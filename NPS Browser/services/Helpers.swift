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
        return NSApp.windows.first?.windowController as! WindowController
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
    
    func rowObject(for sender: NSButton) -> Any? {
        var superView = sender.superview
        while let view = superView, !(view is NSTableCellView) {
            superView = view.superview
        }
        guard let cell = superView as? NSTableCellView else {
            print("Sender is not in a table view cell!")
            return nil
        }
        
        return cell.objectValue
    }
    
    func makeDownloadItem(from item: Item, downloadURL: URL, fileType: FileType) -> DownloadItem {
        let obj = DownloadItem()
        let _: ConsoleType = ConsoleType.init(rawValue: item.consoleType!)!

        obj.titleId        = item.titleId
        obj.name            = "\(fileType.rawValue) - \(item.name!)"
        obj.downloadURL   = downloadURL
        obj.zrif = item.zrif
        if fileType == .game {
            obj.sha256 = item.sha256
        }
        obj.consoleType = item.consoleType
        obj.fileType = fileType.rawValue

        return obj
    }
    
    func relativeDescription(of date: Date?) -> String {
        if (date == nil) {
            return "Never"
        }
        
        let units = Set<Calendar.Component>([.year, .month, .day, .hour, .minute, .second, .weekOfYear])
        let components = Calendar.current.dateComponents(units, from: date!, to: Date())
        
        if components.year! > 0 {
            return "\(components.year!) " + (components.year! > 1 ? "years ago" : "year ago")

        } else if components.month! > 0 {
            return "\(components.month!) " + (components.month! > 1 ? "months ago" : "month ago")
            
        } else if components.weekOfYear! > 0 {
            return "\(components.weekOfYear!) " + (components.weekOfYear! > 1 ? "weeks ago" : "week ago")
            
        } else if (components.day! > 0) {
            return (components.day! > 1 ? "\(components.day!) days ago" : "Yesterday")
            
        } else if components.hour! > 0 {
            return "\(components.hour!) " + (components.hour! > 1 ? "hours ago" : "hour ago")
            
        } else if components.minute! > 0 {
            return "\(components.minute!) " + (components.minute! > 1 ? "minutes ago" : "minute ago")
        } else {
            return components.second! > 5 ? "\(components.second!) seconds ago" : "Just Now"
        }
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

extension NSImage {
    static func symbol(_ name: String) -> NSImage {
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }
}

extension NSTableView {
    // A list with one column fills its scroll view, so it does not scroll sideways.
    func fitSingleColumnToScrollView() {
        intercellSpacing = NSSize(width: 0, height: intercellSpacing.height)
        columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableColumns.first?.resizingMask = .autoresizingMask
        enclosingScrollView?.hasHorizontalScroller = false
        enclosingScrollView?.horizontalScrollElasticity = .none
        sizeLastColumnToFit()
    }
}
