// Focus indicator: borderless overlay window outlining the focused window
// (Hyprland-style active border). Main-thread only — NSWindow requirement.

import AppKit

final class FocusBorder {
    private let window: NSWindow

    init() {
        window = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.transient, .ignoresCycle]
        let view = NSView()
        view.wantsLayer = true
        view.layer?.borderColor = NSColor.controlAccentColor.cgColor
        view.layer?.borderWidth = 2
        view.layer?.cornerRadius = 6
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
