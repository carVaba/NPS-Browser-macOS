//
//  WindowController.swift
//  NPS Browser
//
//  Created by JK3Y on 5/6/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import RealmSwift

private extension NSToolbarItem.Identifier {
    static let type = NSToolbarItem.Identifier("type")
    static let region = NSToolbarItem.Identifier("region")
    static let search = NSToolbarItem.Identifier("search")
    static let downloads = NSToolbarItem.Identifier("downloads")
    static let bookmarks = NSToolbarItem.Identifier("bookmarks")
}

class WindowController: NSWindowController, NSToolbarDelegate, WindowDelegate {
    private let tbType = NSPopUpButton(frame: .zero, pullsDown: false)
    private let tbRegion = NSPopUpButton(frame: .zero, pullsDown: false)
    private let tbSearchBar = NSSearchField()
    var delegate: ToolbarDelegate?
    private let loadingSheet = LoadingViewController()
    private var popover: NSPopover?
    private(set) var downloadsButton: NSView?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 520),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "NPS Browser"
        window.minSize = NSSize(width: 600, height: 150)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentViewController = Self.makeSplitViewController()
        window.setContentSize(NSSize(width: 960, height: 520))
        window.center()
        window.setFrameAutosaveName("NPS Browser")

        super.init(window: window)

        configurePopUps()
        configureSearchBar()
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar

        delegate = dataController
    }

    required init?(coder: NSCoder) {
        fatalError("WindowController is created in code.")
    }

    // MARK: - Layout

    private static func makeSplitViewController() -> NSSplitViewController {
        let details = NSSplitViewItem(viewController: DetailsViewController())
        details.minimumThickness = 200
        let artwork = NSSplitViewItem(viewController: GameArtworkViewController())
        artwork.canCollapse = true
        artwork.minimumThickness = 90
        artwork.holdingPriority = NSLayoutConstraint.Priority(260)

        let sidebar = NSSplitViewController()
        sidebar.splitView.isVertical = false
        sidebar.splitView.dividerStyle = .paneSplitter
        sidebar.addSplitViewItem(details)
        sidebar.addSplitViewItem(artwork)

        let list = NSSplitViewItem(contentListWithViewController: DataViewController())
        list.minimumThickness = 320
        list.holdingPriority = NSLayoutConstraint.Priority(255)
        let side = NSSplitViewItem(viewController: sidebar)
        side.canCollapse = true
        side.minimumThickness = 240
        side.maximumThickness = 420
        side.holdingPriority = NSLayoutConstraint.Priority(260)

        let main = NSSplitViewController()
        main.splitView.isVertical = true
        main.splitView.dividerStyle = .thin
        main.addSplitViewItem(list)
        main.addSplitViewItem(side)
        return main
    }

    private func configurePopUps() {
        let regions: [(String, Int)] = [("US", 0), ("EU", 1), ("JP", 2), ("ASIA", 3)]
        for (title, tag) in regions {
            tbRegion.addItem(withTitle: title.localized)
            tbRegion.lastItem?.tag = tag
        }

        let types: [(String, Int)?] = [
            ("PSV Games", 0), ("PSV DLCs", 1), ("PSV Themes", 2), nil,
            ("PS3 Games", 0), ("PS3 DLCs", 1), ("PS3 Themes", 2), ("PS3 Avatars", 4), nil,
            ("PSP Games", 0), ("PSX Games", 0)
        ]
        for entry in types {
            guard let (title, tag) = entry else {
                tbType.menu?.addItem(.separator())
                continue
            }
            tbType.addItem(withTitle: title.localized)
            tbType.lastItem?.tag = tag
        }

        for popUp in [tbType, tbRegion] {
            popUp.bezelStyle = .texturedRounded
            popUp.target = self
        }
        tbType.action = #selector(onTypeChanged(_:))
        tbRegion.action = #selector(onRegionChanged(_:))
    }

    private func configureSearchBar() {
        tbSearchBar.placeholderString = "Search".localized
        tbSearchBar.target = self
        tbSearchBar.action = #selector(onFilterSearchBar(_:))
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.type, .region, .space, .search, .space, .flexibleSpace, .downloads, .bookmarks]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.type, .region, .search, .downloads, .bookmarks, .space, .flexibleSpace]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .type:
            return makeItem(.type, label: "Type", view: tbType)
        case .region:
            return makeItem(.region, label: "Region", view: tbRegion)
        case .search:
            let item = NSSearchToolbarItem(itemIdentifier: .search)
            item.label = "Search".localized
            item.paletteLabel = item.label
            item.searchField = tbSearchBar
            return item
        case .downloads:
            let button = makeButton(symbol: "arrow.down.circle", action: #selector(showDownloads(_:)))
            downloadsButton = button
            return makeItem(.downloads, label: "Downloads", view: button)
        case .bookmarks:
            let button = makeButton(symbol: "book", action: #selector(showBookmarks(_:)))
            return makeItem(.bookmarks, label: "Bookmarks", view: button)
        default:
            return nil
        }
    }

    private func makeItem(_ identifier: NSToolbarItem.Identifier, label: String, view: NSView) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label.localized
        item.paletteLabel = item.label
        item.view = view
        return item
    }

    private func makeButton(symbol: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage.symbol(symbol), target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.imagePosition = .imageOnly
        return button
    }

    // MARK: - Actions

    @objc private func showDownloads(_ sender: NSButton) {
        showPopover(DownloadViewController(), from: sender)
    }

    @objc private func showBookmarks(_ sender: NSButton) {
        showPopover(BookmarksViewController(), from: sender)
    }

    private func showPopover(_ controller: NSViewController, from button: NSButton) {
        popover?.close()
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        self.popover = popover
    }

    @objc private func onTypeChanged(_ sender: Any) {
        delegate?.filterType(itemType: itemType, region: region)
    }

    @objc private func onRegionChanged(_ sender: Any) {
        delegate?.filterType(itemType: itemType, region: region)
    }

    @objc private func onFilterSearchBar(_ sender: NSSearchField) {
        let searchString = tbSearchBar.stringValue

        if (!searchString.isEmpty) {
            delegate?.filterString(itemType: itemType, region: region, searchString: searchString)
        } else {
            delegate?.filterType(itemType: itemType, region: region)
        }
    }

    @objc func reloadDatabase(_ sender: Any?) {
        Task { await NetworkManager().makeRequest() }
    }

    // MARK: - WindowDelegate

    var dataController: DataViewController {
        let splitViewController = window!.contentViewController as! NSSplitViewController
        return splitViewController.splitViewItems[0].viewController as! DataViewController
    }

    var loadingViewController: LoadingViewController {
        return loadingSheet
    }

    var itemType: ItemType {
        return ItemType(menuTitle: tbType.selectedItem?.title ?? "", fileType: FileType(tag: tbType.selectedItem?.tag ?? 0))
    }

    var searchString: String {
        return tbSearchBar.stringValue.trimmingCharacters(in: .whitespaces)
    }

    var region: String {
        switch tbRegion.selectedItem?.tag {
        case 1: return "EU"
        case 2: return "JP"
        case 3: return "ASIA"
        default: return "US"
        }
    }
}
