//
//  WindowController.swift
//  NPS Browser
//
//  Created by JK3Y on 5/6/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

// Builds the main window and connects the screens with the services they use.
class WindowController: NSWindowController {
    private let toolbar: MainToolbar
    private let downloads: DownloadQueuing
    private let dataViewController: DataViewController
    private var popover: NSPopover?

    init(downloads: DownloadQueuing, alerts: AlertPresenting, sources: SourceURLProviding) {
        let toolbar = MainToolbar()
        let loading = LoadingSheetPresenter()
        let network = NetworkManager(selection: toolbar, loading: loading, alerts: alerts, sources: sources)

        let data = DataViewController(selection: toolbar, loader: network)
        loading.host = data
        toolbar.delegate = data

        let details = DetailsViewController(downloads: downloads, animationTarget: toolbar, updates: network)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 520),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "NPS Browser"
        window.minSize = NSSize(width: 600, height: 150)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentViewController = Self.makeSplitViewController(data: data, details: details)
        window.setContentSize(NSSize(width: 960, height: 520))
        window.center()
        window.setFrameAutosaveName("NPS Browser")
        window.toolbar = toolbar.toolbar

        self.toolbar = toolbar
        self.downloads = downloads
        self.dataViewController = data
        super.init(window: window)

        toolbar.onShowDownloads = { [weak self] button in
            guard let self = self else { return }
            self.showPopover(DownloadViewController(downloads: self.downloads), from: button)
        }
        toolbar.onShowBookmarks = { [weak self] button in
            guard let self = self else { return }
            let bookmarks = BookmarksViewController(downloads: self.downloads, animationTarget: self.toolbar) { [weak self] uuid in
                self?.dataViewController.detailsViewController.toggleBookmark(comparePK: uuid)
            }
            self.showPopover(bookmarks, from: button)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("WindowController is created in code.")
    }

    // MARK: - Layout

    private static func makeSplitViewController(data: DataViewController, details detailsController: DetailsViewController) -> NSSplitViewController {
        let details = NSSplitViewItem(viewController: detailsController)
        // The details have a fixed height, so the artwork pane takes the rest and does not depend on the image.
        details.minimumThickness = 270
        details.maximumThickness = 270
        let artwork = NSSplitViewItem(viewController: GameArtworkViewController())
        artwork.canCollapse = true
        artwork.minimumThickness = 90
        artwork.holdingPriority = NSLayoutConstraint.Priority(260)

        let sidebar = NSSplitViewController()
        sidebar.splitView.isVertical = false
        sidebar.splitView.dividerStyle = .paneSplitter
        sidebar.addSplitViewItem(details)
        sidebar.addSplitViewItem(artwork)

        let list = NSSplitViewItem(contentListWithViewController: data)
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

    private func showPopover(_ controller: NSViewController, from button: NSButton) {
        popover?.close()
        let popover = NSPopover()
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        self.popover = popover
    }

    @objc func reloadDatabase(_ sender: Any?) {
        dataViewController.requestData()
    }
}
