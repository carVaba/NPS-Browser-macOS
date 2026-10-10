//
//  DownloadManager.swift
//  NPS Browser
//
//  Created by JK3Y on 5/18/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import CryptoKit

@MainActor
class DownloadManager {
    
    var downloadItems: [DLItem] = []
    private let slots = DownloadSlots(limit: Defaults[.dl_concurrent_downloads])
    
    init() {
        restoreDownloadList()
    }
    
    func getDestination(data: DLItem) -> FileDownload.Destination {
        let fallbackName = data.downloadUrl?.lastPathComponent ?? "download.pkg"
        let consoleFolder = data.consoleType ?? ""
        let libraryFolder: URL = Defaults[.dl_library_folder] ?? URL(string: try! Folder.home.subfolder(named: "Downloads").path)!

        return { suggestedFilename in
            // .pkg filename
            let path = libraryFolder
                .appendingPathComponent(consoleFolder)
                .appendingPathComponent(suggestedFilename ?? fallbackName)

            return URL(fileURLWithPath: path.path.removingPercentEncoding ?? path.path)
        }
    }
    
    func makeConsoleFolder(dlItem: DLItem) {
        let filepath = Defaults[.dl_library_folder]!
        let console = dlItem.consoleType

        if (try? Folder(path: filepath.path).createSubfolderIfNeeded(withName: console!)) != nil {
            return
        } else {
            Helpers().getSharedAppDelegate().setupDownloadsDirectory()
            makeConsoleFolder(dlItem: dlItem)
        }
    }
    
    func addToDownloadQueue(data: DLItem) {
        guard let url = data.downloadUrl else {
            return
        }

        let destination = getDestination(data: data)
        
        makeConsoleFolder(dlItem: data)
        
        // store the download in the same object so we can stop/resume it later
        let download = FileDownload(url: url, destination: destination)
        data.download = download
        data.destination = destination
        data.status = "Queued..."
        data.makeStoppable()

        downloadItems.insert(data, at: 0)

        start(item: data, download: download)
    }
    
    func resumeDownload(data: DLItem) {
        let destination = data.destination ?? getDestination(data: data)
        let download: FileDownload
        if let resumeData = data.resumeData {
            download = FileDownload(resumeData: resumeData, destination: destination)
        } else if let url = data.downloadUrl {
            download = FileDownload(url: url, destination: destination)
        } else {
            return
        }

        data.download = download
        data.resumeData = nil
        start(item: data, download: download)
    }

    func stopDownload(item: DLItem) {
        item.status = "Stopped"
        item.makeResumable()

        guard let download = item.download else {
            return
        }
        Task {
            item.resumeData = await download.stop()
        }
    }

    func removeCompleted() {
        downloadItems.removeAll { $0.isRemovable }
    }
    
    func moveToCompleted(item: DLItem) {
        guard let index = downloadItems.firstIndex(of: item) else {
            return
        }
        downloadItems.remove(at: index)
        downloadItems.insert(item, at: downloadItems.endIndex)
    }
    
    func getObjectQueue() -> [DLItem] {
        return self.downloadItems
    }
    
    func stopAndStoreDownloadList() {
        for item in downloadItems {
            
            if (item.status == "Download Complete" || item.status == "Extraction Complete" || item.status == "Missing zRIF, license not created") {
                item.makeViewable()
            } else {
                if let download = item.download {
                    Task { _ = await download.stop() }
                }
                item.status = "Stopped"
                item.makeResumable()
            }
        }
        let downloadList: DownloadList = DownloadList(items: downloadItems)
        
        do {
            let data = try PropertyListEncoder().encode(downloadList)
            UserDefaults.standard.set(data, forKey: "downloads")
        } catch {
            Helpers().makeAlert(messageText: "Save Failed",
                                informativeText: "Download list could not be stored.",
                                alertStyle: .warning)
            
            log.error("Save Failed. Download list could not be stored.")
        }
    }
    
    func restoreDownloadList() {
        let storedData = UserDefaults.standard.object(forKey: "downloads") as? Data
        if (storedData != nil) {
            do {
                let downloadList = try PropertyListDecoder().decode(DownloadList.self, from: storedData!)

                self.downloadItems = downloadList.items
            } catch let error as NSError {
                debugPrint(error)
                
                log.error(error)
            }
        }
    }

    private func start(item: DLItem, download: FileDownload) {
        Task {
            await slots.acquire()

            let fileURL: URL
            do {
                fileURL = try await download.run { fraction in
                    item.status = "Downloading..."
                    item.makeStoppable()
                    item.progress = (fraction * 100).rounded()
                    item.timeRemaining = fraction
                }
            } catch {
                await slots.release()
                handleFailure(error, of: item)
                return
            }

            // Frees the slot at once, so the next download starts while this file is verified.
            await slots.release()

            item.destinationURL = fileURL
            await verifyChecksum(of: item)

            if (item.isMore()) {
                item.doNext?.cpackPath = item.destinationURL
                item.status = "Waiting..."

                addToDownloadQueue(data: item.doNext!)
            } else {
                ExtractionManager(item: item, downloadManager: self).start()
            }
        }
    }

    private func handleFailure(_ error: Error, of item: DLItem) {
        guard let failure = error as? DownloadFailure else {
            item.status = "Failed! \(error.localizedDescription)"
            log.error(error)
            item.makeRemovable()
            return
        }

        if failure.isCancelled {
            // `stopDownload` already updated the item.
            return
        }

        if let resumeData = failure.resumeData {
            item.status = "Stopped"
            item.resumeData = resumeData
            item.makeResumable()
        } else {
            item.status = "Failed! \(failure.underlying.localizedDescription)"
            log.error(failure.underlying)

            item.makeRemovable()
        }
    }

    // A wrong checksum only warns, because the TSV hashes are sometimes outdated.
    private func verifyChecksum(of item: DLItem) async {
        guard let expected = item.sha256?.lowercased(), expected.count == 64, let fileURL = item.destinationURL else {
            return
        }

        item.status = "Verifying..."

        let actual = await FileChecksum.sha256(of: fileURL)
        if let actual = actual, actual != expected {
            log.warning("Checksum mismatch for \(fileURL.lastPathComponent)")
            Helpers().makeAlert(messageText: "Checksum mismatch",
                                informativeText: "\(item.name ?? fileURL.lastPathComponent) does not match the expected SHA256. The file may be damaged or the list may be outdated.",
                                alertStyle: .warning)
        }
    }
}

// Limits how many downloads run at the same time.
actor DownloadSlots {
    private let limit: Int
    private var running = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func acquire() async {
        if running < limit {
            running += 1
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    func release() {
        if waiting.isEmpty {
            running -= 1
        } else {
            waiting.removeFirst().resume()
        }
    }
}

enum FileChecksum {
    @concurrent
    static func sha256(of fileURL: URL) async -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }
        defer { try? handle.close() }

        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
