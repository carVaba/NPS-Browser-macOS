import Cocoa

@MainActor
protocol ItemSelecting {
    var itemType: ItemType { get }
    var region: String { get }
    var searchString: String { get }
}

@MainActor
protocol DownloadsButtonProviding {
    var downloadsButton: NSView? { get }
}
