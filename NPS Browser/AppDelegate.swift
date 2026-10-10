//
//  AppDelegate.swift
//  NPS Browser
//
//  Created by JK3Y on 4/28/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
@preconcurrency import UserNotifications
import SwiftyBeaver
import RealmSwift

let log = SwiftyBeaver.self

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    
    lazy var downloadManager: DownloadManager = DownloadManager()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        setupSwiftyBeaverLogging()
        setupDownloadsDirectory()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await downloadManager.stopAndStoreDownloadList()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func setupSwiftyBeaverLogging() {
        let console = ConsoleDestination()
        let file = FileDestination()

        log.addDestination(console)
        log.addDestination(file)
    }
    
    func setupDownloadsDirectory() {
        var dlFolder: URL? = Defaults[.dl_library_location]
        
        
//        if (try! !dlFolder.checkResourceIsReachable()) {
//            dlFolder =
//            try! Defaults[.dl_library_location] = dlFolder
//        }
        
        let dlDirName = "NPS Downloads"
        
        do {
            try Folder(path: dlFolder!.path).createSubfolderIfNeeded(withName: dlDirName)
        } catch {
            dlFolder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            Defaults.set(dlFolder!.absoluteURL, forKey: "dl_library_location")
            try! Folder(path: dlFolder!.path).createSubfolderIfNeeded(withName: dlDirName)
        }
        
    }
    
    // MARK: - Notifications

    func showNotification(title: String, subtitle: String) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = subtitle
            content.sound = .default
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

}
