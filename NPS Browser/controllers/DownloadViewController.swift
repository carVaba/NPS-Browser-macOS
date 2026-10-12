//
//  DownloadViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 5/18/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class DownloadViewController: NSViewController {
    private static let cellIdentifier = NSUserInterfaceItemIdentifier("downloadCell")

    private let dlTableView = NSTableView()
    private var dataSource: NSTableViewDiffableDataSource<Int, DownloadItem>?
    private let downloads: DownloadQueuing

    init(downloads: DownloadQueuing) {
        self.downloads = downloads
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("DownloadViewController is created in code.")
    }

    private var listChanges: Task<Void, Never>?

    override func loadView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("download"))
        dlTableView.addTableColumn(column)
        dlTableView.headerView = nil
        dlTableView.rowHeight = 68
        dlTableView.selectionHighlightStyle = .none
        dlTableView.usesAlternatingRowBackgroundColors = true
        dlTableView.fitSingleColumnToScrollView()

        dataSource = NSTableViewDiffableDataSource<Int, DownloadItem>(tableView: dlTableView) { [weak self] tableView, _, _, item in
            self?.makeCell(in: tableView, item: item) ?? NSView()
        }

        let scrollView = NSScrollView()
        scrollView.documentView = dlTableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        dlTableView.fitSingleColumnToScrollView()

        let title = NSTextField.makeLabel("Downloads".localized)
        let clear = NSButton(title: "Clear".localized, target: self, action: #selector(clearCompleted(_:)))
        clear.bezelStyle = .roundRect
        clear.toolTip = "Remove completed and stopped downloads".localized
        clear.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(title)
        root.addSubview(clear)
        root.addSubview(scrollView)
        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(equalToConstant: 402),
            root.heightAnchor.constraint(equalToConstant: 284),
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            title.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            clear.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            clear.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
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

        listChanges = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .downloadListChanged) {
                guard let self = self else { return }
                self.updateView()
            }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        listChanges?.cancel()
    }

    @objc func clearCompleted(_ sender: Any) {
        downloads.removeCompleted()
        updateView()
    }

    func updateView() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, DownloadItem>()
        snapshot.appendSections([0])
        snapshot.appendItems(downloads.downloadItems)
        Task {
            await dataSource?.show(snapshot, animated: true)
        }
    }

    private func makeCell(in tableView: NSTableView, item: DownloadItem) -> NSView {
        let cell = tableView.makeView(withIdentifier: Self.cellIdentifier, owner: self) as? DownloadListItemCellView
            ?? DownloadListItemCellView(identifier: Self.cellIdentifier, downloads: downloads)
        cell.objectValue = item
        return cell
    }
}
