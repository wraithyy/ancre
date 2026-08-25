// Workspace bar (Task 3.1): one borderless strip per monitor showing that
// monitor's workspaces as a centered pill; clicking one dispatches through
// the command bus via `onSelect`. Pure AppKit/SwiftUI — all methods must run
// on the main thread; the WM controller marshals snapshots in.

import AppKit
import SwiftUI
import WMCore

public struct BarWorkspaceItem: Equatable {
    public let name: String
    public let isActive: Bool
    /// PIDs of apps with windows in the workspace, layout order, deduped.
    public let appPids: [pid_t]

    public init(name: String, isActive: Bool, appPids: [pid_t]) {
        self.name = name
        self.isActive = isActive
        self.appPids = appPids
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

public final class BarController {
    private let opacity: Double
    private let onSelect: (String) -> Void
    private var windows: [String: NSWindow] = [:]
    private var lastSnapshots: [String: BarMonitorSnapshot] = [:]

    public init(opacity: Double, onSelect: @escaping (String) -> Void) {
        self.opacity = opacity
        self.onSelect = onSelect
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
                    onSelect: onSelect
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

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(workspaces, id: \.name) { workspace in
                    WorkspaceCell(workspace: workspace, isFocusedMonitor: isFocused, onSelect: onSelect)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
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

    var body: some View {
        Button {
            onSelect(workspace.name)
        } label: {
            HStack(spacing: 3) {
                Text(workspace.name)
                    .font(.system(size: 11, weight: workspace.isActive ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(workspace.isActive ? Color.primary : Color.secondary)
                ForEach(Array(workspace.appPids.prefix(5).enumerated()), id: \.offset) { _, pid in
                    if let icon = NSRunningApplication(processIdentifier: pid)?.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(workspace.isActive ? Color.accentColor.opacity(isFocusedMonitor ? 0.55 : 0.3) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
