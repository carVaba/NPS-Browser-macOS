//
//  DBManager.swift
//  NPS Browser
//
//  Created by JK3Y on 8/10/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation
import RealmSwift

// A small wrapper around the default Realm. Use it on the main thread.
final class DBManager {
    private let realm: Realm?

    init() {
        do {
            realm = try Realm()
        } catch {
            log.error(error)
            realm = nil
        }
    }

    func store(_ object: Object) {
        store(contentsOf: [object])
    }

    func store(contentsOf objects: [Object]) {
        write { $0.add(objects) }
    }

    func fetch<T: Object>(_ model: T.Type, predicate: NSPredicate? = nil) -> [T] {
        guard let realm = realm else {
            return []
        }
        let objects = realm.objects(model)
        return Array(predicate.map { objects.filter($0) } ?? objects)
    }

    func delete(_ object: Object) {
        write { $0.delete(object) }
    }

    func deleteAll<T: Object>(_ model: T.Type, predicate: NSPredicate? = nil) throws {
        guard let realm = realm else {
            throw DBError.unavailable
        }
        let objects = realm.objects(model)
        let matching = predicate.map { objects.filter($0) } ?? objects
        try perform(in: realm) {
            realm.delete(matching)
        }
    }

    private func write(_ block: (Realm) -> Void) {
        guard let realm = realm else {
            return
        }
        do {
            try perform(in: realm) {
                block(realm)
            }
        } catch {
            log.error(error)
        }
    }

    private func perform(in realm: Realm, _ block: () -> Void) throws {
        if realm.isInWriteTransaction {
            block()
        } else {
            try realm.write(block)
        }
    }
}

enum DBError: Error {
    case unavailable
}
