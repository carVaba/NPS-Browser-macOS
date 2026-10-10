//
//  AppUpdateChecker.swift
//  NPS Browser
//
//  Created by JK3Y on 8/12/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation
import Promises

class AppUpdateChecker {
    
    func fetchLatest(successHandler: @escaping ((_ tagName: String, _ browserDownloadURL: String) -> ()) ) {
        let url = "https://api.github.com/repos/JK3Y/NPS-Browser-macOS/releases/latest"
        
        guard let requestURL = URL(string: url) else {
            return
        }

        HTTPClient.fetchData(from: requestURL) { result in
            switch result {
            case .success(let data):
                guard let release = try? newJSONDecoder().decode(GHLatestRelease.self, from: data),
                      let browserDownloadUrl = release.assets.last?.browserDownloadURL else {
                    log.error("Could not read the latest release information.")
                    return
                }
                let ghVersion = release.tagName.replacingOccurrences(of: "v", with: "")
                successHandler(ghVersion, browserDownloadUrl)
            case .failure(let error):
                log.error(error)
            }
        }
    }
    
    func downloadUpdate(url: URL) {
        
        Helpers().showLoadingViewController()
        Helpers().getLoadingViewController().setLabel(text: "Fetching update...")
        
        let destination: FileDownload.Destination = { suggestedFilename in
            // .pkg filename
            var url: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            url.appendPathComponent(suggestedFilename ?? "NPS-Browser-update.pkg")

            return url
        }

        let download = FileDownload(url: url, destination: destination)
        download.onProgress = { fraction in
            Helpers().getLoadingViewController().setLabel(text: "Downloading...")
            Helpers().getLoadingViewController().setProgress(amount: fraction * 100)
        }
        download.onFinish = { result in
            switch result {
            case .success:
                Helpers().makeAlert(messageText: "Update Downloaded", informativeText: "Update has been downloaded.", alertStyle: .informational)
            case .failure:
                Helpers().makeAlert(messageText: "Download failed", informativeText: "The update has failed to download.", alertStyle: .warning)
            }

            Helpers().getLoadingViewController().closeWindow()
        }
        download.start()
    }
    
}
