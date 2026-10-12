//
//  BookmarkListItemCellView.swift
//  NPS Browser
//
//  Created by JK3Y on 6/9/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class BookmarkListItemCellView: NSTableCellView {
    private let btnDownload = NSButton()
    private let btnRemove = NSButton()
    var item: Bookmark?
    var onRemove: ((Bookmark) -> Void)?
    var onDownload: ((Bookmark, NSButton) -> Void)?

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier

        let name = NSTextField.makeLabel()
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        name.lineBreakMode = .byTruncatingMiddle
        textField = name

        for (button, symbol, action) in [(btnDownload, "arrow.down.circle", #selector(btnDownloadClicked(_:))),
                                         (btnRemove, "trash", #selector(btnRemoveClicked(_:)))] {
            button.image = NSImage.symbol(symbol)
            button.imagePosition = .imageOnly
            button.isBordered = false
            button.target = self
            button.action = action
        }
        btnDownload.toolTip = "Download".localized

        let buttons = NSStackView(views: [btnDownload, btnRemove])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false

        addSubview(name)
        addSubview(buttons)
        NSLayoutConstraint.activate([
            name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
            name.trailingAnchor.constraint(lessThanOrEqualTo: buttons.leadingAnchor, constant: -8),
            buttons.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            buttons.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarkListItemCellView is created in code.")
    }

    override var objectValue: Any? {
        didSet {
            item = objectValue as? Bookmark
            textField?.stringValue = item?.name ?? ""
            textField?.toolTip = item?.name
        }
    }

    @objc func btnDownloadClicked(_ sender: NSButton) {
        if let item = item {
            onDownload?(item, sender)
        }
    }

    @objc func btnRemoveClicked(_ sender: NSButton) {
        if let item = item {
            onRemove?(item)
        }
    }
}
