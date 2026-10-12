//
//  ExtractionManager.swift
//  NPS Browser
//
//  Created by JK3Y on 6/2/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation
import Cocoa
import Zip

@MainActor
class ExtractionManager {
    private var item: DownloadItem
//    private let userSettings = SettingsManager().getSettings()
    private var downloadManager: DownloadManager
    private let notifications: NotificationSending
    private var isPS3: Bool = false

    init(item: DownloadItem, downloadManager: DownloadManager, notifications: NotificationSending) {
        self.item = item
        self.notifications = notifications
        Zip.addCustomFileExtension("ppk")

        if (item.consoleType == "PS3") {
            self.isPS3 = true
        }
    
        self.downloadManager = downloadManager
    }
    
    func start() async {
        if (!shouldExtract) {
            completeDownload(status: "Download Complete")
            return
        }
        
        if (item.fileType == "CPatch" || item.fileType == "CPack") {
            await unzipPPK()
        } else {
            await usePkg2Zip()
        }
    }
    
    private func makeRepatchFolder(in library: URL) -> URL? {
        guard let console = item.consoleType else {
            return nil
        }
        let folder = library.appendingPathComponent(console).appendingPathComponent("rePatch")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        } catch {
            log.error(error)
            return nil
        }
    }

    private func failExtraction() {
        setStatus("Extraction failed")
        item.makeRemovable()
    }

    func unzipPPK() async {
        guard let library = Defaults[.libraryFolder],
              let titleID = item.titleId,
              let archive = item.destinationURL,
              let repatchFolder = makeRepatchFolder(in: library) else {
            failExtraction()
            return
        }
        let target = repatchFolder.appendingPathComponent(titleID)

        do {
            if item.fileType == "CPatch", let pack = item.cpackPath {
                try await Self.unzip(pack, to: target)
                if let parent = item.parentItem {
                    parent.status = "Extraction Complete"
                    parent.makeViewable()
                    notifications.showNotification(title: parent.name ?? "", subtitle: parent.status ?? "")
                }
            }
            try await Self.unzip(archive, to: target)
            completeDownload(status: "Extraction Complete")
        } catch {
            log.warning("compat file not unzipped: \(error)")
            failExtraction()
        }
    }
    
    // The extraction of a large game takes a long time, so the process runs without blocking the main actor.
    func usePkg2Zip() async {
        if (item.zrif == "MISSING") {
            completeDownload(status: "Missing zRIF, license not created")
            return
        }
        
        setStatus("Extracting...")
        
        guard let pkg2zip = Bundle.main.url(forResource: "pkg2zip", withExtension: nil),
              let package = item.destinationURL,
              let consoleFolder = Defaults[.libraryFolder]?.appendingPathComponent(item.consoleType ?? "") else {
            setStatus("Extraction failed")
            item.makeRemovable()
            return
        }

        do {
            let status = try await ProcessRunner.run(executable: pkg2zip, arguments: pkg2zipArguments(for: package), currentDirectory: consoleFolder)
            if (status == 0) {
                setStatus("Extraction Complete")
                item.makeViewable()
                notifications.showNotification(title: item.name ?? "", subtitle: item.status ?? "")
                cleanup()
            } else {
                log.error("pkg2zip stopped with status \(status)")
                setStatus("Extraction failed")
                item.makeRemovable()
            }
        } catch {
            log.error(error)
            setStatus("Extraction failed")
            item.makeRemovable()
        }
    }

    @concurrent
    private static func unzip(_ file: URL, to destination: URL) async throws {
        try Zip.unzipFile(file, destination: destination, overwrite: true, password: nil)
    }
    
    private func completeDownload(status: String) {
        setStatus(status)
        self.item.makeViewable()
        notifications.showNotification(title: item.name ?? "", subtitle: item.status ?? "")
        
        downloadManager.moveToCompleted(self.item)
        return
    }
    
    private var shouldExtract: Bool {
        if (isPS3) {
            return false
        }
        return Defaults[.extractsAfterDownloading]
    }
    
    private func cleanup() {
        guard !Defaults[.keepsPackage], let package = item.destinationURL else {
            return
        }
        do {
            try FileManager.default.removeItem(at: package)
        } catch {
            log.error(error)
        }
    }
    
    // pkg2zip arguments: [zip (nothing) or not (-x)] [.pkg path] [zRIF string]
    private func pkg2zipArguments(for package: URL) -> [String] {
        var arguments: [String] = []
        
        if !Defaults[.savesAsZip] {
            arguments.append("-x")
        }
        
        if item.consoleType == "PSP" && item.fileType == "Game" && Defaults[.compressesPSPISO] {
            arguments.append("-c\(Defaults[.compressionFactor])")
        }
        
        arguments.append(package.path)
        
        if let zrif = item.zrif, Defaults[.createsLicense] {
            arguments.append(zrif)
        }
        
        return arguments
    }
    
    
    private func setStatus(_ status: String) {
        item.status = status
    }
}

enum ProcessRunner {
    // Returns the exit status when the process ends.
    static func run(executable: URL, arguments: [String], currentDirectory: URL) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.currentDirectoryURL = currentDirectory
            // The output is not read, so a full pipe would block the process.
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { finished in
                continuation.resume(returning: finished.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
