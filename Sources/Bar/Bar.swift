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
    /// Dock notification badge of the owning app ("3", "•"), nil when none.
    public let badge: String?

    public init(windowID: UInt32, pid: pid_t, isFocused: Bool, badge: String?) {
        self.windowID = windowID
        self.pid = pid
        self.isFocused = isFocused
        self.badge = badge
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
    /// Current layout name ("dwindle", "scroll", custom).
    public let layoutName: String

    public init(name: String, displayName: String?, icon: String?, showNumber: Bool, isActive: Bool, windows: [BarWindowItem], layoutName: String) {
        self.name = name
        self.displayName = displayName
        self.icon = icon
        self.showNumber = showNumber
        self.isActive = isActive
        self.windows = windows
        self.layoutName = layoutName
    }
}

public struct BarMonitorSnapshot: Equatable {
    public let monitorID: String
    /// Bar strip in NSScreen (bottom-left origin) coordinates.
    public let barFrame: NSRect
    public let workspaces: [BarWorkspaceItem]
    public let isFocusedMonitor: Bool
    /// Every workspace name across all monitors, for the "move to" menu.
    public let allWorkspaceNames: [String]
    /// Layout names offered in the context menu (built-ins + custom).
    public let availableLayouts: [String]

    public init(monitorID: String, barFrame: NSRect, workspaces: [BarWorkspaceItem], isFocusedMonitor: Bool, allWorkspaceNames: [String], availableLayouts: [String]) {
        self.monitorID = monitorID
        self.barFrame = barFrame
        self.workspaces = workspaces
        self.isFocusedMonitor = isFocusedMonitor
        self.allWorkspaceNames = allWorkspaceNames
        self.availableLayouts = availableLayouts
    }
}

private let dragPrefix = "applland-window:"

public extension NSColor {
    /// Parses "#RRGGBB" or "#RRGGBBAA".
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        guard s.hasPrefix("#") else { return nil }
        s.removeFirst()
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let hasAlpha = s.count == 8
        self.init(
            srgbRed: CGFloat((v >> (hasAlpha ? 24 : 16)) & 0xFF) / 255,
            green: CGFloat((v >> (hasAlpha ? 16 : 8)) & 0xFF) / 255,
            blue: CGFloat((v >> (hasAlpha ? 8 : 0)) & 0xFF) / 255,
            alpha: hasAlpha ? CGFloat(v & 0xFF) / 255 : 1
        )
    }
}

/// Visual knobs resolved from config ([theme] + [bar] overrides).
public struct BarTheme {
    public let opacity: Double
    public let align: String
    public let offsetX: Double
    public let iconSize: CGFloat
    /// nil = system material.
    public let background: NSColor?
    /// nil = system accent.
    public let accent: NSColor?

    public init(opacity: Double, align: String, offsetX: Double, iconSize: CGFloat, background: NSColor?, accent: NSColor?) {
        self.opacity = opacity
        self.align = align
        self.offsetX = offsetX
        self.iconSize = iconSize
        self.background = background
        self.accent = accent
    }
}

public final class BarController {
    private let theme: BarTheme
    private let onSelect: (String) -> Void
    private let onMoveWindow: (UInt32, String) -> Void
    private let onMoveFocusedWindow: (String) -> Void
    private let onFocusWindow: (UInt32) -> Void
    private let onSetLayout: (String, String) -> Void
    private var windows: [String: NSWindow] = [:]
    private var lastSnapshots: [String: BarMonitorSnapshot] = [:]

    public init(
        theme: BarTheme,
        onSelect: @escaping (String) -> Void,
        onMoveWindow: @escaping (UInt32, String) -> Void,
        onMoveFocusedWindow: @escaping (String) -> Void,
        onFocusWindow: @escaping (UInt32) -> Void,
        onSetLayout: @escaping (_ workspace: String, _ layout: String) -> Void
    ) {
        self.theme = theme
        self.onSelect = onSelect
        self.onMoveWindow = onMoveWindow
        self.onMoveFocusedWindow = onMoveFocusedWindow
        self.onFocusWindow = onFocusWindow
        self.onSetLayout = onSetLayout
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
                    allWorkspaceNames: snapshot.allWorkspaceNames,
                    availableLayouts: snapshot.availableLayouts,
                    isFocused: snapshot.isFocusedMonitor,
                    theme: theme,
                    onSelect: onSelect,
                    onMoveWindow: onMoveWindow,
                    onMoveFocusedWindow: onMoveFocusedWindow,
                    onFocusWindow: onFocusWindow,
                    onSetLayout: onSetLayout
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
    let allWorkspaceNames: [String]
    let availableLayouts: [String]
    let isFocused: Bool
    let theme: BarTheme
    let onSelect: (String) -> Void
    let onMoveWindow: (UInt32, String) -> Void
    let onMoveFocusedWindow: (String) -> Void
    let onFocusWindow: (UInt32) -> Void
    let onSetLayout: (String, String) -> Void

    var body: some View {
        HStack {
            if theme.align != "left" { Spacer(minLength: 0) }
            HStack(spacing: 6) {
                ForEach(workspaces, id: \.name) { workspace in
                    WorkspaceCell(
                        workspace: workspace,
                        allWorkspaceNames: allWorkspaceNames,
                        availableLayouts: availableLayouts,
                        isFocusedMonitor: isFocused,
                        accent: theme.accent.map(Color.init) ?? Color.accentColor,
                        iconSize: theme.iconSize,
                        onSelect: onSelect,
                        onMoveWindow: onMoveWindow,
                        onMoveFocusedWindow: onMoveFocusedWindow,
                        onFocusWindow: onFocusWindow,
                        onSetLayout: onSetLayout
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(pillBackground)
            .offset(x: theme.align == "center" ? theme.offsetX : 0)
            if theme.align != "right" { Spacer(minLength: 0) }
        }
        .padding(.leading, theme.align == "left" ? 8 + theme.offsetX : 0)
        .padding(.trailing, theme.align == "right" ? 8 + theme.offsetX : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var pillBackground: some View {
        if let background = theme.background {
            Capsule().fill(Color(background)).opacity(theme.opacity)
        } else {
            Capsule().fill(.ultraThinMaterial).opacity(theme.opacity)
        }
    }
}

private struct WorkspaceCell: View {
    let workspace: BarWorkspaceItem
    let allWorkspaceNames: [String]
    let availableLayouts: [String]
    let isFocusedMonitor: Bool
    let accent: Color
    let iconSize: CGFloat
    let onSelect: (String) -> Void
    let onMoveWindow: (UInt32, String) -> Void
    let onMoveFocusedWindow: (String) -> Void
    let onFocusWindow: (UInt32) -> Void
    let onSetLayout: (String, String) -> Void

    /// A drag hovers over this cell — highlight it as the drop target.
    @State private var isDropTarget = false

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
                        .frame(width: iconSize, height: iconSize)
                        .opacity(window.isFocused ? 1 : 0.75)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(accent, lineWidth: window.isFocused ? 1.5 : 0)
                        )
                        .overlay(alignment: .topTrailing) {
                            if let badge = window.badge {
                                Text(badge.count > 2 ? "9+" : badge)
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 2.5)
                                    .padding(.vertical, 0.5)
                                    .background(Capsule().fill(.red))
                                    .offset(x: 4, y: -4)
                            }
                        }
                        .draggable(dragPrefix + String(window.windowID)) {
                            // Bigger preview so the drag is clearly visible.
                            Image(nsImage: icon).resizable().frame(width: 32, height: 32)
                        }
                        .onTapGesture { onFocusWindow(window.windowID) }
                        .contextMenu {
                            Button("Fokusovat okno") { onFocusWindow(window.windowID) }
                            Menu("Přesunout do") {
                                ForEach(allWorkspaceNames.filter { $0 != workspace.name }, id: \.self) { target in
                                    Button("workspace \(target)") { onMoveWindow(window.windowID, target) }
                                }
                            }
                        }
                }
            }
            if isDropTarget {
                // Placeholder slot where the dragged window's icon will land.
                RoundedRectangle(cornerRadius: 4)
                    .stroke(accent, style: StrokeStyle(lineWidth: 1.5, dash: [3]))
                    .frame(width: iconSize, height: iconSize)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(accent, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                .opacity(isDropTarget ? 1 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7))
        .onTapGesture { onSelect(workspace.name) }
        .help("workspace \(workspace.name)\(workspace.displayName.map { " · \($0)" } ?? "") — layout: \(workspace.layoutName), oken: \(workspace.windows.count)")
        .contextMenu {
            Button("Přepnout na workspace \(workspace.name)") { onSelect(workspace.name) }
            Button("Přesunout fokusované okno sem") { onMoveFocusedWindow(workspace.name) }
            Menu("Layout: \(workspace.layoutName)") {
                ForEach(availableLayouts, id: \.self) { layout in
                    Button {
                        onSetLayout(workspace.name, layout)
                    } label: {
                        if layout == workspace.layoutName {
                            Label(layout, systemImage: "checkmark")
                        } else {
                            Text(layout)
                        }
                    }
                }
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let payload = items.first, payload.hasPrefix(dragPrefix),
                  let id = UInt32(payload.dropFirst(dragPrefix.count)) else { return false }
            onMoveWindow(id, workspace.name)
            return true
        } isTargeted: { targeted in
            isDropTarget = targeted
        }
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
    }

    private var backgroundColor: Color {
        if isDropTarget { return accent.opacity(0.25) }
        return workspace.isActive ? accent.opacity(isFocusedMonitor ? 0.55 : 0.3) : Color.clear
    }
}
