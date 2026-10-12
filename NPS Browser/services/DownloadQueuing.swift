import Foundation

@MainActor
protocol DownloadQueuing: AnyObject {
    var downloadItems: [DownloadItem] { get }
    func enqueue(_ item: DownloadItem)
    func resume(_ item: DownloadItem)
    func stop(_ item: DownloadItem)
    func cancel(_ item: DownloadItem)
    func removeCompleted()
}

protocol DownloadsDirectoryPreparing {
    func prepare()
}

struct DefaultsDownloadsDirectory: DownloadsDirectoryPreparing {
    func prepare() {
        let dlDirName = "NPS Downloads"
        let fileManager = FileManager.default

        if let folder = Defaults[.libraryLocation], fileManager.createFolderIfNeeded(at: folder.appendingPathComponent(dlDirName)) {
            return
        }

        let fallback = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        Defaults.set(fallback.absoluteURL, forKey: "dl_library_location")
        _ = fileManager.createFolderIfNeeded(at: fallback.appendingPathComponent(dlDirName))
    }
}
