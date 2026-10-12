//
//  FileInfo.swift
//  NPS Browser
//
//  Created by JK3Y on 8/2/18.
//  Copyright © 2018 JK3Y. All rights reserved.
//

import Foundation

enum ConsoleType: String {
    case psv = "PSV"
    case ps3 = "PS3"
    case psx = "PSX"
    case psp = "PSP"
}

enum FileType: String {
    case game = "Game"
    case update = "Update"
    case dlc = "DLC"
    case theme = "Theme"
    case avatar = "Avatar"
    case compatPack = "CPack"
    case compatPatch = "CPatch"
    case rap = "RAP"
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
        self.init(console: console ?? .psv, fileType: fileType)
    }
}

extension FileType {
    init(tag: Int) {
        switch tag {
        case 1: self = .dlc
        case 2: self = .theme
        case 3: self = .update
        case 4: self = .avatar
        case 5: self = .compatPack
        case 6: self = .compatPatch
        case 7: self = .rap
        default: self = .game
        }
    }
}
