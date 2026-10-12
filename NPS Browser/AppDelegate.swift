//
//  AppDelegate.swift
//  NPS Browser
//
//  Created by JK3Y on 4/28/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
@preconcurrency import UserNotifications
import RealmSwift

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NotificationSending {
    
    private let alerts = AppKitAlertPresenter()
    private let sources = DefaultsSourceURLs()
    private let folders = DefaultsDownloadFolderLocator()
    private let downloadsDirectory = DefaultsDownloadsDirectory()
    lazy var downloadManager = DownloadManager(alerts: alerts, notifications: self, directory: downloadsDirectory)
    private(set) var windowController: WindowController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        downloadsDirectory.prepare()

        windowController = WindowController(downloads: downloadManager, folders: folders, alerts: alerts, sources: sources)
        NSApp.mainMenu = MainMenu.make(appDelegate: self, windowController: windowController)
        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showPreferences(_ sender: Any?) {
        guard let parent = windowController.window?.contentViewController else {
            return
        }
        parent.presentAsModalWindow(PreferencesViewController(alerts: alerts))
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
