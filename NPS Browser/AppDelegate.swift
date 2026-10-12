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

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    
    lazy var downloadManager: DownloadManager = DownloadManager()
    private(set) var windowController: WindowController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupSwiftyBeaverLogging()
        setupDownloadsDirectory()

        windowController = WindowController()
        NSApp.mainMenu = MainMenu.make(appDelegate: self, windowController: windowController)
        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showPreferences(_ sender: Any?) {
        guard let parent = windowController.window?.contentViewController else {
            return
        }
        parent.presentAsModalWindow(PreferencesViewController())
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
        var dlFolder: URL? = Defaults[.libraryLocation]
        
        
//        if (try! !dlFolder.checkResourceIsReachable()) {
//            dlFolder =
//            try! Defaults[.libraryLocation] = dlFolder
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
