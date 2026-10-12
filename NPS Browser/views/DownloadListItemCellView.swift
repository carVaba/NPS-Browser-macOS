//
//  DownloadListItemCellView.swift
//  NPS Browser
//
//  Created by JK3Y on 5/19/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class DownloadListItemCellView: NSTableCellView {

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()

    private let btnAction = NSButton()
    private let btnCancel = NSButton()
    private let progressBar = NSProgressIndicator()
    private let statusLabel = NSTextField.makeLabel(font: .messageFont(ofSize: 11))
    private let detailsLabel = NSTextField.makeLabel(font: .messageFont(ofSize: 11))
    private let typeLabel = NSTextField.makeLabel(font: .messageFont(ofSize: 11))
    private var observations: [NSKeyValueObservation] = []
    private let downloads: DownloadQueuing
    var item: DownloadItem?

    init(identifier: NSUserInterfaceItemIdentifier, downloads: DownloadQueuing) {
        self.downloads = downloads
        super.init(frame: .zero)
        self.identifier = identifier

        let name = NSTextField.makeLabel()
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField = name

        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        for (button, symbol, action) in [(btnAction, "pause.circle", #selector(doAction(_:))),
                                         (btnCancel, "xmark.circle", #selector(cancelAction(_:)))] {
            button.image = NSImage.symbol(symbol)
            button.imagePosition = .imageOnly
            button.isBordered = false
            button.target = self
            button.action = action
            button.translatesAutoresizingMaskIntoConstraints = false
        }
        detailsLabel.alignment = .right
        typeLabel.alignment = .right

        for subview in [name, typeLabel, progressBar, statusLabel, detailsLabel, btnAction, btnCancel] {
            addSubview(subview)
        }
        NSLayoutConstraint.activate([
            btnCancel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            btnCancel.centerYAnchor.constraint(equalTo: centerYAnchor),
            btnAction.trailingAnchor.constraint(equalTo: btnCancel.leadingAnchor, constant: -8),
            btnAction.centerYAnchor.constraint(equalTo: centerYAnchor),

            name.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            name.trailingAnchor.constraint(equalTo: typeLabel.leadingAnchor, constant: -8),
            typeLabel.centerYAnchor.constraint(equalTo: name.centerYAnchor),
            typeLabel.trailingAnchor.constraint(equalTo: btnAction.leadingAnchor, constant: -12),

            progressBar.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 6),
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: btnAction.leadingAnchor, constant: -12),

            statusLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: detailsLabel.leadingAnchor, constant: -8),
            detailsLabel.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            detailsLabel.trailingAnchor.constraint(equalTo: btnAction.leadingAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("DownloadListItemCellView is created in code.")
    }

    override var objectValue: Any? {
        didSet {
            observeItem()
        }
    }

    // The download manager changes the item while the cell is on screen, so the cell watches the item.
    private func observeItem() {
        observations = []
        item = objectValue as? DownloadItem
        guard let item = item else {
            return
        }
        refresh()

        let update: (DownloadItem) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        observations = [
            item.observe(\.name) { object, _ in update(object) },
            item.observe(\.progress) { object, _ in update(object) },
            item.observe(\.status) { object, _ in update(object) },
            item.observe(\.timeRemaining) { object, _ in update(object) },
            item.observe(\.isStoppable) { object, _ in update(object) },
            item.observe(\.isResumable) { object, _ in update(object) },
            item.observe(\.isViewable) { object, _ in update(object) }
        ]
    }

    private func refresh() {
        guard let item = item else {
            return
        }
        textField?.stringValue = item.name ?? ""
        typeLabel.stringValue = item.fileType ?? ""
        statusLabel.stringValue = item.status ?? ""
        progressBar.doubleValue = item.progress
        detailsLabel.stringValue = Self.percentFormatter.string(from: NSNumber(value: item.timeRemaining)) ?? ""
        changeImage()
    }

    @objc func doAction(_ sender: Any) {
        if (item?.isResumable)! {
            resumeRequest()
        } else if (item?.isStoppable)! {
            stopRequest()
        } else if (item?.isViewable)! {
            viewFile()
        }
    }

    func changeImage() {
        if (item?.isResumable)! {
            btnAction.image = NSImage.symbol("play.circle")
        } else if (item?.isStoppable)! {
            btnAction.image = NSImage.symbol("pause.circle")
        } else if (item?.isViewable)! {
            btnAction.image = NSImage.symbol("magnifyingglass.circle")
        }
    }

    @objc func cancelAction(_ sender: Any) {
        guard let item = item else {
            return
        }
        downloads.cancel(item)
    }

    func stopRequest() {
        downloads.stop(item!)
    }
    
    func viewFile() {
        var dlLoc = Defaults[.libraryFolder]
        if Defaults[.extractsAfterDownloading] {
            let ct:ConsoleType = ConsoleType(rawValue: item!.consoleType!)!
            let ft:FileType = FileType(rawValue: item!.fileType!)!
            
            dlLoc?.appendPathComponent(item!.consoleType!)
            
            switch (ct) {
            case .psv:
                switch(ft) {
                case .game:
                    dlLoc?.appendPathComponent("app/\(item!.titleId!)")
                case .dlc:
                    dlLoc?.appendPathComponent("addcont/\(item!.titleId!)")
                case .update:
                    dlLoc?.appendPathComponent("patch/\(item!.titleId!)")
                case .theme:
                    dlLoc?.appendPathComponent("bgdl/t")
                default: break
                }
            case .ps3:
                NSWorkspace.shared.open(dlLoc!)
            case .psp:
                dlLoc?.appendPathComponent("pspemu/ISO")
            case .psx:
                dlLoc?.appendPathComponent("pspemu/")
            }
        }
        
        let str = dlLoc?.absoluteString.removingPercentEncoding
        let path = URL(fileURLWithPath: str!, isDirectory: true)
        
        NSWorkspace.shared.open(path)
    }
    
    func resumeRequest() {
        item!.status = "Resuming..."
        downloads.resume(item!)
        
        item?.makeStoppable()
    }
}
