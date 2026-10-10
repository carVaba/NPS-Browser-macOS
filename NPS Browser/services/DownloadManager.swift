//
//  DownloadManager.swift
//  NPS Browser
//
//  Created by JK3Y on 5/18/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import Queuer
import Promises
//import Files

class DownloadManager {
    
    var downloadItems: [DLItem] = []
    let queue = Queuer(name: "DLQueue", maxConcurrentOperationCount: Defaults[.dl_concurrent_downloads], qualityOfService: .default)
    
    init() {
        restoreDownloadList()
    }
    
    func getDestination(data: DLItem) -> FileDownload.Destination {
        let destination: FileDownload.Destination = { suggestedFilename in
            // .pkg filename
            let pathComponent = suggestedFilename ?? data.downloadUrl?.lastPathComponent ?? "download.pkg"
            let cf = data.consoleType
            
            var path: URL = Defaults[.dl_library_folder] ?? URL(string: try! Folder.home.subfolder(named: "Downloads").path)!
            
            path.appendPathComponent(cf!)
//            var path: URL = Defaults[.dl_library_folder]!.appendingPathComponent(cf!)
            path.appendPathComponent(pathComponent)

            let decodedurl = path.path.removingPercentEncoding
            return URL(fileURLWithPath: decodedurl ?? path.path)
        }
        return destination
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
        // store request in same object so we can cancel/pause/resume it later
        let destination = getDestination(data: data)
        
        makeConsoleFolder(dlItem: data)
        
        let request = FileDownload(url: data.downloadUrl!, destination: destination)
        data.request = request
        data.destination = destination
        data.status = "Queued..."
        data.makeStoppable()
            
        // add object to downloadItems array
        downloadItems.insert(data, at: 0)
        
        let downloadItemsIndex = downloadItems.firstIndex(of: data)!
        
        // get object back out of downloadItems array so the async operation can use it and update the properties as it runs
        let dlItem = self.downloadItems[downloadItemsIndex]
        
        let dlFileOperation = makeConucurrentOperation(dlItem: dlItem, request: request)
        self.queue.addOperation(dlFileOperation)
    }
    
    func resumeDownload(data: DLItem) {
        let destination = data.destination ?? getDestination(data: data)
        let request: FileDownload
        if let resumeData = data.resumeData {
            request = FileDownload(resumeData: resumeData, destination: destination)
        } else if let url = data.downloadUrl {
            request = FileDownload(url: url, destination: destination)
        } else {
            return
        }
        data.request = request
        let op = makeConucurrentOperation(dlItem: data, request: request)
        queue.addOperation(op)
    }

    func removeCompleted() {
        for item in downloadItems {
            if (item.isRemovable) {
                downloadItems.remove(at: downloadItems.firstIndex(of: item)!)
            }
        }
    }
    
    func moveToCompleted(item: DLItem) {
        downloadItems.remove(at: downloadItems.firstIndex(of: item)!)
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
                item.request?.cancel()
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

    func makeConucurrentOperation(dlItem: DLItem, request: FileDownload) -> ConcurrentOperation {
        return ConcurrentOperation { operation in
            request.onProgress = { fraction in
                dlItem.status = "Downloading..."
                dlItem.makeStoppable()
                dlItem.progress = (fraction * 100).rounded()
                dlItem.timeRemaining = fraction
            }
            request.onFinish = { result in
                // Frees the queue slot at once, so the next download can start.
                operation.finish()

                switch result {
                case .success(let fileURL):
                    dlItem.destinationURL = fileURL
                    if (dlItem.isMore()) {
                        dlItem.doNext?.cpackPath = dlItem.destinationURL
                        dlItem.status = "Waiting..."

                        self.addToDownloadQueue(data: dlItem.doNext!)
                    } else {
                        ExtractionManager(item: dlItem, downloadManager: self).start()
                    }
                case .failure(let failure):
                    let wasCancelled = (failure.underlying as? URLError)?.code == .cancelled
                    if wasCancelled || failure.resumeData != nil {
                        dlItem.status = "Stopped"
                        dlItem.resumeData = failure.resumeData
                        dlItem.makeResumable()
                    } else {
                        dlItem.status = "Failed! \(failure.underlying.localizedDescription)"
                        log.error(failure.underlying)

                        dlItem.makeRemovable()
                    }
                }
            }

            request.start()
        }
    }
}
