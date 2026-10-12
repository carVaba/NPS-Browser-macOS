//
//  BookmarksViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 6/9/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class BookmarksViewController: NSViewController {
    private static let cellIdentifier = NSUserInterfaceItemIdentifier("bookmarkCell")

    private let tableView = NSTableView()
    private var dataSource: NSTableViewDiffableDataSource<Int, String>?
    private var bookmarksByID: [String: Bookmark] = [:]
    private let downloads: DownloadQueuing
    private let animationTarget: DownloadsButtonProviding
    private let onBookmarkRemoved: (String) -> Void

    init(downloads: DownloadQueuing, animationTarget: DownloadsButtonProviding, onBookmarkRemoved: @escaping (String) -> Void) {
        self.downloads = downloads
        self.animationTarget = animationTarget
        self.onBookmarkRemoved = onBookmarkRemoved
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarksViewController is created in code.")
    }

    override func loadView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bookmark"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 32
        tableView.selectionHighlightStyle = .none
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.fitSingleColumnToScrollView()

        dataSource = NSTableViewDiffableDataSource<Int, String>(tableView: tableView) { [weak self] tableView, _, _, id in
            self?.makeCell(in: tableView, id: id) ?? NSView()
        }

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        tableView.fitSingleColumnToScrollView()

        let title = NSTextField.makeLabel("Bookmarks".localized)
        let root = NSView()
        root.addSubview(title)
        root.addSubview(scrollView)
        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(equalToConstant: 402),
            root.heightAnchor.constraint(equalToConstant: 156),
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            title.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            scrollView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateView()
    }

    private func removeBookmark(_ bookmark: Bookmark) {
        let uuid = bookmark.uuid

        let storedBookmark = DBManager().fetch(Bookmark.self, predicate: NSPredicate(format: "uuid == %@", uuid!)).first

        DBManager().delete(storedBookmark!)

        onBookmarkRemoved(uuid!)

        updateView()
    }

    private func download(_ bookmark: Bookmark, from button: NSButton) {
        DownloadFlyAnimation.run(image: button.image, from: button, to: animationTarget)

        // TODO: Add all 3 download types to DL list

        let downloadItem              = DownloadItem()
        downloadItem.fileType         = bookmark.fileType
        downloadItem.consoleType      = bookmark.consoleType
        downloadItem.titleId          = bookmark.titleId
        downloadItem.name             = bookmark.name
        downloadItem.downloadURL      = URL(string: bookmark.downloadUrl ?? "")
        downloadItem.zrif             = bookmark.zrif

        downloads.enqueue(downloadItem)
    }

    func updateView() {
        let bookmarks = DBManager().fetch(Bookmark.self)
        bookmarksByID = Dictionary(bookmarks.compactMap { bookmark in bookmark.uuid.map { ($0, bookmark) } },
                                   uniquingKeysWith: { first, _ in first })

        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(bookmarks.compactMap { $0.uuid })
        Task {
            await dataSource?.show(snapshot, animated: true)
        }
    }

    private func makeCell(in tableView: NSTableView, id: String) -> NSView {
        guard let bookmark = bookmarksByID[id] else {
            return NSView()
        }
        let cell = tableView.makeView(withIdentifier: Self.cellIdentifier, owner: self) as? BookmarkListItemCellView
            ?? BookmarkListItemCellView(identifier: Self.cellIdentifier)
        cell.objectValue = bookmark
        cell.onRemove = { [weak self] bookmark in
            self?.removeBookmark(bookmark)
        }
        cell.onDownload = { [weak self] bookmark, button in
            self?.download(bookmark, from: button)
        }
        return cell
    }
}
