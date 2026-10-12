//
//  AppUpdateChecker.swift
//  NPS Browser
//
//  Created by JK3Y on 8/12/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation

@MainActor
class AppUpdateChecker {

    private let loading: LoadingPresenting
    private let alerts: AlertPresenting

    init(loading: LoadingPresenting, alerts: AlertPresenting) {
        self.loading = loading
        self.alerts = alerts
    }

    struct LatestRelease {
        let version: String
        let browserDownloadURL: String
    }

    func fetchLatest() async throws -> LatestRelease {
        guard let url = URL(string: "https://api.github.com/repos/JK3Y/NPS-Browser-macOS/releases/latest") else {
            throw URLError(.badURL)
        }

        let data = try await HTTPClient.data(from: url)
        let release = try newJSONDecoder().decode(GHLatestRelease.self, from: data)
        guard let browserDownloadURL = release.assets.last?.browserDownloadURL else {
            throw URLError(.cannotParseResponse)
        }

        return LatestRelease(version: release.tagName.replacingOccurrences(of: "v", with: ""),
                             browserDownloadURL: browserDownloadURL)
    }

    func downloadUpdate(url: URL) async {
        loading.show()
        loading.setLabel(text: "Fetching update...")

        let destination: FileDownload.Destination = { suggestedFilename in
            // .pkg filename
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            return downloads.appendingPathComponent(suggestedFilename ?? "NPS-Browser-update.pkg")
        }

        do {
            _ = try await FileDownload(url: url, destination: destination).run { progress in
                loading.setLabel(text: "Downloading...")
                loading.setProgress(amount: progress.fraction * 100)
            }
            alerts.showAlert(messageText: "Update Downloaded", informativeText: "Update has been downloaded.", alertStyle: .informational)
        } catch {
            alerts.showAlert(messageText: "Download failed", informativeText: "The update has failed to download.", alertStyle: .warning)
        }

        loading.close()
    }

}
