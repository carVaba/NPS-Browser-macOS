//
//  NSTableView+keydown.swift
//  NPS Browser
//
//  Created by JK3Y on 6/22/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

extension NSTableView {
    override open func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125:
            // Arrow Down
            if (Helpers().dataController.tsvResultsController.canSelectNext) {
                Helpers().dataController.tsvResultsController.setSelectionIndex(selectedRow + 1)
                Helpers().dataController.tableSelectionChanged(self)
            }
            break
        case 126:
            // Arrow Up
            if (Helpers().dataController.tsvResultsController.canSelectPrevious) {
                Helpers().dataController.tsvResultsController.setSelectionIndex(selectedRow - 1)
                Helpers().dataController.tableSelectionChanged(self)
            }
            break
        default:
            break
        }
    }
}
