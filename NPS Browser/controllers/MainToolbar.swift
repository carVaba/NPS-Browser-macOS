//
//  MainToolbar.swift
//  NPS Browser
//

import Cocoa

private extension NSToolbarItem.Identifier {
    static let type = NSToolbarItem.Identifier("type")
    static let region = NSToolbarItem.Identifier("region")
    static let search = NSToolbarItem.Identifier("search")
    static let downloads = NSToolbarItem.Identifier("downloads")
    static let bookmarks = NSToolbarItem.Identifier("bookmarks")
}

// Owns the toolbar items and tells what the user selected there.
@MainActor
final class MainToolbar: NSObject, NSToolbarDelegate, ItemSelecting, DownloadsButtonProviding {
    let toolbar = NSToolbar(identifier: "MainToolbar")
    weak var delegate: ToolbarDelegate?
    var onShowDownloads: ((NSButton) -> Void)?
    var onShowBookmarks: ((NSButton) -> Void)?
    private(set) var downloadsButton: NSView?

    private let tbType = NSPopUpButton(frame: .zero, pullsDown: false)
    private let tbRegion = NSPopUpButton(frame: .zero, pullsDown: false)
    private let tbSearchBar = NSSearchField()

    override init() {
        super.init()
        configurePopUps()
        tbSearchBar.placeholderString = "Search".localized
        tbSearchBar.target = self
        tbSearchBar.action = #selector(onFilterSearchBar(_:))

        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
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
        tbType.action = #selector(onSelectionChanged(_:))
        tbRegion.action = #selector(onSelectionChanged(_:))
    }

    // MARK: - ItemSelecting

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
        onShowDownloads?(sender)
    }

    @objc private func showBookmarks(_ sender: NSButton) {
        onShowBookmarks?(sender)
    }

    @objc private func onSelectionChanged(_ sender: Any) {
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
}
