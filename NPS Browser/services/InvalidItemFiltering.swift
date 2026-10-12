import Foundation

protocol InvalidItemFiltering {
    var hidesInvalidItems: Bool { get }
}

struct DefaultsInvalidItemFilter: InvalidItemFiltering {
    var hidesInvalidItems: Bool {
        Defaults[.hidesInvalidURLItems]
    }
}
