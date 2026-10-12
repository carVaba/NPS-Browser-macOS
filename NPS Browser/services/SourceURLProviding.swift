import Foundation

protocol SourceURLProviding {
    func sourceURL(for itemType: ItemType) -> URL?
}

struct DefaultsSourceURLs: SourceURLProviding {
    func sourceURL(for itemType: ItemType) -> URL? {
        switch (itemType.console) {
        case .psv:
            switch (itemType.fileType) {
            case .game: return Defaults[.sourcePSVGames]
            case .dlc: return Defaults[.sourcePSVDLCs]
            case .theme: return Defaults[.sourcePSVThemes]
            case .compatPack: return Defaults[.sourceCompatPacks]
            case .compatPatch: return Defaults[.sourceCompatPatch]
            default: break
            }
        case .ps3:
            switch (itemType.fileType) {
            case .game: return Defaults[.sourcePS3Games]
            case .dlc: return Defaults[.sourcePS3DLCs]
            case .theme: return Defaults[.sourcePS3Themes]
            case .avatar: return Defaults[.sourcePS3Avatars]
            default: break
            }
        case .psp: return Defaults[.sourcePSPGames]
        case .psx: return Defaults[.sourcePSXGames]
        }

        return nil
    }
}
