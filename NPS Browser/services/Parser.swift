//
//  Parser.swift
//  NPS Browser
//
//  Created by JK3Y on 8/3/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation

class Parser {
    func parseTSV(_ text: String, itemType: ItemType) -> [TSVData] {
        var lines = text.split(whereSeparator: { $0.isNewline }).makeIterator()

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
    
    func parseCompatPackEntries(_ text: String, isPatch: Bool = false, typeName: String) -> [CompatPack] {
        var parsedData: [CompatPack] = []
        let rows = text.split(separator: "\n")

        for row in rows {
            let baseURL = "https://gitlab.com/nopaystation_repos/nps_compati_packs/raw/master/"
            let components = row.components(separatedBy: "=")
            let path = components.first ?? ""
            var titleID: String
            if (isPatch) {
                titleID = path.components(separatedBy: "/")[1]
            } else {
                titleID = path.components(separatedBy: "/")[0]
            }
            
            let pack = CompatPack()
            pack.titleId = titleID
            pack.downloadUrl = "\(baseURL)\(path)"
            pack.type = typeName

            parsedData.append(pack)
        }
        return parsedData
    }

    func parseUpdateXML(_ xml: String) -> URL? {
        guard let data = xml.data(using: .utf8) else {
            return nil
        }

        let reader = UpdateXMLReader()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = reader
        guard xmlParser.parse() else {
            log.error(xmlParser.parserError ?? URLError(.cannotParseResponse))
            return nil
        }

        return reader.packageURL.flatMap { URL(string: $0) }
    }
}

// Reads the "url" of the last package in the first <tag> element. A hybrid package wins over the package itself.
private final class UpdateXMLReader: NSObject, XMLParserDelegate {
    private(set) var packageURL: String?
    private var depth = 0
    private var tagCount = 0
    private var insideFirstTag = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        depth += 1

        switch depth {
        case 2 where elementName == "tag":
            tagCount += 1
            insideFirstTag = tagCount == 1
        case 3 where insideFirstTag:
            packageURL = attributeDict["url"]
        case 4 where insideFirstTag && elementName == "hybrid_package":
            packageURL = attributeDict["url"] ?? packageURL
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        if depth == 2 {
            insideFirstTag = false
        }
        depth -= 1
    }
}
