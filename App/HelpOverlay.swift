// Keybind cheatsheet: translucent overlay listing [keybindings], shown while
// the hyper key is held past the configured delay. Main-thread only.

import AppKit
import SwiftUI

final class HelpOverlay {
    struct Style {
        var opacity = 0.85
        var fontSize = 11.0
        var columns = 3
        var cornerRadius = 12.0
    }

    private let window: NSWindow

    /// `bindings` = raw config keybindings (combo -> command string).
    init(bindings: [String: String], hyperKeyName: String, style: Style) {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.transient, .ignoresCycle]
        window.contentView = NSHostingView(
            rootView: HelpView(rows: Self.rows(from: bindings), hyperKeyName: hyperKeyName, style: style)
        )
    }

    private static func rows(from bindings: [String: String]) -> [(combo: String, command: String)] {
        bindings
            .map { (combo: $0.key.replacingOccurrences(of: "hyper-", with: ""), command: $0.value) }
            .sorted { ($0.command, $0.combo) < ($1.command, $1.combo) }
    }

    /// Shows centered on the screen that currently has keyboard focus.
    func show() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = window.contentView?.fittingSize ?? NSSize(width: 700, height: 500)
        window.setFrame(
            NSRect(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            display: true
        )
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }
}

private struct HelpView: View {
    let rows: [(combo: String, command: String)]
    let hyperKeyName: String
    let style: HelpOverlay.Style

    private var columns: [[(combo: String, command: String)]] {
        let count = max(1, style.columns)
        let perColumn = max(1, Int((Double(rows.count) / Double(count)).rounded(.up)))
        return stride(from: 0, to: rows.count, by: perColumn).map { Array(rows[$0..<min($0 + perColumn, rows.count)]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ancre — hyper = \(hyperKeyName)")
                .font(.system(size: style.fontSize + 2, weight: .bold))
            HStack(alignment: .top, spacing: 24) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(column, id: \.combo) { row in
                            HStack(spacing: 8) {
                                Text(row.combo)
                                    .font(.system(size: style.fontSize, weight: .semibold, design: .monospaced))
                                    .frame(width: style.fontSize * 8.5, alignment: .trailing)
                                    .foregroundStyle(Color.accentColor)
                                Text(row.command)
                                    .font(.system(size: style.fontSize, design: .monospaced))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: style.cornerRadius).fill(.ultraThinMaterial).opacity(style.opacity))
        .fixedSize()
    }
}
