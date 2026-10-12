//
//  GameArtworkViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 8/3/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class GameArtworkViewController: NSViewController {
    @IBOutlet weak var imgBoxart: NSImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Only the template symbol of a missing artwork is tinted. Real artwork is not changed.
        imgBoxart.contentTintColor = .tertiaryLabelColor
    }

    override var representedObject: Any? {
        didSet {
            imgBoxart.image = nil
            
            loadImage()
        }
    }
    
    private func setImage(image: NSImage) {
//        self.imgBoxart.sizeToFit()
        self.imgBoxart.image = image
    }
    
    func loadImage() {
        let api = PSNStoreApi(item: representedObject as! Item)
        Task {
            setImage(image: await api.fetchImage())
        }
    }
}
