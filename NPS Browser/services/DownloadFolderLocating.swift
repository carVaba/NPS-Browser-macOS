import Foundation

protocol DownloadFolderLocating {
    func folder(for item: DownloadItem) -> URL?
}

// Finds the folder with the files of a download. It falls back to the nearest folder that exists.
struct DefaultsDownloadFolderLocator: DownloadFolderLocating {
    func folder(for item: DownloadItem) -> URL? {
        guard let library = Defaults[.libraryFolder] else {
            return nil
        }
        let consoleFolder = library.appendingPathComponent(item.consoleType ?? "")

        var candidates: [URL] = []
        if let extracted = extractedFolder(of: item, in: consoleFolder) {
            candidates.append(extracted)
        }
        if let file = item.destinationURL {
            candidates.append(file.deletingLastPathComponent())
        }
        candidates.append(consoleFolder)
        candidates.append(library)

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func extractedFolder(of item: DownloadItem, in consoleFolder: URL) -> URL? {
        guard let console = ConsoleType(rawValue: item.consoleType ?? ""),
              let type = FileType(rawValue: item.fileType ?? "") else {
            return nil
        }
        let titleID = item.titleId ?? ""

        if type == .compatPack || type == .compatPatch {
            return consoleFolder.appendingPathComponent("rePatch/\(titleID)")
        }

        guard Defaults[.extractsAfterDownloading] else {
            return nil
        }

        switch (console, type) {
        case (.psv, .game): return consoleFolder.appendingPathComponent("app/\(titleID)")
        case (.psv, .dlc): return consoleFolder.appendingPathComponent("addcont/\(titleID)")
        case (.psv, .update): return consoleFolder.appendingPathComponent("patch/\(titleID)")
        case (.psv, .theme): return consoleFolder.appendingPathComponent("bgdl/t")
        case (.psp, _): return consoleFolder.appendingPathComponent("pspemu/ISO")
        case (.psx, _): return consoleFolder.appendingPathComponent("pspemu")
        default: return nil
        }
    }
}
