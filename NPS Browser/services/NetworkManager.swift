//
//  NetworkManager.swift
//  NPS Browser
//
//  Created by JK3Y on 8/10/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation

@MainActor
class NetworkManager {
    
    let windowDelegate: WindowDelegate = Helpers().windowDelegate
    
    let itemType = Helpers().windowDelegate.itemType

    func makeRequest() async {
        guard let url = Helpers().getUrlSettingsByType(itemType: itemType) else {
            Helpers().makeAlert(messageText: "No URL set for \(self.itemType.console.rawValue) \(self.itemType.fileType.rawValue)s.", informativeText: "Set source paths in the preferences window.", alertStyle: .warning)

            log.error("Invalid URL given for item type: \(itemType.description)")
            return
        }
        
        if (url.isFileURL) {
            guard (try? url.checkResourceIsReachable()) != nil else {
                Helpers().makeAlert(messageText: "Resource not found!", informativeText: "File does not exist at path: \(url)", alertStyle: .warning)
                return
            }
        }

        let storage = try! RealmStorageContext()
        let ft:FileType = self.windowDelegate.itemType.fileType
        let ct:ConsoleType = self.windowDelegate.itemType.console
        
        Helpers().showLoadingViewController()
        Helpers().loadingViewController.setLabel(text: "Requesting data... (step 1/5)")
        Helpers().loadingViewController.setProgress(amount: 20)

        do {
            let text = try await HTTPClient.string(from: url) { fraction in
                self.windowDelegate.loadingViewController.setLabel(text: "Receiving data... (step 2/5)")
                self.windowDelegate.loadingViewController.setProgress(amount: fraction / 20)
            }

            self.windowDelegate.loadingViewController.setLabel(text: "Preparing... (step 3/5)")
            self.windowDelegate.loadingViewController.setProgress(amount: 20)
            let parsedTSV = Parser().parseTSV(data: text, itemType: self.itemType)

            self.windowDelegate.loadingViewController.setLabel(text: "Removing old values... (step 4/5)")
            self.windowDelegate.loadingViewController.setProgress(amount: 50)
            try storage.deleteAll(Item.self, predicate: NSPredicate(format: "fileType == %@ AND consoleType == %@", ft.rawValue, ct.rawValue))

            self.windowDelegate.loadingViewController.setLabel(text: "Storing new values... (step 5/5)")
            self.windowDelegate.loadingViewController.setProgress(amount: 20)
            DBManager().storeBulk(objArray: parsedTSV.map { Item(tsvData: $0) })
        } catch {
            log.error(error)
            Helpers().loadingViewController.closeWindow()
            Helpers().makeAlert(messageText: "Could not load the list.", informativeText: error.localizedDescription, alertStyle: .warning)
            return
        }

        Helpers().loadingViewController.closeWindow()

        if (self.itemType.console == ConsoleType.PSV && self.itemType.fileType == FileType.Game) {
            Task {
                await loadCompatPacks()
            }
        }

        Helpers().dataController.filterType(itemType: ItemType(console: ct, fileType: ft), region: self.windowDelegate.region)
    }

    private func loadCompatPacks() async {
        guard let cpackurl = Defaults[.src_compatPacks] else {
            Helpers().makeAlert(messageText: "No URL set for Compat Packs.", informativeText: "Set source paths in the preferences window.", alertStyle: .warning)

            log.error("Invalid URL given for compat packs.")
            return
        }

        guard let cpatchurl: URL = Defaults[.src_compatPatch] else {
            Helpers().makeAlert(messageText: "No URL set for Compat Patches.", informativeText: "Set source paths in the preferences window.", alertStyle: .warning)

            log.error("Invalid URL given for compat patches")
            return
        }

        if (cpatchurl.isFileURL) {
            guard (try? cpatchurl.checkResourceIsReachable()) != nil else {
                Helpers().makeAlert(messageText: "Resource not found!", informativeText: "File does not exist at path: \(cpatchurl)", alertStyle: .warning)
                return
            }
        }

        do {
            try await fetchCompatPacks(url: cpackurl, isPatch: false)
            try await fetchCompatPacks(url: cpatchurl, isPatch: true)
        } catch {
            log.error(error)
        }
    }

    private func fetchCompatPacks(url: URL, isPatch: Bool) async throws {
        if url.absoluteString.isEmpty {
            return
        }
        
        let storage = try RealmStorageContext()
        
        let typeName: String = isPatch ? "CompatPatch" : "CompatPack"

        if (self.windowDelegate.loadingViewController.presentingViewController != nil) {
            Helpers().showLoadingViewController()
        }
        Helpers().loadingViewController.setLabel(text: "Requesting Comp Packs... (step 1/5)")
        Helpers().loadingViewController.setProgress(amount: 20)

        let text = try await HTTPClient.string(from: url) { fraction in
            self.windowDelegate.loadingViewController.setLabel(text: "Receiving data... (step 2/5)")
            self.windowDelegate.loadingViewController.setProgress(amount: fraction / 20)
        }

        self.windowDelegate.loadingViewController.setLabel(text: "Preparing... (step 3/5)")
        self.windowDelegate.loadingViewController.setProgress(amount: 20)
        let parsed = Parser().parseCompatPackEntries(data: text, isPatch: isPatch, typeName: typeName)

        self.windowDelegate.loadingViewController.setLabel(text: "Removing old values... (step 4/5)")
        self.windowDelegate.loadingViewController.setProgress(amount: 50)
        try storage.deleteAll(CompatPack.self, predicate: NSPredicate(format: "type == %@", typeName))

        self.windowDelegate.loadingViewController.setLabel(text: "Storing new values... (step 5/5)")
        self.windowDelegate.loadingViewController.setProgress(amount: 20)
        DBManager().storeBulk(objArray: parsed)

        Helpers().loadingViewController.closeWindow()
    }

    func getUpdateXMLURLFromHMAC(titleId: String) -> String {
        var output: [String] = []
        var error: [String] = []

        let vitaupdatelinksPath = Bundle.main.path(forResource: "vitaupdatelinks", ofType: nil)
        let task = Process()
        let outpipe = Pipe()
        task.standardOutput = outpipe
        let errpipe = Pipe()
        task.standardError = errpipe

        task.launchPath = vitaupdatelinksPath
        task.arguments = ["-t", titleId]

        task.launch()

        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String(data: outdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            output = string.components(separatedBy: "\n")
        }

        let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String(data: errdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            error = string.components(separatedBy: "\n")
        }

        task.waitUntilExit()
        let status = task.terminationStatus

        if (status == 0) {
            debugPrint("Update URL Fetch SUCCESS!")
            return output.first!
        } else {
            return error.first!
        }
    }

    func fetchUpdateXML(url: String) async throws -> URL {
        log.debug(url)

        guard let requestURL = URL(string: url) else {
            throw URLError(.badURL)
        }

        let xml = try await HTTPClient.string(from: requestURL)
        guard let updateURL = Parser().parseUpdateXML(data: xml) else {
            throw URLError(.cannotParseResponse)
        }
        return updateURL
    }
    
}
