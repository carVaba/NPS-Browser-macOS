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

    private static let speedFormatter = ByteCountFormatter()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }()

    private static let buttonSize: CGFloat = 24

    private let btnAction = NSButton()
    private let btnCancel = NSButton()
    private let progressBar = ProgressBarView()
    private let statusLabel = NSTextField.makeLabel(font: .messageFont(ofSize: 11))
    private let detailsLabel = NSTextField.makeLabel(font: .messageFont(ofSize: 11))
    private let typeLabel = NSTextField.makeLabel(font: .messageFont(ofSize: 11))
    private var observations: [NSKeyValueObservation] = []
    private let downloads: DownloadQueuing
    private let folders: DownloadFolderLocating
    var item: DownloadItem?

    init(identifier: NSUserInterfaceItemIdentifier, downloads: DownloadQueuing, folders: DownloadFolderLocating) {
        self.downloads = downloads
        self.folders = folders
        super.init(frame: .zero)
        self.identifier = identifier

        let name = NSTextField.makeLabel()
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // Like Safari: a long name keeps its start and its end, and the middle is cut.
        name.lineBreakMode = .byTruncatingMiddle
        textField = name

        progressBar.translatesAutoresizingMaskIntoConstraints = false

        for (button, symbol, action) in [(btnAction, "pause.circle", #selector(doAction(_:))),
                                         (btnCancel, "xmark.circle", #selector(cancelAction(_:)))] {
            button.image = NSImage.symbol(symbol)
            button.imagePosition = .imageOnly
            button.isBordered = false
            button.imageScaling = .scaleProportionallyDown
            button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            button.target = self
            button.action = action
            button.translatesAutoresizingMaskIntoConstraints = false
        }
        detailsLabel.alignment = .right
        typeLabel.alignment = .right
        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(rowClicked(_:))))

        for subview in [name, typeLabel, progressBar, statusLabel, detailsLabel, btnAction, btnCancel] {
            addSubview(subview)
        }
        // The icons have a fixed size, so they stay in place and the bar width does not depend on the icon.
        NSLayoutConstraint.activate([
            btnCancel.widthAnchor.constraint(equalToConstant: Self.buttonSize),
            btnCancel.heightAnchor.constraint(equalToConstant: Self.buttonSize),
            btnAction.widthAnchor.constraint(equalToConstant: Self.buttonSize),
            btnAction.heightAnchor.constraint(equalToConstant: Self.buttonSize),

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
            item.observe(\.bytesPerSecond) { object, _ in update(object) },
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
        textField?.toolTip = item.name
        typeLabel.stringValue = item.fileType ?? ""
        statusLabel.stringValue = item.status ?? ""
        progressBar.fraction = item.progress / 100
        progressBar.fillColor = item.isViewable ? .systemGreen : .controlAccentColor
        detailsLabel.stringValue = detailsText(for: item)
        changeImage()
    }

    // Shows the percent, and the speed with the time left while the download runs.
    private func detailsText(for item: DownloadItem) -> String {
        var parts = [Self.percentFormatter.string(from: NSNumber(value: item.progress / 100)) ?? ""]

        if item.isStoppable, item.bytesPerSecond > 0 {
            parts.append(Self.speedFormatter.string(fromByteCount: Int64(item.bytesPerSecond)) + "/s")
            if item.timeRemaining > 0, let duration = Self.durationFormatter.string(from: item.timeRemaining) {
                parts.append(String(format: "%@ left".localized, duration))
            }
        }
        return parts.joined(separator: " · ")
    }

    @objc func doAction(_ sender: Any) {
        guard let item = item else {
            return
        }
        if item.isResumable {
            resumeRequest()
        } else if item.isStoppable {
            stopRequest()
        } else if item.isViewable {
            viewFile()
        }
    }

    func changeImage() {
        guard let item = item else {
            return
        }
        if item.isResumable {
            btnAction.image = NSImage.symbol("play.circle")
        } else if item.isStoppable {
            btnAction.image = NSImage.symbol("pause.circle")
        } else if item.isViewable {
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
        if let item = item {
            downloads.stop(item)
        }
    }
    
    // A click on a finished download opens its folder.
    @objc private func rowClicked(_ sender: Any) {
        if item?.isViewable == true {
            viewFile()
        }
    }

    func viewFile() {
        guard let item = item, let folder = folders.folder(for: item) else {
            return
        }
        NSWorkspace.shared.open(folder)
    }

    func resumeRequest() {
        guard let item = item else {
            return
        }
        item.status = "Resuming..."
        downloads.resume(item)
        item.makeStoppable()
    }
}
