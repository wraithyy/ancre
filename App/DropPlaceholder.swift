// Translucent overlay marking the tile a hyper+dragged window will drop
// into. Main-thread only.

import AppKit

final class DropPlaceholder {
    private let window: NSWindow

    init(color: NSColor) {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.transient, .ignoresCycle]
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = color.withAlphaComponent(0.25).cgColor
        view.layer?.borderColor = color.cgColor
        view.layer?.borderWidth = 2
        view.layer?.cornerRadius = 8
        window.contentView = view
    }

    /// `frame` in NSScreen (bottom-left origin) coordinates.
    func show(frame: NSRect) {
        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }
}
