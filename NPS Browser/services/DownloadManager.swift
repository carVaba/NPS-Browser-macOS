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
class DownloadManager: DownloadQueuing {

    var downloadItems: [DownloadItem] = []
    private let slots = DownloadSlots(limit: Defaults[.concurrentDownloads])
    private let alerts: AlertPresenting
    private let notifications: NotificationSending
    private let directory: DownloadsDirectoryPreparing

    init(alerts: AlertPresenting, notifications: NotificationSending, directory: DownloadsDirectoryPreparing) {
        self.alerts = alerts
        self.notifications = notifications
        self.directory = directory
        restoreDownloadList()
    }
    
    func makeDestination(for item: DownloadItem) -> FileDownload.Destination {
        let fallbackName = item.downloadURL?.lastPathComponent ?? "download.pkg"
        let consoleFolder = item.consoleType ?? ""
        let libraryFolder: URL = Defaults[.libraryFolder] ?? URL(string: try! Folder.home.subfolder(named: "Downloads").path)!

        return { suggestedFilename in
            // .pkg filename
            let path = libraryFolder
                .appendingPathComponent(consoleFolder)
                .appendingPathComponent(suggestedFilename ?? fallbackName)

            return URL(fileURLWithPath: path.path.removingPercentEncoding ?? path.path)
        }
    }
    
    func createConsoleFolder(for item: DownloadItem) {
        let filepath = Defaults[.libraryFolder]!
        let console = item.consoleType

        if (try? Folder(path: filepath.path).createSubfolderIfNeeded(withName: console!)) != nil {
            return
        } else {
            directory.prepare()
            createConsoleFolder(for: item)
        }
    }
    
    func enqueue(_ item: DownloadItem) {
        guard let url = item.downloadURL else {
            return
        }

        let destination = makeDestination(for: item)
        
        createConsoleFolder(for: item)
        
        // store the download in the same object so we can stop/resume it later
        let download = FileDownload(url: url, waitsForConnectivity: true, destination: destination)
        item.download = download
        item.destination = destination
        item.status = "Queued..."
        item.makeStoppable()

        downloadItems.insert(item, at: 0)
        NotificationCenter.default.post(name: .downloadListChanged, object: nil)

        start(item: item, download: download)
    }
    
    func resume(_ item: DownloadItem) {
        let destination = item.destination ?? makeDestination(for: item)
        let download: FileDownload
        if let resumeData = item.resumeData {
            download = FileDownload(resumeData: resumeData, waitsForConnectivity: true, destination: destination)
        } else if let url = item.downloadURL {
            download = FileDownload(url: url, waitsForConnectivity: true, destination: destination)
        } else {
            return
        }

        item.download = download
        item.resumeData = nil
        start(item: item, download: download)
    }

    func stop(_ item: DownloadItem) {
        item.isUserStopped = true
        item.status = "Stopped"
        item.clearTransferRate()
        item.makeResumable()

        guard let download = item.download else {
            return
        }
        Task {
            item.resumeData = await download.stop()
        }
    }

    // Stops the download and removes it from the list. The temporary data is deleted by the system.
    func cancel(_ item: DownloadItem) {
        item.isUserStopped = true
        item.isCancelled = true

        if let download = item.download {
            Task { _ = await download.stop() }
        }

        downloadItems.removeAll { $0 === item }
        NotificationCenter.default.post(name: .downloadListChanged, object: nil)
    }

    func removeCompleted() {
        downloadItems.removeAll { $0.isRemovable }
    }
    
    func moveToCompleted(_ item: DownloadItem) {
        guard let index = downloadItems.firstIndex(of: item) else {
            return
        }
        downloadItems.remove(at: index)
        downloadItems.insert(item, at: downloadItems.endIndex)
    }
    
    // Stops the running downloads and keeps their resume data, so the next start continues the files.
    func stopAndStoreDownloadList() async {
        var running: [(item: DownloadItem, download: FileDownload)] = []

        for item in downloadItems {
            
            if (item.status == "Download Complete" || item.status == "Extraction Complete" || item.status == "Missing zRIF, license not created") {
                item.makeViewable()
            } else {
                item.isUserStopped = true
                if item.isStoppable, let download = item.download {
                    running.append((item, download))
                }
                item.status = "Stopped"
                item.makeResumable()
            }
        }

        for (item, download) in running {
            if let resumeData = await download.stop() {
                item.resumeData = resumeData
            }
        }

        let downloadList: DownloadList = DownloadList(items: downloadItems)
        
        do {
            let data = try PropertyListEncoder().encode(downloadList)
            UserDefaults.standard.set(data, forKey: "downloads")
        } catch {
            alerts.showAlert(messageText: "Save Failed",
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

    private func start(item: DownloadItem, download: FileDownload) {
        item.isUserStopped = false

        Task {
            await slots.acquire()
            let outcome = await transfer(item: item, firstAttempt: download)
            // Frees the slot at once, so the next download starts while this file is verified.
            await slots.release()

            let fileURL: URL
            switch outcome {
            case .failure(let error):
                handleFailure(error, of: item)
                return
            case .success(let url):
                fileURL = url
            }

            item.destinationURL = fileURL
            await verifyChecksum(of: item)

            guard !item.isCancelled else {
                return
            }

            if (item.hasFollowUp) {
                item.doNext?.cpackPath = item.destinationURL
                item.status = "Waiting..."

                enqueue(item.doNext!)
            } else {
                await ExtractionManager(item: item, downloadManager: self, notifications: notifications).start()
            }
        }
    }

    private static let maxAttempts = 3

    // Runs the download and tries again after a network error. A retry continues from the resume data.
    private func transfer(item: DownloadItem, firstAttempt: FileDownload) async -> Result<URL, Error> {
        var attempt = firstAttempt
        var resumeFromURLUsed = false

        for number in 1...Self.maxAttempts {
            do {
                let rate = TransferRateEstimator()
                let fileURL = try await attempt.run(onProgress: { progress in
                    item.status = "Downloading..."
                    item.makeStoppable()
                    item.progress = (progress.fraction * 100).rounded()
                    rate.update(bytesWritten: progress.bytesWritten)
                    item.bytesPerSecond = rate.bytesPerSecond
                    item.timeRemaining = rate.remainingSeconds(bytesWritten: progress.bytesWritten,
                                                               bytesExpected: progress.bytesExpected) ?? 0
                }, onWaiting: {
                    item.status = "Waiting for the network..."
                    item.clearTransferRate()
                })
                item.clearTransferRate()
                return .success(fileURL)
            } catch {
                item.clearTransferRate()
                var canRetry = Self.isRetryable(error)
                if !canRetry, !resumeFromURLUsed, attempt.usesResumeData, !Self.isCancelled(error) {
                    // The resume data is not valid any more, so the file starts again.
                    resumeFromURLUsed = true
                    canRetry = true
                }

                guard canRetry, number < Self.maxAttempts, !item.isUserStopped else {
                    return .failure(error)
                }

                item.status = "Retrying (\(number + 1)/\(Self.maxAttempts))..."
                try? await Task.sleep(nanoseconds: UInt64(number) * 2_000_000_000)
                guard !item.isUserStopped, let next = makeRetry(for: item, after: error) else {
                    return .failure(error)
                }

                item.download = next
                attempt = next
            }
        }
        return .failure(URLError(.unknown))
    }

    private func makeRetry(for item: DownloadItem, after error: Error) -> FileDownload? {
        let destination = item.destination ?? makeDestination(for: item)
        if let resumeData = (error as? DownloadFailure)?.resumeData {
            return FileDownload(resumeData: resumeData, waitsForConnectivity: true, destination: destination)
        }
        guard let url = item.downloadURL else {
            return nil
        }
        return FileDownload(url: url, waitsForConnectivity: true, destination: destination)
    }

    private static func isCancelled(_ error: Error) -> Bool {
        (error as? DownloadFailure)?.isCancelled ?? false
    }

    private static func isRetryable(_ error: Error) -> Bool {
        guard let failure = error as? DownloadFailure else {
            return false
        }
        if let status = failure.underlying as? HTTPStatusError {
            return status.statusCode >= 500
        }
        guard let urlError = failure.underlying as? URLError else {
            return false
        }
        switch urlError.code {
        case .networkConnectionLost, .timedOut, .notConnectedToInternet, .cannotConnectToHost,
             .dnsLookupFailed, .cannotFindHost:
            return true
        default:
            return false
        }
    }

    private func handleFailure(_ error: Error, of item: DownloadItem) {
        guard let failure = error as? DownloadFailure else {
            item.status = "Failed! \(error.localizedDescription)"
            log.error(error)
            item.makeRemovable()
            return
        }

        if failure.isCancelled {
            // `stop(_:)` already updated the item.
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
    private func verifyChecksum(of item: DownloadItem) async {
        guard let expected = item.sha256?.lowercased(), expected.count == 64, let fileURL = item.destinationURL else {
            return
        }

        item.status = "Verifying..."

        let actual = await FileChecksum.sha256(of: fileURL)
        if let actual = actual, actual != expected {
            log.warning("Checksum mismatch for \(fileURL.lastPathComponent)")
            alerts.showAlert(messageText: "Checksum mismatch",
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

extension Notification.Name {
    static let downloadListChanged = Notification.Name("downloadListChanged")
}
