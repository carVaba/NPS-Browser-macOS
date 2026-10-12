//
//  BookmarksViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 6/9/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class BookmarksViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private static let cellIdentifier = NSUserInterfaceItemIdentifier("bookmarkCell")

    private let tableView = NSTableView()
    private var bookmarks: [Bookmark] = []

    override func loadView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bookmark"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 32
        tableView.selectionHighlightStyle = .none
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.fitSingleColumnToScrollView()

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

        Helpers().dataController.detailsViewController.toggleBookmark(comparePK: uuid!)

        updateView()
    }

    func updateView() {
        bookmarks = DBManager().fetch(Bookmark.self)
        tableView.reloadData()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return bookmarks.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: Self.cellIdentifier, owner: self) as? BookmarkListItemCellView
            ?? BookmarkListItemCellView(identifier: Self.cellIdentifier)
        cell.objectValue = bookmarks[row]
        cell.onRemove = { [weak self] bookmark in
            self?.removeBookmark(bookmark)
        }
        return cell
    }
}
