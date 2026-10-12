import Cocoa

// A thin progress bar. The system bar cannot change its color, so the fill color is drawn here.
final class ProgressBarView: NSView {
    private static let height: CGFloat = 6

    // From 0 to 1.
    var fraction: Double = 0 {
        didSet {
            needsDisplay = true
            setAccessibilityValue(fraction)
        }
    }

    var fillColor: NSColor = .controlAccentColor {
        didSet {
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityRole(.progressIndicator)
    }

    required init?(coder: NSCoder) {
        fatalError("ProgressBarView is created in code.")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        let clamped = min(max(fraction, 0), 1)
        guard clamped > 0 else {
            return
        }
        var fill = bounds
        fill.size.width = max(bounds.width * clamped, bounds.height)
        fillColor.setFill()
        NSBezierPath(roundedRect: fill, xRadius: radius, yRadius: radius).fill()
    }
}
