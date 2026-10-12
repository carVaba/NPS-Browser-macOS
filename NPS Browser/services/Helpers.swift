//
//  Helpers.swift
//  NPS Browser
//
//  Created by JK3Y on 6/3/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import Foundation

@MainActor
class Helpers {
    
    func showAlert(messageText: String = "", informativeText: String = "", alertStyle: NSAlert.Style = .warning) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = alertStyle
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showNotification(title: String, subtitle: String) {
        sharedAppDelegate.showNotification(title: title, subtitle: subtitle)
    }
    
    var sharedAppDelegate: AppDelegate {
        return NSApp.delegate as! AppDelegate
    }
    
    var windowDelegate: WindowDelegate {
        return sharedAppDelegate.windowController
    }
    
    var dataController: DataViewController {
        return windowDelegate.dataController
    }
        
    var loadingViewController: LoadingViewController {
        return windowDelegate.loadingViewController
    }
    
    func showLoadingViewController() {
        dataController.presentAsSheet(windowDelegate.loadingViewController)
    }
    
    func sourceURL(for itemType: ItemType) -> URL? {
        switch (itemType.console) {
        case .psv:
            switch (itemType.fileType) {
            case .game: return Defaults[.sourcePSVGames]
            case .dlc: return Defaults[.sourcePSVDLCs]
            case .theme: return Defaults[.sourcePSVThemes]
            case .compatPack: return Defaults[.sourceCompatPacks]
            case .compatPatch: return Defaults[.sourceCompatPatch]
            default: break
            }
        case .ps3:
            switch (itemType.fileType) {
            case .game: return Defaults[.sourcePS3Games]
            case .dlc: return Defaults[.sourcePS3DLCs]
            case .theme: return Defaults[.sourcePS3Themes]
            case .avatar: return Defaults[.sourcePS3Avatars]
            default: break
            }
        case .psp: return Defaults[.sourcePSPGames]
        case .psx: return Defaults[.sourcePSXGames]
        }
        
        return nil
    }
}
