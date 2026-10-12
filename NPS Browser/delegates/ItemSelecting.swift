import Cocoa

protocol ItemSelecting {
    var itemType: ItemType { get }
    var region: String { get }
    var searchString: String { get }
}

protocol DownloadsButtonProviding {
    var downloadsButton: NSView? { get }
}
