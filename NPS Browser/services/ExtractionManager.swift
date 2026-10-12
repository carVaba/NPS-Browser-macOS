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
    private var isPS3: Bool = false
    
    init(item: DownloadItem, downloadManager: DownloadManager) {
        self.item = item
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
    
    func makeRepatchFolder(filepath: URL) -> URL {
        let fp = filepath.appendingPathComponent(item.consoleType!)
        try! Folder(path: fp.path).createSubfolderIfNeeded(withName: "rePatch")
        
        return fp.appendingPathComponent("rePatch")
    }
    
    func unzipPPK() async {
        var filepath = Defaults[.libraryFolder]
        let rpf = makeRepatchFolder(filepath: filepath!)
        filepath = rpf.appendingPathComponent("\(item.titleId!)")
        
        if (item.fileType == "CPack") {
            do {
                try await Self.unzip(item.destinationURL!, to: filepath!)
                completeDownload(status: "Extraction Complete")
            }
            catch {
                log.warning("pack not unzipped")
            }
        }
        
        if (item.fileType == "CPatch") {
            do {
                if (item.cpackPath != nil) {
                    try await Self.unzip(item.cpackPath!, to: filepath!)
                    item.parentItem?.status = "Extraction Complete"
                    item.parentItem?.makeViewable()
                    Helpers().showNotification(title: (item.parentItem?.name!)!, subtitle: (item.parentItem?.status!)!)
                }
                try await Self.unzip(item.destinationURL!, to: filepath!)
                completeDownload(status: "Extraction Complete")
            }
            catch {
                log.warning("patch not unzipped")
            }
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
              let consoleFolder = Defaults[.libraryFolder]?.appendingPathComponent(item.consoleType ?? "") else {
            setStatus("Extraction failed")
            item.makeRemovable()
            return
        }

        do {
            let status = try await ProcessRunner.run(executable: pkg2zip, arguments: pkg2zipArguments, currentDirectory: consoleFolder)
            if (status == 0) {
                setStatus("Extraction Complete")
                item.makeViewable()
                Helpers().showNotification(title: item.name ?? "", subtitle: item.status ?? "")
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
        Helpers().showNotification(title: self.item.name!, subtitle: self.item.status!)
        
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
        if (!(Defaults[.keepsPackage])) { // false
            let pkg_path = item.destinationURL
            do {
                try FileManager.default.removeItem(at: pkg_path!)
            } catch let error as NSError {
                debugPrint(error)
            }
        }
    }
    
    private var pkg2zipArguments: [String] {
        // pkg2zip args: [zip (nothing) or not (-x)] [.pkg path] [zRIF string]
        var arguments: [String] = []
        
        if (!(Defaults[.savesAsZip])) { // == false
            arguments.append("-x")
        }
        
        if (item.consoleType! == "PSP" && item.fileType! == "Game" && Defaults[.compressesPSPISO]) { // == true
            arguments.append("-c\(Defaults[.compressionFactor])")
        }
        
        arguments.append((item.destinationURL?.path)!)
        
        if (item.zrif != nil && Defaults[.createsLicense]) { // == true
            arguments.append(item.zrif!)
        }
        
        return arguments
    }
    
//    private func unpackagePS3() {
//        setStatus("Extracting...")
//
//        let pkgripPath = Bundle.main.resourcePath! + "/pkgrip"
//        let task = Process()
//        let pipe = Pipe()
//
//        task.currentDirectoryURL = userSettings?.download.download_location
//        task.executableURL = URL(fileURLWithPath: pkgripPath)
//        task.arguments = ["-s", (item.destinationURL?.path)!]
//        task.standardOutput = pipe
//        task.terminationHandler = { task in
//            DispatchQueue.main.async {
//                self.setStatus("Extraction Complete")
//                self.item.makeViewable()
//                Helpers().showNotification(title: self.item.name!, subtitle: self.item.status!)
//            }
//        }
//
//        do {
//            try task.run()
//        } catch let error as NSError {
//            debugPrint(error)
//        }
//
//        task.waitUntilExit()
//
//        cleanup()
//    }
    
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
