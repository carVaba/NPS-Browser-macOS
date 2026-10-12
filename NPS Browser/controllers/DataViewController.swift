//
//  DataViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 4/28/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

// The table asks for sort changes through the data source, which the diffable data source does not forward.
private final class ItemsDataSource: NSTableViewDiffableDataSource<Int, String> {
    var onSortDescriptorsChanged: (() -> Void)?

    @objc func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        onSortDescriptorsChanged?()
    }
}

class DataViewController: NSViewController, ToolbarDelegate, NSTableViewDelegate {

    private struct Column {
        let key: String
        let title: String
        let width: CGFloat
    }

    private static let columns = [
        Column(key: "titleId", title: "Title ID", width: 88),
        Column(key: "region", title: "Region", width: 53),
        Column(key: "name", title: "Name", width: 240),
        Column(key: "fileSize", title: "File Size", width: 70),
        Column(key: "lastModificationDate", title: "Last Modified", width: 96)
    ]

    private static let sizeFormatter = ByteCountFormatter()
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var dataSource: ItemsDataSource?
    private var contentTask: Task<Void, Never>?
    private let viewModel: ItemListViewModel

    private var isReloading = false

    init(viewModel: ItemListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        viewModel.onRowsChanged = { [weak self] in
            self?.showRows()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("DataViewController is created in code.")
    }

    override func loadView() {
        for column in Self.columns {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.key))
            tableColumn.title = column.title.localized
            tableColumn.width = column.width
            tableColumn.minWidth = 40
            tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.key, ascending: true)
            tableColumn.resizingMask = column.key == "name" ? .autoresizingMask : .userResizingMask
            tableView.addTableColumn(tableColumn)
        }
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = false
        tableView.allowsColumnReordering = false
        tableView.rowHeight = 20
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.delegate = self

        let dataSource = ItemsDataSource(tableView: tableView) { [weak self] tableView, tableColumn, _, id in
            self?.makeCell(in: tableView, column: tableColumn, id: id) ?? NSView()
        }
        dataSource.onSortDescriptorsChanged = { [weak self] in
            self?.sortChanged()
        }
        self.dataSource = dataSource

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        view = scrollView
    }

    override func viewDidAppear() {
        viewModel.start()
    }

    // Loads the list from the source again.
    func requestData() {
        Task {
            await viewModel.reload()
        }
    }

    override var representedObject: Any? {
        didSet {
            detailsViewController?.representedObject = representedObject
        }
    }

    func selectionChanged() {
        viewModel.typeChanged()
    }

    func searchChanged() {
        viewModel.searchChanged()
    }

    private func sortChanged() {
        guard let descriptor = tableView.sortDescriptors.first, let key = descriptor.key else {
            viewModel.sort = nil
            return
        }
        viewModel.sort = ItemSort(key: key, ascending: descriptor.ascending)
    }

    // The latest request wins, so a quick series of filter changes shows only the last one.
    private func showRows() {
        contentTask?.cancel()
        contentTask = Task {
            await applyRows()
        }
    }

    private func applyRows() async {
        let ids = viewModel.rowIDs

        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(ids)

        isReloading = true
        await dataSource?.show(snapshot, animated: false)
        isReloading = false
        guard !Task.isCancelled else {
            return
        }

        if !ids.isEmpty {
            isReloading = true
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            isReloading = false
            tableView.scrollRowToVisible(0)
        }
        publishSelection()
    }

    private func publishSelection() {
        let row = tableView.selectedRow
        guard row >= 0, let id = dataSource?.itemIdentifier(forRow: row), let item = viewModel.item(forID: id) else {
            return
        }
        representedObject = item
    }

    // Set by the window controller. The details show the selected row.
    weak var detailsViewController: DetailsViewController?

    // MARK: - NSTableViewDelegate

    func tableViewSelectionDidChange(_ notification: Notification) {
        if !isReloading {
            publishSelection()
        }
    }

    private func makeCell(in tableView: NSTableView, column tableColumn: NSTableColumn, id: String) -> NSView {
        guard let item = viewModel.item(forID: id) else {
            return NSView()
        }
        let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView ?? makeCell(identifier: tableColumn.identifier)
        cell.textField?.stringValue = text(for: item, key: tableColumn.identifier.rawValue)
        return cell
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let label = NSTextField.makeLabel()
        cell.addSubview(label)
        cell.textField = label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    private func text(for item: Item, key: String) -> String {
        switch key {
        case "titleId": return item.titleId ?? ""
        case "region": return item.region ?? ""
        case "name": return item.name ?? ""
        case "fileSize":
            guard let size = item.fileSize.value else { return "" }
            return Self.sizeFormatter.string(fromByteCount: size)
        case "lastModificationDate":
            guard let date = item.lastModificationDate else { return "" }
            return Self.dateFormatter.string(from: date)
        default: return ""
        }
    }
}
