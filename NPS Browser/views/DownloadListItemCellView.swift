//
//  DownloadListItemCellView.swift
//  NPS Browser
//
//  Created by JK3Y on 5/19/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class DownloadListItemCellView: NSTableCellView {

    @IBOutlet weak var btnAction: NSButton!
    @IBOutlet weak var btnCancel: NSButton!
    var item: DLItem?
    var dlLoc = Defaults[.dl_library_folder]

    override func awakeFromNib() {
        super.awakeFromNib()
        btnCancel.image = NSImage.symbol("xmark.circle")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Drawing code here.
        item = objectValue as? DLItem
        
        changeImage()
    }
    
    @IBAction func doAction(_ sender: Any) {
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
    
    @IBAction func cancelAction(_ sender: Any) {
        guard let item = item else {
            return
        }
        Helpers().sharedAppDelegate.downloadManager.cancel(item)
    }
    
    func stopRequest() {
        Helpers().sharedAppDelegate.downloadManager.stop(item!)
    }
    
    func viewFile() {
        if Defaults[.xt_extract_after_downloading] {
            let ct:ConsoleType = ConsoleType(rawValue: item!.consoleType!)!
            let ft:FileType = FileType(rawValue: item!.fileType!)!
            
            dlLoc?.appendPathComponent(item!.consoleType!)
            
            switch (ct) {
            case .PSV:
                switch(ft) {
                case .Game:
                    dlLoc?.appendPathComponent("app/\(item!.titleId!)")
                case .DLC:
                    dlLoc?.appendPathComponent("addcont/\(item!.titleId!)")
                case .Update:
                    dlLoc?.appendPathComponent("patch/\(item!.titleId!)")
                case .Theme:
                    dlLoc?.appendPathComponent("bgdl/t")
                default: break
                }
            case .PS3:
                NSWorkspace.shared.open(dlLoc!)
            case .PSP:
                dlLoc?.appendPathComponent("pspemu/ISO")
            case .PSX:
                dlLoc?.appendPathComponent("pspemu/")
            }
        }
        
        let str = dlLoc?.absoluteString.removingPercentEncoding
        let path = URL(fileURLWithPath: str!, isDirectory: true)
        
        NSWorkspace.shared.open(path)
    }
    
    func resumeRequest() {
        item!.status = "Resuming..."
        Helpers().sharedAppDelegate.downloadManager.resume(item!)
        
        item?.makeStoppable()
    }
}
