//
//  AppUpdateChecker.swift
//  NPS Browser
//
//  Created by JK3Y on 8/12/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation

class AppUpdateChecker {

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

    @MainActor
    func downloadUpdate(url: URL) async {
        Helpers().showLoadingViewController()
        Helpers().getLoadingViewController().setLabel(text: "Fetching update...")

        let destination: FileDownload.Destination = { suggestedFilename in
            // .pkg filename
            var url: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            url.appendPathComponent(suggestedFilename ?? "NPS-Browser-update.pkg")

            return url
        }

        do {
            _ = try await FileDownload(url: url, destination: destination).run { fraction in
                Helpers().getLoadingViewController().setLabel(text: "Downloading...")
                Helpers().getLoadingViewController().setProgress(amount: fraction * 100)
            }
            Helpers().makeAlert(messageText: "Update Downloaded", informativeText: "Update has been downloaded.", alertStyle: .informational)
        } catch {
            Helpers().makeAlert(messageText: "Download failed", informativeText: "The update has failed to download.", alertStyle: .warning)
        }

        Helpers().getLoadingViewController().closeWindow()
    }

}
