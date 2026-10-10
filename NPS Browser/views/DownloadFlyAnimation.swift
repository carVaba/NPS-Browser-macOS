import Cocoa

@MainActor
enum DownloadFlyAnimation {
    private static let duration: TimeInterval = 0.6
    private static let endSize: CGFloat = 24

    static func run(image: NSImage?, from source: NSView) {
        guard let window = source.window,
              let target = Helpers().windowDelegate.downloadsButton,
              let targetWindow = target.window,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            return
        }

        let start = screenRect(of: source, in: window)
        let targetRect = screenRect(of: target, in: targetWindow)
        let end = NSRect(x: targetRect.midX - endSize / 2, y: targetRect.midY - endSize / 2, width: endSize, height: endSize)

        let flyer = makeFlyer(image: image, frame: start)
        window.addChildWindow(flyer, ordered: .above)
        flyer.orderFront(nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            flyer.animator().setFrame(end, display: true)
            flyer.animator().alphaValue = 0.3
        }, completionHandler: {
            MainActor.assumeIsolated {
                window.removeChildWindow(flyer)
                flyer.orderOut(nil)
            }
        })
    }

    private static func screenRect(of view: NSView, in window: NSWindow) -> NSRect {
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    private static func makeFlyer(image: NSImage?, frame: NSRect) -> NSWindow {
        let flyer = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        flyer.isOpaque = false
        flyer.backgroundColor = .clear
        flyer.hasShadow = true
        flyer.ignoresMouseEvents = true
        flyer.isReleasedWhenClosed = false

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: frame.size))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true
        flyer.contentView = imageView
        return flyer
    }
}
