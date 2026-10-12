//
//  DetailsViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 5/6/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class DetailsViewController: NSViewController {
    
    @IBOutlet weak var chkBookmark: NSButton!
    @IBOutlet weak var btnDownload: NSButton!
    @IBOutlet weak var chkDLGame: NSButton!
    @IBOutlet weak var chkDLUpdate: NSButton!
    @IBOutlet weak var chkDLCompatPack: NSButton!
    
    var windowDelegate: WindowDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        chkBookmark.image = NSImage.symbol("star")
        let yellow = NSImage.SymbolConfiguration(paletteColors: [.systemYellow])
        chkBookmark.alternateImage = NSImage.symbol("star.fill").withSymbolConfiguration(yellow)
    }

    override var representedObject: Any? {
        didSet {
            enableBookmarkButton()
            toggleBookmark()
            enableDownloadOptions()
            
            boxartViewController.representedObject = representedObject
        }
    }

    @IBAction func btnDownloadClicked(_ sender: Any) {
        let obj = selectedItem

        let artwork = boxartViewController
        DownloadFlyAnimation.run(image: artwork.imgBoxart.image, from: artwork.imgBoxart)

        var baseDownloadItem: DownloadItem? = nil

        if (chkDLGame.state == .on) {
            if let link = obj.pkgDirectLink, let url = URL(string: link) {
                self.sendDLData(url: url, fileType: .Game)
            }
        }
        if (chkDLUpdate.state == .on && chkDLUpdate.isEnabled && chkDLUpdate.isHidden == false) {
            let url = NetworkManager().updateXMLURL(forTitleID: selectedItem.titleId!)
            Task {
                do {
                    let updateURL = try await NetworkManager().fetchUpdateXML(url: url)
                    self.sendDLData(url: updateURL, fileType: .Update)
                } catch {
                    log.error(error)
                }
            }
        }
        if (chkDLCompatPack.state == .on && chkDLCompatPack.isEnabled && chkDLCompatPack.isHidden == false) {
            let ct: ConsoleType = ConsoleType(rawValue: obj.consoleType!)!
            let ft: FileType = FileType(rawValue: obj.fileType!)!
            switch(ct) {
            case .PS3:
                let url = URL(string: obj.downloadRapFile!)
                sendDLData(url: url!, fileType: .RAP)
            case .PSV:
                switch(ft) {
                case .Game:
                    let titleId = obj.titleId
                    
                    if let cpacko: CompatPack = DBManager().fetch(CompatPack.self, predicate: NSPredicate(format: "titleId == %@ AND type == 'CompatPack'", titleId!), sorted: nil).first {
                        let url = URL(string: (cpacko.downloadUrl)!)
                        baseDownloadItem = Helpers().makeDownloadItem(from: obj, downloadURL: url!, fileType: .CPack)
                    }
                    
                    if let cpatcho: CompatPack = DBManager().fetch(CompatPack.self, predicate: NSPredicate(format: "titleId == %@ AND type == 'CompatPatch'", titleId!), sorted: nil).first {
                        let url = URL(string: (cpatcho.downloadUrl)!)
                        let item = Helpers().makeDownloadItem(from: obj, downloadURL: url!, fileType: .CPatch)
                        baseDownloadItem?.doNext = item
                        item.parentItem = baseDownloadItem
                    }
                    
                    Helpers().sharedAppDelegate.downloadManager.enqueue(baseDownloadItem!)
                default: break
                }
            default: break
            }
        }
    }
    
    @IBAction func btnBookmarkToggle(_ sender: NSButton) {
        if (sender.state == .on) {
            let bookmark = Bookmark(item: selectedItem)
            DBManager().store(bookmark)
        } else {
            let bookmark = DBManager().fetch(Bookmark.self, predicate: NSPredicate(format: "uuid == %@", selectedItem.pk)).first
            DBManager().delete(bookmark!)
        }
    }

    func enableBookmarkButton() {
        let link = selectedItem.pkgDirectLink
        if (link == "MISSING") {
            btnDownload.isEnabled = false
            chkBookmark.isEnabled = false
        } else {
            btnDownload.isEnabled = true
            chkBookmark.isEnabled = true
        }
    }
    
    func enableDownloadOptions() {
        let ctype: ConsoleType = ConsoleType(rawValue: selectedItem.consoleType!)!
        let ftype: FileType = FileType(rawValue: selectedItem.fileType!)!
        
        chkDLGame.title = ftype.rawValue
        
        switch(ctype) {
        case .PSV:
            switch(ftype) {
            case .Game:
                let titleId = selectedItem.titleId
                chkDLCompatPack.title = "CPack"
                chkDLGame.isEnabled = true
                chkDLUpdate.isEnabled = true
                chkDLUpdate.isHidden = false
                chkDLCompatPack.isHidden = false
                
                try! RealmStorageContext().fetch(CompatPack.self, predicate: NSPredicate(format: "titleId == %@", titleId!)) { result in
                    if (result.isEmpty) {
                        chkDLCompatPack.isEnabled = false
                    } else {
                        chkDLCompatPack.isEnabled = true
                    }
                }
            default:
                chkDLCompatPack.isHidden = true
                chkDLCompatPack.isEnabled = false
                chkDLUpdate.isHidden = true
                chkDLUpdate.isEnabled = false
            }
        case .PS3:
            let rap = selectedItem.rap!
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
        let predicate = NSPredicate(format: "uuid == %@", selectedItem.pk)
        let bookmark = DBManager().fetch(Bookmark.self, predicate: predicate)

        if bookmark.isEmpty {
            chkBookmark.state = .off
        } else {
            chkBookmark.state = .on
        }
    }
    
    func toggleBookmark(comparePK: String) {
        if selectedItem.pk == comparePK {
            chkBookmark.state = .off
        }
    }

    func sendDLData(url: URL, fileType: FileType) {
        let obj = selectedItem
        let downloadItem = Helpers().makeDownloadItem(from: obj, downloadURL: url, fileType: fileType)
        Helpers().sharedAppDelegate.downloadManager.enqueue(downloadItem)
    }
    
    var selectedItem: Item {
        return representedObject as! Item
    }
    
    var boxartViewController: GameArtworkViewController {
        let vc: GameArtworkViewController = parent?.children[1] as! GameArtworkViewController
        return vc
    }
}
