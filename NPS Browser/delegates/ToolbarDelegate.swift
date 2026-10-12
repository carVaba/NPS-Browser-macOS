//
//  ToolbarDelegate.swift
//  NPS Browser
//
//  Created by JK3Y on 5/18/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//
import RealmSwift

protocol ToolbarDelegate: AnyObject {
    func setContent(_ content: Results<Item>?)

    func filterType(itemType: ItemType, region: String)

    func filterString(itemType: ItemType, region: String, searchString: String)
}
