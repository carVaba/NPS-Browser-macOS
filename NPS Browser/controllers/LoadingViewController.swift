//
//  LoadingViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 6/23/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class LoadingViewController: NSViewController, LoadingViewDelegate {
    private let progressIndicator = NSProgressIndicator()
    private let txtStatus = NSTextField.makeLabel()

    override func loadView() {
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 100
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(progressIndicator)
        root.addSubview(txtStatus)
        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(equalToConstant: 301),
            root.heightAnchor.constraint(equalToConstant: 83),
            progressIndicator.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            progressIndicator.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            progressIndicator.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            txtStatus.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 8),
            txtStatus.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            txtStatus.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20)
        ])
        view = root
        title = "Loading...".localized
    }

    override func viewWillDisappear() {
        progressIndicator.doubleValue = 0.0
        setLabel(text: "")
    }

    func setLabel(text: String) {
        self.txtStatus.stringValue = text
    }

    func setProgress(amount: Double) {
        self.progressIndicator.increment(by: amount)
    }

    func closeWindow() {
        if (self.presentingViewController != nil) {
            dismiss(self)
        } else {
            return
        }
    }
}
