import Cocoa

extension NSImage {
    static func symbol(_ name: String) -> NSImage {
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }
}

extension NSTableView {
    // A list with one column fills its scroll view, so it does not scroll sideways.
    func fitSingleColumnToScrollView() {
        intercellSpacing = NSSize(width: 0, height: intercellSpacing.height)
        columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableColumns.first?.resizingMask = .autoresizingMask
        enclosingScrollView?.hasHorizontalScroller = false
        enclosingScrollView?.horizontalScrollElasticity = .none
        sizeLastColumnToFit()
    }
}

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}

extension NSTextField {
    static func makeLabel(_ text: String = "", font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}
