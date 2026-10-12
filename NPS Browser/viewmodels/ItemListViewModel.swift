import Foundation
import RealmSwift

struct ItemSort: Equatable {
    let key: String
    let ascending: Bool
}

// Decides which items the list shows. The controller only draws `rowIDs`.
@MainActor
final class ItemListViewModel {
    private let selection: ItemSelecting
    private let loader: ListLoading
    private let filter: InvalidItemFiltering
    private let provider: ItemProviding

    // The rows come straight from the Realm results, so a large list is not copied.
    private var baseResults: Results<Item>?
    private var itemsByID: [String: Item] = [:]

    private(set) var rowIDs: [String] = []
    var onRowsChanged: (@MainActor () -> Void)?

    var sort: ItemSort? {
        didSet {
            if sort != oldValue {
                rebuildRows()
            }
        }
    }

    init(selection: ItemSelecting, loader: ListLoading, filter: InvalidItemFiltering, provider: ItemProviding) {
        self.selection = selection
        self.loader = loader
        self.filter = filter
        self.provider = provider
    }

    func item(forID id: String) -> Item? {
        itemsByID[id]
    }

    func start() {
        if provider.allItems?.isEmpty ?? true {
            Task { await reload() }
        } else {
            showSelectedContent()
        }
    }

    // Loads the list from the source, then shows what the toolbar selects.
    func reload() async {
        await loader.makeRequest()
        showSelectedContent()
    }

    func typeChanged() {
        if typeContent()?.isEmpty ?? true {
            Task { await reload() }
        }
        showSelectedContent()
    }

    func searchChanged() {
        showSelectedContent()
    }

    private func typeContent() -> Results<Item>? {
        let itemType = selection.itemType
        var format = "consoleType == %@ AND fileType == %@ AND region == %@"

        if filter.hidesInvalidItems {
            format.append(" AND pkgDirectLink != 'MISSING'")
            if itemType.console == .psv {
                format.append(" AND zrif != 'MISSING'")
            }
        }

        let predicate = NSPredicate(format: format, itemType.console.rawValue, itemType.fileType.rawValue, selection.region)
        return provider.allItems?.filter(predicate)
    }

    // The search text stays active when the console or the region changes.
    private func showSelectedContent() {
        let searchString = selection.searchString
        baseResults = typeContent().map { searchString.isEmpty ? $0 : $0.filter("name contains[c] %@", searchString) }
        rebuildRows()
    }

    private func rebuildRows() {
        var results = baseResults
        if let sort = sort {
            results = results?.sorted(byKeyPath: sort.key, ascending: sort.ascending)
        }

        var ids: [String] = []
        var lookup: [String: Item] = [:]
        if let results = results {
            for (index, item) in results.enumerated() {
                // A snapshot needs unique identifiers, and two rows of the list can share a key.
                let id = lookup[item.pk] == nil ? item.pk : "\(item.pk)#\(index)"
                ids.append(id)
                lookup[id] = item
            }
        }
        itemsByID = lookup
        rowIDs = ids
        onRowsChanged?()
    }
}
