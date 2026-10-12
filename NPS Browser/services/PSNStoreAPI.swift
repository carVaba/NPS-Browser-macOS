//
//  PSNStoreAPI.swift
//  NPS Browser
//
//  Created by JK3Y on 8/3/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Cocoa

// Realm objects belong to the main thread, so the class stays on the main actor.
@MainActor
class PSNStoreAPI {
    var item: Item
    
    init(item: Item) {
        self.item = item
    }
    
    private var imageURL: URL? {
        guard let region = item.region, let contentId = item.contentId else {
            return nil
        }
        var language = "en"
        
        var countryCode: String = region
        
        switch(region) {
        case "EU": countryCode = "GB"
        case "JP":
            language = "ja"
            countryCode = "JP"
        case "ASIA": countryCode = "SG"
        default: countryCode = region
        }
        
        let psnUrl = "https://store.playstation.com/store/api/chihiro/00_09_000/container/\(countryCode)/\(language)/19/\(contentId)/1534563384000/image?w=248&h=248"
        return URL(string: psnUrl)
    }
    
    func fetchImage() async -> NSImage {
        if let imageURL = imageURL {
            do {
                let data = try await HTTPClient.data(from: imageURL)
                if let image = NSImage(data: data) {
                    return image
                }
            } catch {
                log.debug(error)
            }
        }

        log.info("No image found for \(item.titleId ?? "") - \(item.name ?? "")")
        let configuration = NSImage.SymbolConfiguration(pointSize: 120, weight: .thin)
        return NSImage.symbol("photo").withSymbolConfiguration(configuration) ?? NSImage.symbol("photo")
    }
}
