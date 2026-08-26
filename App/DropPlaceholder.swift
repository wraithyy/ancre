// Drop preview for hyper+drag: an overlay covering the monitor that outlines
// how the layout WILL look after the drop — every future tile as an outline,
// the dragged window's slot filled. Main-thread only.

import AppKit
import SwiftUI

final class LayoutPreview {
    /// One future tile in monitor-local top-left coordinates.
    struct Tile {
        let rect: CGRect
        let isDragged: Bool
    }

    private let window: NSWindow
    private let color: NSColor
    private let fillOpacity: Double

    init(color: NSColor, fillOpacity: Double) {
        self.color = color
        self.fillOpacity = fillOpacity
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.transient, .ignoresCycle]
    }

    /// `monitorFrame` in NSScreen coordinates; tiles in monitor-local
    /// top-left coordinates.
    func show(monitorFrame: NSRect, tiles: [Tile]) {
        window.setFrame(monitorFrame, display: false)
        window.contentView = NSHostingView(
            rootView: PreviewView(tiles: tiles, accent: Color(color), fillOpacity: fillOpacity)
        )
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }
}

private struct PreviewView: View {
    let tiles: [LayoutPreview.Tile]
    let accent: Color
    let fillOpacity: Double

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
                RoundedRectangle(cornerRadius: 8)
                    .fill(tile.isDragged ? accent.opacity(fillOpacity) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                accent.opacity(tile.isDragged ? 1 : 0.6),
                                style: StrokeStyle(lineWidth: tile.isDragged ? 2.5 : 1.5, dash: tile.isDragged ? [] : [5])
                            )
                    )
                    .frame(width: tile.rect.width, height: tile.rect.height)
                    .offset(x: tile.rect.minX, y: tile.rect.minY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
