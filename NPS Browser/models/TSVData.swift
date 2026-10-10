//
//  TSVData.swift
//  NPS Browser
//
//  Created by JK3Y on 8/4/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation

struct TSVData {
    var titleId                 : String?
    var region                  : String?
    var name                    : String?
    var pkgDirectLink           : String?
    var lastModificationDate    : Date?
    var fileSize                : Int64?
    var sha256                  : String?
    var zrif                    : String?
    var contentId               : String?
    var originalName            : String?
    var requiredFw              : Float?
    var rap                     : String?
    var downloadRapFile         : String?
    var consoleType             : ConsoleType
    var fileType                : FileType
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // Columns are read by header name, because the column order differs between the TSV files.
    init(type: ItemType, row: [String: String]) {
        consoleType = type.console
        fileType = type.fileType

        titleId              = row["Title ID"]
        region               = row["Region"]
        name                 = row["Name"]
        pkgDirectLink        = row["PKG direct link"]
        zrif                 = row["zRIF"]
        contentId            = row["Content ID"]
        lastModificationDate = row["Last Modification Date"].flatMap { TSVData.dateFormatter.date(from: $0) }
        originalName         = row["Original Name"]
        fileSize             = row["File Size"].flatMap { Int64($0) }
        sha256               = row["SHA256"]
        requiredFw           = row["Required FW"].flatMap { Float($0) }

        if type.console == .PS3 {
            rap = row["RAP"]
            if let contentId = contentId, let rap = rap {
                downloadRapFile = "https://nopaystation.com/tools/rap2file/\(contentId)/\(rap)"
            }
        } else {
            rap = row["RAP"]
            downloadRapFile = row["Download .RAP file"]
        }
    }
}
