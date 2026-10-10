//
//  Parser.swift
//  NPS Browser
//
//  Created by JK3Y on 8/3/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation
import Fuzi

class Parser {
    func parseTSV(data: String, itemType: ItemType) -> [TSVData] {
        var lines = data.split(whereSeparator: { $0.isNewline }).makeIterator()

        guard let headerLine = lines.next() else {
            return []
        }
        let header = headerLine.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
        guard header.first == "Title ID" else {
            log.error("Unexpected TSV header: \(headerLine)")
            return []
        }

        var parsedData: [TSVData] = []
        while let line = lines.next() {
            let values = line.components(separatedBy: "\t")

            var row: [String: String] = [:]
            for (column, value) in zip(header, values) where !value.isEmpty {
                row[column] = value
            }

            // Item creation needs these values, so rows without them cannot be stored.
            guard row["Title ID"] != nil, row["Region"] != nil, row["Name"] != nil, row["Content ID"] != nil else {
                continue
            }

            parsedData.append(TSVData(type: itemType, row: row))
        }
        return parsedData
    }
    
    func parseCompatPackEntries(data: String, isPatch: Bool = false, typeName: String) -> [CompatPack] {
        var parsedData: [CompatPack] = []
        let rows = data.split(separator: "\n")

        for row in rows {
            let baseURL = "https://gitlab.com/nopaystation_repos/nps_compati_packs/raw/master/"
            let components = row.components(separatedBy: "=")
            let path = components.first ?? ""
            var title_id: String
            if (isPatch) {
                title_id = path.components(separatedBy: "/")[1]
            } else {
                title_id = path.components(separatedBy: "/")[0]
            }
            
            let pack = CompatPack()
            pack.titleId = title_id
            pack.downloadUrl = "\(baseURL)\(path)"
            pack.type = typeName

            parsedData.append(pack)
        }
        return parsedData
    }

    func parseUpdateXML(data: String) -> URL? {
        let xml = data
        var x: String = ""
        
        do {
            let document = try XMLDocument(string: xml)
            
            if let root = document.root {
                guard let lastpkg = root.firstChild(tag: "tag")?.children.last else {
                    return nil
                }
                
                let hp = lastpkg.firstChild(tag: "hybrid_package")
                if hp == nil {
                    x = lastpkg.attributes["url"]!
                } else {
                    x = (hp?.attributes["url"])!
                }
            }
        } catch let error {
            log.error(error)
        }
        
        return URL(string: x)
    }
}
