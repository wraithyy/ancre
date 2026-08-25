// Workspace bar (Tasks 3.1 + 3.2): one borderless strip per monitor showing
// that monitor's workspaces as a centered pill. Click switches workspace,
// dragging a window's app icon onto another workspace moves the window,
// right-click offers a menu. All methods must run on the main thread; the WM
// controller marshals snapshots in and dispatches actions via the callbacks.

import AppKit
import SwiftUI
import WMCore

public struct BarWindowItem: Equatable {
    public let windowID: UInt32
    public let pid: pid_t
    /// The globally focused window (accent ring in the bar).
    public let isFocused: Bool

    public init(windowID: UInt32, pid: pid_t, isFocused: Bool) {
        self.windowID = windowID
        self.pid = pid
        self.isFocused = isFocused
    }
}

public struct BarWorkspaceItem: Equatable {
    public let name: String
    /// Custom label from config; nil shows just the number/icon.
    public let displayName: String?
    /// Short icon string (emoji) from config.
    public let icon: String?
    public let showNumber: Bool
    public let isActive: Bool
    /// Windows in layout order; one app icon is rendered per window so each
    /// icon is a draggable handle for that window.
    public let windows: [BarWindowItem]

    public init(name: String, displayName: String?, icon: String?, showNumber: Bool, isActive: Bool, windows: [BarWindowItem]) {
        self.name = name
        self.displayName = displayName
        self.icon = icon
        self.showNumber = showNumber
        self.isActive = isActive
        self.windows = windows
    }
}

public struct BarMonitorSnapshot: Equatable {
    public let monitorID: String
    /// Bar strip in NSScreen (bottom-left origin) coordinates.
    public let barFrame: NSRect
    public let workspaces: [BarWorkspaceItem]
    public let isFocusedMonitor: Bool

    public init(monitorID: String, barFrame: NSRect, workspaces: [BarWorkspaceItem], isFocusedMonitor: Bool) {
        self.monitorID = monitorID
        self.barFrame = barFrame
        self.workspaces = workspaces
        self.isFocusedMonitor = isFocusedMonitor
    }
}

private let dragPrefix = "applland-window:"

public final class BarController {
    private let opacity: Double
    private let onSelect: (String) -> Void
    private let onMoveWindow: (UInt32, String) -> Void
    private let onMoveFocusedWindow: (String) -> Void
    private let onFocusWindow: (UInt32) -> Void
    private var windows: [String: NSWindow] = [:]
    private var lastSnapshots: [String: BarMonitorSnapshot] = [:]

    public init(
        opacity: Double,
        onSelect: @escaping (String) -> Void,
        onMoveWindow: @escaping (UInt32, String) -> Void,
        onMoveFocusedWindow: @escaping (String) -> Void,
        onFocusWindow: @escaping (UInt32) -> Void
    ) {
        self.opacity = opacity
        self.onSelect = onSelect
        self.onMoveWindow = onMoveWindow
        self.onMoveFocusedWindow = onMoveFocusedWindow
        self.onFocusWindow = onFocusWindow
    }

    /// Replaces all bars with the given per-monitor snapshots. Bars for
    /// monitors that disappeared are closed.
    public func update(_ snapshots: [BarMonitorSnapshot]) {
        var seen = Set<String>()
        for snapshot in snapshots {
            seen.insert(snapshot.monitorID)
            guard lastSnapshots[snapshot.monitorID] != snapshot else { continue }
            lastSnapshots[snapshot.monitorID] = snapshot
            let window = windows[snapshot.monitorID] ?? makeWindow()
            windows[snapshot.monitorID] = window
            window.setFrame(snapshot.barFrame, display: true)
            window.contentView = NSHostingView(
                rootView: BarView(
                    workspaces: snapshot.workspaces,
                    isFocused: snapshot.isFocusedMonitor,
                    opacity: opacity,
                    onSelect: onSelect,
                    onMoveWindow: onMoveWindow,
                    onMoveFocusedWindow: onMoveFocusedWindow,
                    onFocusWindow: onFocusWindow
                )
            )
            window.orderFrontRegardless()
        }
        for (id, window) in windows where !seen.contains(id) {
            window.orderOut(nil)
            windows.removeValue(forKey: id)
            lastSnapshots.removeValue(forKey: id)
        }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        return window
    }
}

private struct BarView: View {
    let workspaces: [BarWorkspaceItem]
    let isFocused: Bool
    let opacity: Double
    let onSelect: (String) -> Void
    let onMoveWindow: (UInt32, String) -> Void
    let onMoveFocusedWindow: (String) -> Void
    let onFocusWindow: (UInt32) -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach(workspaces, id: \.name) { workspace in
                    WorkspaceCell(
                        workspace: workspace,
                        isFocusedMonitor: isFocused,
                        onSelect: onSelect,
                        onMoveWindow: onMoveWindow,
                        onMoveFocusedWindow: onMoveFocusedWindow,
                        onFocusWindow: onFocusWindow
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(.ultraThinMaterial).opacity(opacity)
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WorkspaceCell: View {
    let workspace: BarWorkspaceItem
    let isFocusedMonitor: Bool
    let onSelect: (String) -> Void
    let onMoveWindow: (UInt32, String) -> Void
    let onMoveFocusedWindow: (String) -> Void
    let onFocusWindow: (UInt32) -> Void

    var body: some View {
        HStack(spacing: 4) {
            if let icon = workspace.icon {
                Text(icon).font(.system(size: 13))
            }
            if workspace.showNumber {
                Text(workspace.name)
                    .font(.system(size: 13, weight: workspace.isActive ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(workspace.isActive ? Color.primary : Color.secondary)
            }
            if let displayName = workspace.displayName {
                Text(displayName)
                    .font(.system(size: 12, weight: workspace.isActive ? .semibold : .regular))
                    .foregroundStyle(workspace.isActive ? Color.primary : Color.secondary)
            }
            ForEach(Array(workspace.windows.prefix(6).enumerated()), id: \.element.windowID) { _, window in
                if let icon = NSRunningApplication(processIdentifier: window.pid)?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 17, height: 17)
                        .opacity(window.isFocused ? 1 : 0.75)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.accentColor, lineWidth: window.isFocused ? 1.5 : 0)
                        )
                        .draggable(dragPrefix + String(window.windowID))
                        .onTapGesture { onFocusWindow(window.windowID) }
                }
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(workspace.isActive ? Color.accentColor.opacity(isFocusedMonitor ? 0.55 : 0.3) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .onTapGesture { onSelect(workspace.name) }
        .contextMenu {
            Button("Přepnout na workspace \(workspace.name)") { onSelect(workspace.name) }
            Button("Přesunout fokusované okno sem") { onMoveFocusedWindow(workspace.name) }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let payload = items.first, payload.hasPrefix(dragPrefix),
                  let id = UInt32(payload.dropFirst(dragPrefix.count)) else { return false }
            onMoveWindow(id, workspace.name)
            return true
        }
    }
}
