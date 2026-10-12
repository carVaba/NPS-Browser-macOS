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
        var dlFolder: URL? = Defaults[.libraryLocation]

        let dlDirName = "NPS Downloads"

        do {
            try Folder(path: dlFolder!.path).createSubfolderIfNeeded(withName: dlDirName)
        } catch {
            dlFolder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            Defaults.set(dlFolder!.absoluteURL, forKey: "dl_library_location")
            try! Folder(path: dlFolder!.path).createSubfolderIfNeeded(withName: dlDirName)
        }
    }
}
