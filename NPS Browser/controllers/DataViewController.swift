//
//  DataViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 4/28/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import RealmSwift

class DataViewController: NSViewController, ToolbarDelegate {
    
    @IBOutlet var tsvResultsController: NSArrayController!
    @IBOutlet weak var tableView: NSTableView!
    lazy var windowDelegate: WindowDelegate = Helpers().windowDelegate

    var notificationToken: NotificationToken?
    
    private var realm: Realm = {
        return DBMigration.configureMigration()
    }()
    
    var items: Results<Item>? = try! Realm().objects(Item.self)
    
    override func viewDidAppear() {
        let it = windowDelegate.itemType
        let ct = it.console.rawValue
        let ft = it.fileType.rawValue
        let reg = windowDelegate.region

        if (items?.isEmpty)! {
            Task { await NetworkManager().makeRequest() }
        } else {
            setArrayControllerContent(content: items?.filter(NSPredicate(format: "consoleType == %@ AND fileType == %@ AND region == %@ AND pkgDirectLink != 'MISSING'", ct, ft, reg)))
        }
    }

    override var representedObject: Any? {
        didSet {
            self.detailsViewController.representedObject = representedObject
        }
    }

    @IBAction func tableSelectionChanged(_ sender: NSTableView) {
        if (!tsvResultsController.selectedObjects.isEmpty) {
            self.representedObject = tsvResultsController.selectedObjects.first
        }
    }
    
    var predicateString: String {
        var str = "consoleType == %@ AND fileType == %@ AND region == %@ "
        let it = windowDelegate.itemType
        
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
        let p = NSPredicate(format: predicateString, itemType.console.rawValue, itemType.fileType.rawValue, region)
        let objects = items!.filter(p)
        
        if objects.isEmpty {
            Task { await NetworkManager().makeRequest() }
        }

        // The search text stays active when the console or the region changes.
        let searchString = windowDelegate.searchString
        if searchString.isEmpty {
            setArrayControllerContent(content: objects)
        } else {
            setArrayControllerContent(content: objects.filter("name contains[c] %@", searchString))
        }
    }
    
    func filterString(itemType: ItemType, region: String, searchString: String) {
//        let p = NSPredicate(format: "consoleType == %@ AND fileType == %@ AND region == %@ AND name contains[c] %@ AND pkgDirectLink != 'MISSING'", itemType.console.rawValue, itemType.fileType.rawValue, region, searchString)
        var p = predicateString
        p.append(" AND name contains[c] %@")
        let q = NSPredicate(format: p, itemType.console.rawValue, itemType.fileType.rawValue, region, searchString)

        let objects = items!.filter(q)
        setArrayControllerContent(content: objects)
    }
    
    func setArrayControllerContent(content: Results<Item>?) {
        tsvResultsController.content = Array(content!)
        tsvResultsController.setSelectionIndex(0)
        tableSelectionChanged(tableView)
    }
    
    var detailsViewController: DetailsViewController {
        let sc: NSSplitViewController = parent?.children[1] as! NSSplitViewController
        let vc: DetailsViewController = sc.children[0] as! DetailsViewController
        return vc
    }
}
