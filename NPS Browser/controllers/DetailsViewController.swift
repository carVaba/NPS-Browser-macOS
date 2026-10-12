//
//  DetailsViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 5/6/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class DetailsViewController: NSViewController {

    private let chkBookmark = NSButton()
    private let btnDownload = NSButton(title: "Download".localized, target: nil, action: nil)
    private let chkDLGame = NSButton(checkboxWithTitle: "Game".localized, target: nil, action: nil)
    private let chkDLUpdate = NSButton(checkboxWithTitle: "Update".localized, target: nil, action: nil)
    private let chkDLCompatPack = NSButton(checkboxWithTitle: "CPack", target: nil, action: nil)
    private let nameLabel = NSTextField(wrappingLabelWithString: "")
    private let regionLabel = NSTextField.makeLabel()
    private let requiredFWLabel = NSTextField.makeLabel()

    private let downloads: DownloadQueuing
    private let animationTarget: DownloadsButtonProviding
    private let updates: UpdateLinkFetching
    private let artwork: GameArtworkViewController

    init(downloads: DownloadQueuing, animationTarget: DownloadsButtonProviding, updates: UpdateLinkFetching,
         artwork: GameArtworkViewController) {
        self.downloads = downloads
        self.animationTarget = animationTarget
        self.updates = updates
        self.artwork = artwork
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("DetailsViewController is created in code.")
    }

    private static let firmwareFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    override func loadView() {
        chkBookmark.setButtonType(.toggle)
        chkBookmark.isBordered = false
        chkBookmark.imagePosition = .imageOnly
        chkBookmark.image = NSImage.symbol("star")
        let yellow = NSImage.SymbolConfiguration(paletteColors: [.systemYellow])
        chkBookmark.alternateImage = NSImage.symbol("star.fill").withSymbolConfiguration(yellow)
        chkBookmark.target = self
        chkBookmark.action = #selector(btnBookmarkToggle(_:))
        chkBookmark.setContentHuggingPriority(.required, for: .horizontal)

        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.placeholderString = "title name"
        nameLabel.maximumNumberOfLines = 0
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        chkBookmark.setContentCompressionResistancePriority(.required, for: .horizontal)

        regionLabel.alignment = .right
        requiredFWLabel.alignment = .right

        for checkbox in [chkDLGame, chkDLUpdate, chkDLCompatPack] {
            checkbox.state = .on
        }
        btnDownload.bezelStyle = .rounded
        btnDownload.target = self
        btnDownload.action = #selector(btnDownloadClicked(_:))

        let header = NSStackView(views: [nameLabel, chkBookmark])
        header.orientation = .horizontal
        header.alignment = .top
        header.distribution = .fill
        header.spacing = 8

        let separator = NSBox()
        separator.boxType = .separator

        let options = NSStackView(views: [chkDLGame, chkDLUpdate, chkDLCompatPack])
        options.orientation = .horizontal
        options.distribution = .fillEqually

        let content = NSStackView(views: [
            header,
            Self.makeRow(title: "Region:".localized, value: regionLabel),
            Self.makeRow(title: "Required FW:".localized, value: requiredFWLabel),
            separator,
            options,
            btnDownload
        ])
        content.orientation = .vertical
        content.alignment = .centerX
        content.spacing = 12
        content.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        content.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: root.topAnchor),
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            separator.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            options.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            options.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20)
        ])
        for row in content.arrangedSubviews where row is NSStackView && row !== header && row !== options {
            row.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20).isActive = true
            row.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20).isActive = true
        }
        view = root
    }

    private static func makeRow(title: String, value: NSTextField) -> NSStackView {
        let titleLabel = NSTextField.makeLabel(title)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        value.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [titleLabel, value])
        row.orientation = .horizontal
        row.distribution = .fill
        return row
    }

    // A wrapping label needs its width to know its height, so the width is passed back after each layout.
    override func viewDidLayout() {
        super.viewDidLayout()
        if nameLabel.preferredMaxLayoutWidth != nameLabel.frame.width {
            nameLabel.preferredMaxLayoutWidth = nameLabel.frame.width
        }
    }

    override var representedObject: Any? {
        didSet {
            guard let item = representedObject as? Item else {
                chkBookmark.isHidden = true
                return
            }
            chkBookmark.isHidden = false
            nameLabel.stringValue = item.name ?? ""
            regionLabel.stringValue = item.region ?? ""
            requiredFWLabel.stringValue = item.requiredFw.value.flatMap { Self.firmwareFormatter.string(from: NSNumber(value: $0)) } ?? ""

            enableBookmarkButton()
            toggleBookmark()
            enableDownloadOptions()

            artwork.representedObject = representedObject
        }
    }

    @objc func btnDownloadClicked(_ sender: Any) {
        guard let obj = selectedItem else {
            return
        }

        DownloadFlyAnimation.run(image: artwork.imgBoxart.image, from: artwork.imgBoxart, to: animationTarget)

        if (chkDLGame.state == .on) {
            if let link = obj.pkgDirectLink, let url = URL(string: link) {
                self.sendDLData(url: url, fileType: .game)
            }
        }
        if (chkDLUpdate.state == .on && chkDLUpdate.isEnabled && chkDLUpdate.isHidden == false) {
            let url = updates.updateXMLURL(forTitleID: obj.titleId ?? "")
            Task {
                do {
                    let updateURL = try await self.updates.fetchUpdateXML(url: url)
                    self.sendDLData(url: updateURL, fileType: .update)
                } catch {
                    log.error(error)
                }
            }
        }
        if (chkDLCompatPack.state == .on && chkDLCompatPack.isEnabled && chkDLCompatPack.isHidden == false) {
            enqueueCompatDownloads(for: obj)
        }
    }

    private func enqueueCompatDownloads(for obj: Item) {
        guard let console = ConsoleType(rawValue: obj.consoleType ?? ""),
              let type = FileType(rawValue: obj.fileType ?? "") else {
            return
        }

        switch (console, type) {
        case (.ps3, _):
            if let link = obj.downloadRapFile, let url = URL(string: link) {
                sendDLData(url: url, fileType: .rap)
            }
        case (.psv, .game):
            guard let titleID = obj.titleId else {
                return
            }
            let pack = makeCompatItem(for: obj, titleID: titleID, type: "CompatPack", fileType: .compatPack)
            let patch = makeCompatItem(for: obj, titleID: titleID, type: "CompatPatch", fileType: .compatPatch)

            // The patch is unpacked over the pack, so it follows the pack. A game can have only one of them.
            if let pack = pack {
                pack.doNext = patch
                patch?.parentItem = pack
                downloads.enqueue(pack)
            } else if let patch = patch {
                downloads.enqueue(patch)
            }
        default:
            break
        }
    }

    private func makeCompatItem(for obj: Item, titleID: String, type: String, fileType: FileType) -> DownloadItem? {
        let predicate = NSPredicate(format: "titleId == %@ AND type == %@", titleID, type)
        guard let entry = DBManager().fetch(CompatPack.self, predicate: predicate).first,
              let link = entry.downloadUrl, let url = URL(string: link) else {
            return nil
        }
        return DownloadItem(item: obj, downloadURL: url, fileType: fileType)
    }
    
    @objc func btnBookmarkToggle(_ sender: NSButton) {
        guard let item = selectedItem else {
            return
        }
        if (sender.state == .on) {
            DBManager().store(Bookmark(item: item))
        } else if let bookmark = DBManager().fetch(Bookmark.self, predicate: NSPredicate(format: "uuid == %@", item.pk)).first {
            DBManager().delete(bookmark)
        }
    }

    func enableBookmarkButton() {
        guard let item = selectedItem else {
            return
        }
        if (item.pkgDirectLink == "MISSING") {
            btnDownload.isEnabled = false
            chkBookmark.isEnabled = false
        } else {
            btnDownload.isEnabled = true
            chkBookmark.isEnabled = true
        }
    }
    
    func enableDownloadOptions() {
        guard let item = selectedItem,
              let ctype = ConsoleType(rawValue: item.consoleType ?? ""),
              let ftype = FileType(rawValue: item.fileType ?? "") else {
            return
        }
        
        chkDLGame.title = ftype.rawValue
        
        switch(ctype) {
        case .psv:
            switch(ftype) {
            case .game:
                chkDLCompatPack.title = "CPack"
                chkDLGame.isEnabled = true
                chkDLUpdate.isEnabled = true
                chkDLUpdate.isHidden = false
                chkDLCompatPack.isHidden = false
                
                let packs = item.titleId.map { DBManager().fetch(CompatPack.self, predicate: NSPredicate(format: "titleId == %@", $0)) } ?? []
                chkDLCompatPack.isEnabled = !packs.isEmpty
            default:
                chkDLCompatPack.isHidden = true
                chkDLCompatPack.isEnabled = false
                chkDLUpdate.isHidden = true
                chkDLUpdate.isEnabled = false
            }
        case .ps3:
            let rap = item.rap ?? "MISSING"
            chkDLCompatPack.isHidden = false
            chkDLUpdate.isHidden = true
            if (rap == "NOT REQUIRED" || rap == "UNLOCK/LICENSE BY DLC" || rap == "MISSING") {
                chkDLCompatPack.title = rap
                chkDLCompatPack.isEnabled = false
            } else {
                chkDLCompatPack.title = "RAP"
                chkDLCompatPack.isEnabled = true
            }
        default:
            chkDLUpdate.isHidden = true
            chkDLCompatPack.isHidden = true
        }
    }
    
    func toggleBookmark() {
        guard let item = selectedItem else {
            return
        }
        let predicate = NSPredicate(format: "uuid == %@", item.pk)
        let bookmark = DBManager().fetch(Bookmark.self, predicate: predicate)

        chkBookmark.state = bookmark.isEmpty ? .off : .on
    }
    
    func toggleBookmark(comparePK: String) {
        if selectedItem?.pk == comparePK {
            chkBookmark.state = .off
        }
    }

    func sendDLData(url: URL, fileType: FileType) {
        guard let obj = selectedItem else {
            return
        }
        downloads.enqueue(DownloadItem(item: obj, downloadURL: url, fileType: fileType))
    }
    
    var selectedItem: Item? {
        representedObject as? Item
    }
}
