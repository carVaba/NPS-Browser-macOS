//
//  WindowDelegate.swift
//  NPS Browser
//
//  Created by JK3Y on 5/12/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

protocol WindowDelegate {
    var region: String { get }
    var searchString: String { get }
    
    var itemType: ItemType { get }
    
    var dataController: DataViewController { get }
    var loadingViewController: LoadingViewController { get }
}
