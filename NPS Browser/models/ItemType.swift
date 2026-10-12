//
//  FileInfo.swift
//  NPS Browser
//
//  Created by JK3Y on 8/2/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation

enum ConsoleType: String {
    case PSV, PS3, PSX, PSP
}

enum FileType: String {
    case Game, Update, DLC, Theme, Avatar, CPack, CPatch, RAP
}

struct ItemType: CustomStringConvertible {
    var console: ConsoleType
    var fileType: FileType
    var description: String {
        return "ConsoleType: \(console.rawValue), FileType: \(fileType.rawValue)"
    }
    init(console: ConsoleType, fileType: FileType) {
        self.console = console
        self.fileType = fileType
    }
    init(menuTitle: String, fileType: FileType) {
        let console = ConsoleType(rawValue: String(menuTitle.split(separator: " ").first ?? ""))
        self.init(console: console ?? .PSV, fileType: fileType)
    }
}

extension FileType {
    init(tag: Int) {
        switch tag {
        case 1: self = .DLC
        case 2: self = .Theme
        case 3: self = .Update
        case 4: self = .Avatar
        case 5: self = .CPack
        case 6: self = .CPatch
        case 7: self = .RAP
        default: self = .Game
        }
    }
}
