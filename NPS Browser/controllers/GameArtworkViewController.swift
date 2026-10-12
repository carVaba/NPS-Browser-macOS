//
//  GameArtworkViewController.swift
//  NPS Browser
//
//  Created by JK3Y on 8/3/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

class GameArtworkViewController: NSViewController {
    let imgBoxart = NSImageView()

    override func loadView() {
        imgBoxart.imageScaling = .scaleProportionallyUpOrDown
        imgBoxart.translatesAutoresizingMaskIntoConstraints = false
        // The artwork has a different size for each game. It scales to the pane and never resizes the pane.
        for axis in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
            imgBoxart.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: axis)
            imgBoxart.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(1), for: axis)
        }
        // Only the template symbol of a missing artwork is tinted. Real artwork is not changed.
        imgBoxart.contentTintColor = .tertiaryLabelColor

        let root = NSView()
        root.addSubview(imgBoxart)
        NSLayoutConstraint.activate([
            imgBoxart.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            imgBoxart.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            imgBoxart.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            imgBoxart.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20)
        ])
        view = root
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
        guard let item = representedObject as? Item else {
            return
        }
        let api = PSNStoreAPI(item: item)
        Task {
            setImage(image: await api.fetchImage())
        }
    }
}
