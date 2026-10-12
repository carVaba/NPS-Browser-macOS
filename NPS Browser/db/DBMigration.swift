//
//  DBMigration.swift
//  NPS Browser
//
//  Created by JK3Y on 8/25/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation
import RealmSwift

final class DBMigration {
    // MARK: - Properties
    static let currentSchemaVersion: UInt64 = 0
    
    // Sets the default configuration, so every `Realm()` opens the file with the migration.
    static func configureMigration() throws -> Realm {
        let config = Realm.Configuration(
            // Set the new schema version here. This must be greater than the previous version
            schemaVersion: 1,
            
            migrationBlock: { migration, oldSchemaVersion in
                switch oldSchemaVersion {
                case 1:
                    break
                default:
                    // Nothing to do!
                    // Realm will automatically detect new/removed properties and update schema on disk
                    zeroToOne(with: migration)
                }
            }
        )
        
        Realm.Configuration.defaultConfiguration = config
        return try Realm(configuration: config)
    }
    
    
    // MARK: - Migrations
    static func zeroToOne(with migration: Migration) {
        migration.enumerateObjects(ofType: Item.className()) { oldItem, newItem in
            guard let oldItem = oldItem else {
                return
            }
            let key = ["region", "fileType", "titleId", "contentId"].map { oldItem[$0] as? String ?? "" }
            newItem?["pk"] = key.joined()
        }
    }
    
//    static func oneToTwo(with migration: Migration) {
//        // Migration #2
//    }
}
