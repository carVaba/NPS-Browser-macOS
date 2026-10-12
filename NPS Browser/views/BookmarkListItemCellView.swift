//
//  BookmarkListItemCellView.swift
//  NPS Browser
//
//  Created by JK3Y on 6/9/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class BookmarkListItemCellView: NSTableCellView {
    @IBOutlet weak var btnDownload: NSButton!
    @IBOutlet weak var btnRemove: NSButton!
    var item: Bookmark?

    override func awakeFromNib() {
        super.awakeFromNib()
        btnDownload.image = NSImage.symbol("arrow.down.circle")
        btnRemove.image = NSImage.symbol("trash")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        self.item = objectValue as? Bookmark
    }
    
    @IBAction func btnDownloadClicked(_ sender: NSButton) {
        DownloadFlyAnimation.run(image: sender.image, from: sender)
        
        // TODO: Add all 3 download types to DL list
        
        let downloadItem              = DownloadItem()
        downloadItem.fileType         = self.item?.fileType
        downloadItem.consoleType      = self.item?.consoleType
        downloadItem.titleId         = self.item?.titleId
        downloadItem.name             = self.item?.name
        downloadItem.downloadURL    = URL(string: (self.item?.downloadUrl)!)
        downloadItem.zrif             = self.item?.zrif
        
        
        Helpers().sharedAppDelegate.downloadManager.enqueue(downloadItem)
    }
}
