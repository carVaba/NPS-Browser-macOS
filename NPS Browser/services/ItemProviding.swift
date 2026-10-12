import RealmSwift

@MainActor
protocol ItemProviding {
    var allItems: Results<Item> { get }
}

struct RealmItemProvider: ItemProviding {
    private let realm = DBMigration.configureMigration()

    var allItems: Results<Item> {
        realm.objects(Item.self)
    }
}
