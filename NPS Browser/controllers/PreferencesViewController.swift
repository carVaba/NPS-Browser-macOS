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
    @IBOutlet weak var psvgField: NSTextField!
    @IBOutlet weak var psvdlcField: NSTextField!
    @IBOutlet weak var psvtField: NSTextField!
    @IBOutlet weak var psxgField: NSTextField!
    @IBOutlet weak var pspgField: NSTextField!
    @IBOutlet weak var ps3gField: NSTextField!
    @IBOutlet weak var ps3dlcField: NSTextField!
    @IBOutlet weak var ps3tField: NSTextField!
    @IBOutlet weak var ps3aField: NSTextField!
    @IBOutlet weak var compatPackField: NSTextField!
    @IBOutlet weak var compatPatchField: NSTextField!
    
    // Display
    @IBOutlet weak var chkHideInvalidURLItems: NSButton!
    
    // Downloads
    @IBOutlet weak var ccDLField: NSTextField!
    @IBOutlet weak var dlPathField: NSTextField!
    
    // Extraction Methods
    @IBOutlet weak var chkExtractPKG: NSButton!
    @IBOutlet weak var chkCreateLicense: NSButton!
    @IBOutlet weak var chkKeepPKG: NSButton!
    @IBOutlet weak var chkSaveZip: NSButton!
    @IBOutlet weak var chkCompressPSPISO: NSButton!
    @IBOutlet weak var compressionFactorStepper: NSStepper!
    @IBOutlet weak var compressionFactorField: NSTextField!
//    @IBOutlet weak var chkUnpackPS3Packages: NSButton!
    
    
//    let settings = SettingsManager().getSettings()
    var dlLocation: URL?
    var update_checked: Date? = nil
    
    override func viewWillAppear() {
        // Remove fullscreen and ability to resize the window
        self.view.window?.styleMask.remove(.fullScreen)
        self.view.window?.styleMask.remove(.resizable)
    }

    override func viewDidLoad() {
        updateTextFields()
        super.viewDidLoad()
    }
    
    @IBAction func toggleEnableExtractionSettings(_ sender: Any) {
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
    
    
    @IBAction func toggleCompressionFactor(_ sender: Any) {
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
    
    @IBAction func stepCompressionFactor(_ sender: Any) {
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
    
    @IBAction func selectDLPath(_ sender: Any) {
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
    
    @IBAction func chooseTSVFile(_ sender: NSButton) {
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

    @IBAction func resetToDefaults(_ sender: Any) {
        Defaults.removeAll()
    }
    
    @IBAction func save(_ sender: Any) {
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
