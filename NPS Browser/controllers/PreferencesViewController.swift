//
//  SettingsViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 4/28/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa
import Foundation

class PreferencesViewController: NSViewController {
    // Sources
    private let psvgField = PreferencesViewController.makeURLField()
    private let psvdlcField = PreferencesViewController.makeURLField()
    private let psvtField = PreferencesViewController.makeURLField()
    private let psxgField = PreferencesViewController.makeURLField()
    private let pspgField = PreferencesViewController.makeURLField()
    private let ps3gField = PreferencesViewController.makeURLField()
    private let ps3dlcField = PreferencesViewController.makeURLField()
    private let ps3tField = PreferencesViewController.makeURLField()
    private let ps3aField = PreferencesViewController.makeURLField()
    private let compatPackField = PreferencesViewController.makeURLField()
    private let compatPatchField = PreferencesViewController.makeURLField()

    // Display
    private let chkHideInvalidURLItems = NSButton(checkboxWithTitle: "Hide items with invalid URLs".localized, target: nil, action: nil)

    // Downloads
    private let ccDLField = NSTextField()
    private let dlPathField = NSTextField()

    // Extraction Methods
    private let chkExtractPKG = NSButton(checkboxWithTitle: "Extract PKG after downloading".localized, target: nil, action: nil)
    private let chkCreateLicense = NSButton(checkboxWithTitle: "Create NoNpDRM license with extraction".localized, target: nil, action: nil)
    private let chkKeepPKG = NSButton(checkboxWithTitle: "Keep PKG after extraction".localized, target: nil, action: nil)
    private let chkSaveZip = NSButton(checkboxWithTitle: "Save decrypted PKG as ZIP file".localized, target: nil, action: nil)
    private let chkCompressPSPISO = NSButton(checkboxWithTitle: "Compress PSP ISO to .CSO".localized, target: nil, action: nil)
    private let compressionFactorStepper = NSStepper()
    private let compressionFactorField = NSTextField()

    var dlLocation: URL?
    var update_checked: Date? = nil

    private static func makeURLField() -> NSTextField {
        let field = NSTextField()
        field.placeholderString = "url goes here".localized
        field.lineBreakMode = .byTruncatingMiddle
        return field
    }

    // MARK: - View

    override func loadView() {
        let integerFormatter = NumberFormatter()
        integerFormatter.numberStyle = .decimal
        integerFormatter.usesGroupingSeparator = false
        integerFormatter.maximumFractionDigits = 0
        ccDLField.formatter = integerFormatter
        ccDLField.placeholderString = "3"
        compressionFactorField.formatter = integerFormatter
        compressionFactorField.placeholderString = "1"

        dlPathField.placeholderString = "Library Location".localized
        dlPathField.isEditable = false

        compressionFactorStepper.minValue = 1
        compressionFactorStepper.maxValue = 9
        compressionFactorStepper.valueWraps = true
        compressionFactorStepper.target = self
        compressionFactorStepper.action = #selector(stepCompressionFactor(_:))
        chkExtractPKG.target = self
        chkExtractPKG.action = #selector(toggleEnableExtractionSettings(_:))
        chkCompressPSPISO.target = self
        chkCompressPSPISO.action = #selector(toggleCompressionFactor(_:))

        let downloads = Self.makeBox("Downloads", content: Self.makeGrid([
            [Self.label("Location"), dlPathField, makeChooseButton(identifier: "folder", action: #selector(selectDLPath(_:)))],
            [Self.label("Concurrent Downloads"), ccDLField]
        ]))
        let display = Self.makeBox("Display", content: chkHideInvalidURLItems)

        let sources: [(String, String, NSTextField)] = [
            ("PSV Games", "psvg", psvgField), ("PSV DLCs", "psvd", psvdlcField), ("PSV Themes", "psvt", psvtField),
            ("PSX Games", "psxg", psxgField), ("PSP Games", "pspg", pspgField),
            ("PS3 Games", "ps3g", ps3gField), ("PS3 DLCs", "ps3d", ps3dlcField),
            ("PS3 Themes", "ps3t", ps3tField), ("PS3 Avatars", "ps3a", ps3aField),
            ("Compat Packs", "compatpack", compatPackField), ("Compat Patches", "compatpatch", compatPatchField)
        ]
        let sourceRows: [[NSView]] = sources.map { title, identifier, field in
            [Self.label(title), field, makeChooseButton(identifier: identifier, action: #selector(chooseTSVFile(_:)))]
        }
        let sourcesBox = Self.makeBox("Sources", content: Self.makeGrid(sourceRows))

        let factorRow = NSStackView(views: [Self.label("Factor"), compressionFactorField, compressionFactorStepper])
        factorRow.orientation = .horizontal
        compressionFactorField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        let extraction = NSStackView(views: [chkExtractPKG, chkCreateLicense, chkKeepPKG, chkSaveZip, chkCompressPSPISO, factorRow])
        extraction.orientation = .vertical
        extraction.alignment = .leading
        extraction.spacing = 8
        let extractionBox = Self.makeBox("Extraction Methods", content: extraction)

        let defaults = NSButton(title: "Use Defaults".localized, target: self, action: #selector(resetToDefaults(_:)))
        defaults.bezelStyle = .inline
        let save = NSButton(title: "Save".localized, target: self, action: #selector(save(_:)))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        let buttons = NSStackView(views: [defaults, NSView(), save])
        buttons.orientation = .horizontal

        let root = NSStackView(views: [downloads, display, sourcesBox, extractionBox, buttons])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        for row in root.arrangedSubviews {
            row.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -40).isActive = true
        }
        root.widthAnchor.constraint(equalToConstant: 640).isActive = true
        view = root
        title = "Preferences".localized
    }

    private static func label(_ text: String) -> NSTextField {
        let field = NSTextField.makeLabel(text.localized)
        field.alignment = .right
        return field
    }

    private static func makeBox(_ title: String, content: NSView) -> NSStackView {
        let header = NSTextField.makeLabel(title.localized, font: .boldSystemFont(ofSize: NSFont.systemFontSize))
        let section = NSStackView(views: [header, content])
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8
        if content is NSGridView {
            content.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        }
        return section
    }

    private static func makeGrid(_ rows: [[NSView]]) -> NSGridView {
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        if grid.numberOfColumns > 1 {
            grid.column(at: 1).xPlacement = .fill
        }
        return grid
    }

    private func makeChooseButton(identifier: String, action: Selector) -> NSButton {
        let button = NSButton(title: "...", target: self, action: action)
        button.bezelStyle = .rounded
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        return button
    }

    override func viewWillAppear() {
        // Remove fullscreen and ability to resize the window
        self.view.window?.styleMask.remove(.fullScreen)
        self.view.window?.styleMask.remove(.resizable)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateTextFields()
    }
    
    @objc func toggleEnableExtractionSettings(_ sender: Any) {
        switch chkExtractPKG.state {
        case .off:
            chkCreateLicense.isEnabled = false
            chkKeepPKG.isEnabled = false
            chkSaveZip.isEnabled = false
            chkCompressPSPISO.isEnabled = false
        case .on:
            chkCreateLicense.isEnabled = true
            chkKeepPKG.isEnabled = true
            chkSaveZip.isEnabled = true
            chkCompressPSPISO.isEnabled = true
        default:
            break
        }
    }
    
    
    @objc func toggleCompressionFactor(_ sender: Any) {
        switch chkCompressPSPISO.state {
        case .on:
            compressionFactorStepper.isEnabled = true
            compressionFactorField.isEnabled = true
        case .off :
            compressionFactorStepper.isEnabled = false
            compressionFactorField.isEnabled = false
        default:
            break
        }
    }
    
    @objc func stepCompressionFactor(_ sender: Any) {
        compressionFactorField.integerValue = compressionFactorStepper.integerValue
    }
    
    func updateTextFields() {
        self.dlLocation = Defaults[.libraryLocation]

        psvgField.stringValue                   = Defaults[.sourcePSVGames]?.absoluteString ?? ""
        psvdlcField.stringValue                 = Defaults[.sourcePSVDLCs]?.absoluteString ?? ""
        psvtField.stringValue                   = Defaults[.sourcePSVThemes]?.absoluteString ?? ""
        psxgField.stringValue                   = Defaults[.sourcePSXGames]?.absoluteString ?? ""
        pspgField.stringValue                   = Defaults[.sourcePSPGames]?.absoluteString ?? ""
        ps3gField.stringValue                   = Defaults[.sourcePS3Games]?.absoluteString ?? ""
        ps3dlcField.stringValue                 = Defaults[.sourcePS3DLCs]?.absoluteString ?? ""
        ps3tField.stringValue                   = Defaults[.sourcePS3Themes]?.absoluteString ?? ""
        ps3aField.stringValue                   = Defaults[.sourcePS3Avatars]?.absoluteString ?? ""
        compatPackField.stringValue             = Defaults[.sourceCompatPacks]?.absoluteString ?? ""
        compatPatchField.stringValue            = Defaults[.sourceCompatPatch]?.absoluteString ?? ""

        chkHideInvalidURLItems.state            = Defaults[.hidesInvalidURLItems] ? .on : .off
        ccDLField.integerValue                  = Defaults[.concurrentDownloads]
        dlPathField.stringValue                 = self.dlLocation!.path

        chkExtractPKG.state                     = Defaults[.extractsAfterDownloading] ? .on : .off
        chkKeepPKG.state                        = Defaults[.keepsPackage] ? .on : .off
        chkSaveZip.state                        = Defaults[.savesAsZip] ? .on : .off
        chkCreateLicense.state                  = Defaults[.createsLicense] ? .on : .off
        chkCompressPSPISO.state                 = Defaults[.compressesPSPISO] ? .on : .off
        
        compressionFactorField.integerValue     = Defaults[.compressionFactor]
        compressionFactorStepper.integerValue   = Defaults[.compressionFactor]
        
        toggleEnableExtractionSettings(self)
        toggleCompressionFactor(self)
    }
    
    @objc func selectDLPath(_ sender: Any) {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        panel.beginSheetModal(for: window) { (result) in
            if result == NSApplication.ModalResponse.OK {
                self.dlLocation = panel.urls[0]
                self.dlPathField.stringValue = self.dlLocation!.path
            }
        }
    }
    
    @objc func chooseTSVFile(_ sender: NSButton) {
        let id = sender.identifier!.rawValue
        
        func openDialog(txtField: NSTextField) {
            guard let window = view.window else { return }
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.beginSheetModal(for: window) { (result) in
                if result == NSApplication.ModalResponse.OK {
                    txtField.stringValue = panel.url!.absoluteString
                }
            }
        }
        
        switch(id) {
        case "psvg": openDialog(txtField: self.psvgField)
        case "psvd": openDialog(txtField: self.psvdlcField)
        case "psvt": openDialog(txtField: self.psvtField)
        case "psxg": openDialog(txtField: self.psxgField)
        case "pspg": openDialog(txtField: self.pspgField)
        case "ps3g": openDialog(txtField: self.ps3gField)
        case "ps3d": openDialog(txtField: self.ps3dlcField)
        case "ps3t": openDialog(txtField: self.ps3tField)
        case "ps3a": openDialog(txtField: self.ps3aField)
        case "compatpack": openDialog(txtField: self.compatPackField)
        case "compatpatch": openDialog(txtField: self.compatPatchField)
        default: break
        }
    }

    @objc func resetToDefaults(_ sender: Any) {
        Defaults.removeAll()
        updateTextFields()
    }
    
    @objc func save(_ sender: Any) {
        storePreferences()
    }
    
    func validateAndStore(urlString: String, endsWith: String, defaultsKey: DefaultsKey<URL?>) throws {
        if urlString.isEmpty {
            Defaults.set(URL(string:""), forKey: defaultsKey._key)
            return
        }

        let url = URL(string: urlString)

        if url?.pathExtension == endsWith {
            Defaults[defaultsKey] = url
        } else {
            Helpers().showAlert(messageText: "Invalid URL", informativeText: "Invalid URL given: \(urlString). File must have extension '.\(endsWith)'", alertStyle: .critical)
            throw NSError()
        }
    }
    
    func storePreferences() {
        do {
            try validateAndStore(urlString: psvgField.stringValue, endsWith: "tsv", defaultsKey: .sourcePSVGames)
            try validateAndStore(urlString: psvdlcField.stringValue, endsWith: "tsv", defaultsKey: .sourcePSVDLCs)
            try validateAndStore(urlString: psvtField.stringValue, endsWith: "tsv", defaultsKey: .sourcePSVThemes)
            try validateAndStore(urlString: psxgField.stringValue, endsWith: "tsv", defaultsKey: .sourcePSXGames)
            try validateAndStore(urlString: pspgField.stringValue, endsWith: "tsv", defaultsKey: .sourcePSPGames)
            try validateAndStore(urlString: ps3gField.stringValue, endsWith: "tsv", defaultsKey: .sourcePS3Games)
            try validateAndStore(urlString: ps3dlcField.stringValue, endsWith: "tsv", defaultsKey: .sourcePS3DLCs)
            try validateAndStore(urlString: ps3tField.stringValue, endsWith: "tsv", defaultsKey: .sourcePS3Themes)
            try validateAndStore(urlString: ps3aField.stringValue, endsWith: "tsv", defaultsKey: .sourcePS3Avatars)
            try validateAndStore(urlString: compatPackField.stringValue, endsWith: "txt", defaultsKey: .sourceCompatPacks)
            try validateAndStore(urlString: compatPatchField.stringValue, endsWith: "txt", defaultsKey: .sourceCompatPatch)

            Defaults[.libraryLocation]      = self.dlLocation!.absoluteURL
            Defaults[.concurrentDownloads]  = ccDLField.integerValue
            
            Defaults[.extractsAfterDownloading] = chkExtractPKG.state == .on
            Defaults[.keepsPackage]                  = chkKeepPKG.state == .on
            Defaults[.savesAsZip]               = chkSaveZip.state == .on
            Defaults[.createsLicense]            = chkCreateLicense.state == .on
            Defaults[.compressesPSPISO]          = chkCompressPSPISO.state == .on
            Defaults[.compressionFactor]        = compressionFactorField.integerValue
            
            Defaults[.hidesInvalidURLItems]   = chkHideInvalidURLItems.state == .on

            
            dismiss(self)
        } catch {
            return
        }
    }
}
