//
//  DataViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 4/28/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import RealmSwift

class DataViewController: NSViewController, ToolbarDelegate, NSTableViewDataSource, NSTableViewDelegate {

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
    private let selection: ItemSelecting
    private let loader: ListLoading

    // Declared before `items`: it sets the default Realm configuration with the migration.
    private var realm: Realm = DBMigration.configureMigration()

    var items: Results<Item>? = try! Realm().objects(Item.self)

    // The rows come straight from the Realm results, so a large list is not copied.
    private var baseResults: Results<Item>?
    private var results: Results<Item>?
    private var isReloading = false

    init(selection: ItemSelecting, loader: ListLoading) {
        self.selection = selection
        self.loader = loader
        super.init(nibName: nil, bundle: nil)
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
        tableView.dataSource = self
        tableView.delegate = self

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        view = scrollView
    }

    override func viewDidAppear() {
        let it = selection.itemType
        let ct = it.console.rawValue
        let ft = it.fileType.rawValue
        let reg = selection.region

        if (items?.isEmpty)! {
            requestData()
        } else {
            setContent(items?.filter(NSPredicate(format: "consoleType == %@ AND fileType == %@ AND region == %@ AND pkgDirectLink != 'MISSING'", ct, ft, reg)))
        }
    }

    // Loads the list from the source, then shows what the toolbar selects.
    func requestData() {
        Task {
            await loader.makeRequest()
            setContent(applySearch(to: typeContent(itemType: selection.itemType, region: selection.region)))
        }
    }

    override var representedObject: Any? {
        didSet {
            self.detailsViewController.representedObject = representedObject
        }
    }

    var predicateString: String {
        var str = "consoleType == %@ AND fileType == %@ AND region == %@ "
        let it = selection.itemType

        if Defaults[.hidesInvalidURLItems] {
            str.append(" AND pkgDirectLink != 'MISSING'")

            switch( it.console ) {
            case .psv:
                str.append(" AND zrif != 'MISSING'")
            default: break
            }
        }
        return str
    }

    func filterType(itemType: ItemType, region: String) {
        let objects = typeContent(itemType: itemType, region: region)

        if objects.isEmpty {
            requestData()
        }

        setContent(applySearch(to: objects))
    }

    private func typeContent(itemType: ItemType, region: String) -> Results<Item> {
        let p = NSPredicate(format: predicateString, itemType.console.rawValue, itemType.fileType.rawValue, region)
        return items!.filter(p)
    }

    // The search text stays active when the console or the region changes.
    private func applySearch(to objects: Results<Item>) -> Results<Item> {
        let searchString = selection.searchString
        if searchString.isEmpty {
            return objects
        }
        return objects.filter("name contains[c] %@", searchString)
    }

    func filterString(itemType: ItemType, region: String, searchString: String) {
        var p = predicateString
        p.append(" AND name contains[c] %@")
        let q = NSPredicate(format: p, itemType.console.rawValue, itemType.fileType.rawValue, region, searchString)

        setContent(items!.filter(q))
    }

    func setContent(_ content: Results<Item>?) {
        baseResults = content
        applySortDescriptor()

        isReloading = true
        tableView.reloadData()
        if (results?.count ?? 0) > 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        isReloading = false

        // The table has no size yet when the first content arrives, so the scroll waits for the layout.
        DispatchQueue.main.async { [weak self] in
            self?.tableView.scrollRowToVisible(0)
        }

        publishSelection()
    }

    private func applySortDescriptor() {
        guard let descriptor = tableView.sortDescriptors.first, let key = descriptor.key else {
            results = baseResults
            return
        }
        results = baseResults?.sorted(byKeyPath: key, ascending: descriptor.ascending)
    }

    private func publishSelection() {
        let row = tableView.selectedRow
        guard row >= 0, let results = results, row < results.count else {
            return
        }
        representedObject = results[row]
    }

    var detailsViewController: DetailsViewController {
        let sc: NSSplitViewController = parent?.children[1] as! NSSplitViewController
        let vc: DetailsViewController = sc.children[0] as! DetailsViewController
        return vc
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return results?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        applySortDescriptor()
        isReloading = true
        tableView.reloadData()
        isReloading = false
        publishSelection()
    }

    // MARK: - NSTableViewDelegate

    func tableViewSelectionDidChange(_ notification: Notification) {
        if !isReloading {
            publishSelection()
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn, let item = results?[row] else {
            return nil
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
