//
//  ToolbarDelegate.swift
//  NPS Browser
//
//  Created by JK3Y on 5/18/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//
protocol ToolbarDelegate: AnyObject {
    // The console, the file type, or the region changed.
    func selectionChanged()

    func searchChanged()
}
