//
//  NetworkManager.swift
//  NPS Browser
//
//  Created by JK3Y on 8/10/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation

@MainActor
protocol ListLoading {
    func makeRequest() async
}

@MainActor
protocol UpdateLinkFetching {
    func updateXMLURL(forTitleID titleID: String) -> String
    func fetchUpdateXML(url: String) async throws -> URL
}

@MainActor
class NetworkManager: ListLoading, UpdateLinkFetching {

    private let selection: ItemSelecting
    private let loading: LoadingPresenting
    private let alerts: AlertPresenting
    private let sources: SourceURLProviding

    init(selection: ItemSelecting, loading: LoadingPresenting, alerts: AlertPresenting, sources: SourceURLProviding) {
        self.selection = selection
        self.loading = loading
        self.alerts = alerts
        self.sources = sources
    }

    private var itemType: ItemType {
        return selection.itemType
    }

    func makeRequest() async {
        guard let url = sources.sourceURL(for: itemType) else {
            alerts.showAlert(messageText: "No URL set for \(self.itemType.console.rawValue) \(self.itemType.fileType.rawValue)s.", informativeText: "Set source paths in the preferences window.", alertStyle: .warning)

            log.error("Invalid URL given for item type: \(itemType.description)")
            return
        }
        
        if (url.isFileURL) {
            guard (try? url.checkResourceIsReachable()) != nil else {
                alerts.showAlert(messageText: "Resource not found!", informativeText: "File does not exist at path: \(url)", alertStyle: .warning)
                return
            }
        }

        let ft:FileType = selection.itemType.fileType
        let ct:ConsoleType = selection.itemType.console
        
        loading.show()
        loading.setLabel(text: "Requesting data... (step 1/5)")
        loading.setProgress(amount: 20)

        do {
            let text = try await HTTPClient.string(from: url) { fraction in
                loading.setLabel(text: "Receiving data... (step 2/5)")
                loading.setProgress(amount: fraction / 20)
            }

            loading.setLabel(text: "Preparing... (step 3/5)")
            loading.setProgress(amount: 20)
            let parsedTSV = Parser().parseTSV(text, itemType: self.itemType)

            loading.setLabel(text: "Removing old values... (step 4/5)")
            loading.setProgress(amount: 50)
            try DBManager().deleteAll(Item.self, predicate: NSPredicate(format: "fileType == %@ AND consoleType == %@", ft.rawValue, ct.rawValue))

            loading.setLabel(text: "Storing new values... (step 5/5)")
            loading.setProgress(amount: 20)
            DBManager().store(contentsOf: parsedTSV.map { Item(tsvData: $0) })
        } catch {
            log.error(error)
            loading.close()
            alerts.showAlert(messageText: "Could not load the list.", informativeText: error.localizedDescription, alertStyle: .warning)
            return
        }

        loading.close()

        if (self.itemType.console == ConsoleType.psv && self.itemType.fileType == FileType.game) {
            Task {
                await loadCompatPacks()
            }
        }

    }

    private func loadCompatPacks() async {
        guard let cpackurl = Defaults[.sourceCompatPacks] else {
            alerts.showAlert(messageText: "No URL set for Compat Packs.", informativeText: "Set source paths in the preferences window.", alertStyle: .warning)

            log.error("Invalid URL given for compat packs.")
            return
        }

        guard let cpatchurl: URL = Defaults[.sourceCompatPatch] else {
            alerts.showAlert(messageText: "No URL set for Compat Patches.", informativeText: "Set source paths in the preferences window.", alertStyle: .warning)

            log.error("Invalid URL given for compat patches")
            return
        }

        if (cpatchurl.isFileURL) {
            guard (try? cpatchurl.checkResourceIsReachable()) != nil else {
                alerts.showAlert(messageText: "Resource not found!", informativeText: "File does not exist at path: \(cpatchurl)", alertStyle: .warning)
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
        
        let typeName: String = isPatch ? "CompatPatch" : "CompatPack"

        if (loading.isShowing) {
            loading.show()
        }
        loading.setLabel(text: "Requesting Comp Packs... (step 1/5)")
        loading.setProgress(amount: 20)

        let text = try await HTTPClient.string(from: url) { fraction in
            loading.setLabel(text: "Receiving data... (step 2/5)")
            loading.setProgress(amount: fraction / 20)
        }

        loading.setLabel(text: "Preparing... (step 3/5)")
        loading.setProgress(amount: 20)
        let parsed = Parser().parseCompatPackEntries(text, isPatch: isPatch, typeName: typeName)

        loading.setLabel(text: "Removing old values... (step 4/5)")
        loading.setProgress(amount: 50)
        try DBManager().deleteAll(CompatPack.self, predicate: NSPredicate(format: "type == %@", typeName))

        loading.setLabel(text: "Storing new values... (step 5/5)")
        loading.setProgress(amount: 20)
        DBManager().store(contentsOf: parsed)

        loading.close()
    }

    func updateXMLURL(forTitleID titleID: String) -> String {
        var output: [String] = []
        var error: [String] = []

        let vitaupdatelinksPath = Bundle.main.path(forResource: "vitaupdatelinks", ofType: nil)
        let task = Process()
        let outpipe = Pipe()
        task.standardOutput = outpipe
        let errpipe = Pipe()
        task.standardError = errpipe

        task.launchPath = vitaupdatelinksPath
        task.arguments = ["-t", titleID]

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
        guard let updateURL = Parser().parseUpdateXML(xml) else {
            throw URLError(.cannotParseResponse)
        }
        return updateURL
    }
    
}
