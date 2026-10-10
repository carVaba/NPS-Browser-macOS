//
//  WindowController.swift
//  NPS Browser
//
//  Created by JK3Y on 5/6/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import RealmSwift

class WindowController: NSWindowController, NSToolbarDelegate, WindowDelegate {
    @IBOutlet weak var progressSpinner: NSProgressIndicator!
    @IBOutlet weak var toolbar: NSToolbar!
    @IBOutlet weak var tbType: NSPopUpButton!
    @IBOutlet weak var tbRegion: NSPopUpButton!
    @IBOutlet weak var tbSearchBar: NSSearchField!
    var delegate: ToolbarDelegate?
    private var loadingSheet: LoadingViewController?

    override func windowDidLoad() {
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        super.windowDidLoad()
        let vc: LoadingViewController = self.storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("loadingVC")) as! LoadingViewController
        loadingSheet = vc
        
        self.delegate = dataController
        applyToolbarSymbols()
    }

    private static let toolbarSymbols = [
        "C9BC1AE3-0F74-4220-AC66-B1F4FA0B5EAD": "arrow.down.circle", // Downloads
        "EDF695BA-2023-4936-9543-EAD5EC5E465D": "book",              // Bookmarks
        "2E5BAEB9-691D-4ED3-88EA-C48B89CD7BD9": "arrow.clockwise"    // Reload
    ]

    // The items may not exist yet when the window loads, so the symbols are also set when an item is added.
    private func applyToolbarSymbols() {
        for item in window?.toolbar?.items ?? [] {
            applySymbol(to: item)
        }

        NotificationCenter.default.addObserver(forName: NSToolbar.willAddItemNotification, object: window?.toolbar, queue: .main) { [weak self] notification in
            guard let item = notification.userInfo?["item"] as? NSToolbarItem else {
                return
            }
            MainActor.assumeIsolated {
                self?.applySymbol(to: item)
            }
        }
    }

    private func applySymbol(to item: NSToolbarItem) {
        guard let name = Self.toolbarSymbols[item.itemIdentifier.rawValue] else {
            return
        }
        let image = NSImage.symbol(name)
        item.image = image
        firstButton(in: item.view)?.image = image
    }

    private func firstButton(in view: NSView?) -> NSButton? {
        guard let view = view else {
            return nil
        }
        if let button = view as? NSButton {
            return button
        }
        for subview in view.subviews {
            if let button = firstButton(in: subview) {
                return button
            }
        }
        return nil
    }
    
    @IBAction func onTypeChanged(_ sender: Any) {
        delegate?.filterType(itemType: itemType, region: region)
    }
    
    @IBAction func onRegionChanged(_ sender: Any) {
        delegate?.filterType(itemType: itemType, region: region)
    }

    @IBAction func onFilterSearchBar(_ sender: NSSearchField) {
        let searchString = tbSearchBar.stringValue
        
        if (!searchString.isEmpty) {
            delegate?.filterString(itemType: itemType, region: region, searchString: searchString)
        } else {
            delegate?.filterType(itemType: itemType, region: region)
        }
    }
    
    @IBAction func reloadDatabase(_ sender: NSMenuItem) {
        Task { await NetworkManager().makeRequest() }
    }

//    @IBAction func toggleArtworkSidebar(_ sender: NSMenuItem) {
//        debugPrint(sender)
//
//        let sv = dataController.detailsViewController.getBoxartViewController().parent as! NSSplitViewController
//        let av = sv.splitViewItems.last!
//
//        if av.isCollapsed {
//            av.isCollapsed = false
//
//            sender.title = "Hide Artwork"
//        } else {
//            av.isCollapsed = true
//            sender.title = "Show Artwork"
//        }
//        // TODO: use nextResponder to pass toggleSidebar call to Artwork Controller
////        Respon
//    }
    
    
    var dataController: DataViewController {
        let splitViewController = self.window!.contentViewController! as! NSSplitViewController
        let vc: DataViewController = splitViewController.splitViewItems[0].viewController as! DataViewController
        return vc
    }
    
    var loadingViewController: LoadingViewController {
        return loadingSheet!
    }

    var itemType: ItemType {
//        return
        return ItemType.parseString((tbType.selectedItem?.title)!, ItemType.getTypeFromTag(tbType.selectedItem?.tag ?? 0))
    }
    
    var searchString: String {
        return tbSearchBar.stringValue.trimmingCharacters(in: .whitespaces)
    }
    
    var region: String {
        let tag = tbRegion.selectedItem?.tag
        switch (tag) {
        case 0:
            return "US"
        case 1:
            return "EU"
        case 2:
            return "JP"
        case 3:
            return "ASIA"
        default:
            return "US"
        }
        
//        return region!
    }
    
}

import Foundation
class SplitViewController: NSSplitViewController {
    
    override func toggleSidebar(_ sender: Any?) {
        let mi = sender as! NSMenuItem
        debugPrint(mi.title)

        for view in splitViewItems {
            if view.canCollapse {
                if view.isCollapsed {
                    view.isCollapsed = false
                    mi.title = "Hide Sidebar"
                } else  {
                    view.isCollapsed = true
                    mi.title = "Show Sidebar"
                }
            }
        }
    }
    
}

//class MenuItemController: NSMenuItem {
//    func fds() {
//        self.get
//    }
//    
////    override func menuWillOpen(_ menu: NSMenu) {
//////        menu.su
////    }
//}
