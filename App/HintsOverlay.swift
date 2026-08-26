// Window hints (hyper+o): letter badges over every visible window; pressing
// a letter focuses that window, Esc cancels. Main-thread only.

import AppKit
import SwiftUI

struct HintEntry {
    let letter: String
    let windowID: UInt32
    /// Window frame in CG (top-left) global coordinates.
    let frame: CGRect
}

final class HintsOverlay {
    private final class KeyPanel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private var panel: NSPanel?
    private var keyMonitor: Any?
    private let onChoose: (UInt32) -> Void

    init(onChoose: @escaping (UInt32) -> Void) {
        self.onChoose = onChoose
    }

    var isVisible: Bool { panel != nil }

    /// `union` = union of all display frames in CG coordinates.
    func show(entries: [HintEntry], union: CGRect) {
        hide()
        guard !entries.isEmpty else { return }
        let panel = KeyPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.transient, .ignoresCycle]

        let local = entries.map { entry in
            HintBadge(
                letter: entry.letter,
                position: CGPoint(x: entry.frame.midX - union.minX, y: entry.frame.midY - union.minY)
            )
        }
        panel.contentView = NSHostingView(rootView: HintsView(badges: local))

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        panel.setFrame(DisplayManager_nsRect(union, primaryHeight: primaryHeight), display: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        let byLetter = Dictionary(uniqueKeysWithValues: entries.map { ($0.letter, $0.windowID) })
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // escape
                self.hide()
                return nil
            }
            if let letter = event.charactersIgnoringModifiers?.lowercased(), let windowID = byLetter[letter] {
                self.hide()
                self.onChoose(windowID)
                return nil
            }
            return nil // swallow everything while hints are up
        }
    }

    func hide() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }
}

/// CG (top-left) → NSScreen (bottom-left) rect; local copy to keep this file
/// AppKit-only (the canonical converter lives in AXBridge.DisplayManager).
private func DisplayManager_nsRect(_ rect: CGRect, primaryHeight: CGFloat) -> NSRect {
    NSRect(x: rect.minX, y: primaryHeight - rect.minY - rect.height, width: rect.width, height: rect.height)
}

private struct HintBadge: Identifiable {
    var id: String { letter }
    let letter: String
    /// Position in overlay-local top-left coordinates.
    let position: CGPoint
}

private struct HintsView: View {
    let badges: [HintBadge]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(badges) { badge in
                Text(badge.letter.uppercased())
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                    .shadow(radius: 6)
                    .position(x: badge.position.x, y: badge.position.y)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
