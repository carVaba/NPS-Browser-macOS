import RealmSwift

@MainActor
protocol ItemProviding {
    // nil when the database cannot be opened.
    var allItems: Results<Item>? { get }
}

struct RealmItemProvider: ItemProviding {
    private let realm: Realm?

    init() {
        do {
            realm = try DBMigration.configureMigration()
        } catch {
            log.error(error)
            realm = nil
        }
    }

    var allItems: Results<Item>? {
        realm?.objects(Item.self)
    }
}
