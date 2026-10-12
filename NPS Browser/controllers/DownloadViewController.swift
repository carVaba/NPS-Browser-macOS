//
//  DownloadViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 5/18/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class DownloadViewController: NSViewController {

    @IBOutlet weak var dlTableView: NSTableView!
    @IBOutlet var dlArrayController: NSArrayController!

    private var listObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        dlTableView.fitSingleColumnToScrollView()
        updateView()

        listObserver = NotificationCenter.default.addObserver(forName: .downloadListChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateView()
            }
        }
    }

    deinit {
        if let listObserver = listObserver {
            NotificationCenter.default.removeObserver(listObserver)
        }
    }
    
    @IBAction func clearCompleted(_ sender: Any) {
        Helpers().sharedAppDelegate.downloadManager.removeCompleted()
        updateView()
    }
    
    func updateView() {
        let content = Helpers().sharedAppDelegate.downloadManager.downloadItems
        dlArrayController.content = content
    }
}
