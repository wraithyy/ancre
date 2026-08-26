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
    /// Floating windows get a dashed ring and a "return to tiling" menu item.
    public let isFloating: Bool

    public init(windowID: UInt32, pid: pid_t, isFocused: Bool, badge: String?, isFloating: Bool) {
        self.windowID = windowID
        self.pid = pid
        self.isFocused = isFocused
        self.badge = badge
        self.isFloating = isFloating
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

/// Workspace reference for menus: raw `name` for commands, `title` with
/// icon/custom label for display.
public struct BarWorkspaceRef: Equatable {
    public let name: String
    public let title: String

    public init(name: String, title: String) {
        self.name = name
        self.title = title
    }
}

public struct BarMonitorSnapshot: Equatable {
    public let monitorID: String
    /// Bar strip in NSScreen (bottom-left origin) coordinates.
    public let barFrame: NSRect
    public let workspaces: [BarWorkspaceItem]
    public let isFocusedMonitor: Bool
    /// Every workspace across all monitors, for the "move to" menu.
    public let allWorkspaceNames: [BarWorkspaceRef]
    /// Layout names offered in the context menu (built-ins + custom).
    public let availableLayouts: [String]

    public init(monitorID: String, barFrame: NSRect, workspaces: [BarWorkspaceItem], isFocusedMonitor: Bool, allWorkspaceNames: [BarWorkspaceRef], availableLayouts: [String]) {
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

/// Visual knobs resolved from config ([theme] + [bar] overrides). Defaults
/// here mirror the config defaults; the controller overwrites everything.
public struct BarTheme {
    public var opacity = 1.0
    public var align = "center"
    public var offsetX = 0.0
    public var iconSize: CGFloat = 17
    /// nil = system material.
    public var background: NSColor?
    /// nil = system accent.
    public var accent: NSColor?
    /// Dashed float-indicator ring; nil = white.
    public var floatColor: NSColor?
    /// Notification badge background; nil = system red.
    public var badgeColor: NSColor?
    public var fontSize = 13.0
    /// nil = system font (workspace numbers monospaced).
    public var fontFamily: String?
    public var spacing = 6.0
    public var cellSpacing = 4.0
    public var cellRadius = 6.0
    public var cellPaddingX = 8.0
    public var cellPaddingY = 3.0
    public var pillPaddingX = 10.0
    public var pillPaddingY = 3.0
    public var activeOpacity = 0.55
    public var inactiveIconOpacity = 0.75
    public var ringWidth = 1.5
    public var maxIcons = 6

    public init() {}

    func font(size: Double, weight: Font.Weight, monospaced: Bool = false) -> Font {
        if let fontFamily { return .custom(fontFamily, size: size).weight(weight) }
        return .system(size: size, weight: weight, design: monospaced ? .monospaced : .default)
    }
}

public final class BarController {
    private let theme: BarTheme
    private let onSelect: (String) -> Void
    private let onMoveWindow: (UInt32, String) -> Void
    private let onMoveFocusedWindow: (String) -> Void
    private let onFocusWindow: (UInt32) -> Void
    private let onSetLayout: (String, String) -> Void
    private let onToggleFloat: (UInt32) -> Void
    private let onToggleFullscreen: (UInt32) -> Void
    private var windows: [String: NSWindow] = [:]
    private var lastSnapshots: [String: BarMonitorSnapshot] = [:]

    public init(
        theme: BarTheme,
        onSelect: @escaping (String) -> Void,
        onMoveWindow: @escaping (UInt32, String) -> Void,
        onMoveFocusedWindow: @escaping (String) -> Void,
        onFocusWindow: @escaping (UInt32) -> Void,
        onSetLayout: @escaping (_ workspace: String, _ layout: String) -> Void,
        onToggleFloat: @escaping (UInt32) -> Void,
        onToggleFullscreen: @escaping (UInt32) -> Void
    ) {
        self.theme = theme
        self.onSelect = onSelect
        self.onMoveWindow = onMoveWindow
        self.onMoveFocusedWindow = onMoveFocusedWindow
        self.onFocusWindow = onFocusWindow
        self.onSetLayout = onSetLayout
        self.onToggleFloat = onToggleFloat
        self.onToggleFullscreen = onToggleFullscreen
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
                    onSetLayout: onSetLayout,
                    onToggleFloat: onToggleFloat,
                    onToggleFullscreen: onToggleFullscreen
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

    /// Closes all bar windows (hot-reload replaces the controller). Main thread.
    public func close() {
        for window in windows.values { window.orderOut(nil) }
        windows.removeAll()
        lastSnapshots.removeAll()
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
    let allWorkspaceNames: [BarWorkspaceRef]
    let availableLayouts: [String]
    let isFocused: Bool
    let theme: BarTheme
    let onSelect: (String) -> Void
    let onMoveWindow: (UInt32, String) -> Void
    let onMoveFocusedWindow: (String) -> Void
    let onFocusWindow: (UInt32) -> Void
    let onSetLayout: (String, String) -> Void
    let onToggleFloat: (UInt32) -> Void
    let onToggleFullscreen: (UInt32) -> Void

    var body: some View {
        HStack {
            if theme.align != "left" { Spacer(minLength: 0) }
            HStack(spacing: theme.spacing) {
                ForEach(workspaces, id: \.name) { workspace in
                    WorkspaceCell(
                        workspace: workspace,
                        allWorkspaceNames: allWorkspaceNames,
                        availableLayouts: availableLayouts,
                        isFocusedMonitor: isFocused,
                        theme: theme,
                        onSelect: onSelect,
                        onMoveWindow: onMoveWindow,
                        onMoveFocusedWindow: onMoveFocusedWindow,
                        onFocusWindow: onFocusWindow,
                        onSetLayout: onSetLayout,
                        onToggleFloat: onToggleFloat,
                        onToggleFullscreen: onToggleFullscreen
                    )
                }
            }
            .padding(.horizontal, theme.pillPaddingX)
            .padding(.vertical, theme.pillPaddingY)
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
            // Native default: the menu-bar material with a hairline edge.
            Capsule()
                .fill(.bar)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                .opacity(theme.opacity)
        }
    }
}

private struct WorkspaceCell: View {
    let workspace: BarWorkspaceItem
    let allWorkspaceNames: [BarWorkspaceRef]
    let availableLayouts: [String]
    let isFocusedMonitor: Bool
    let theme: BarTheme
    let onSelect: (String) -> Void
    let onMoveWindow: (UInt32, String) -> Void
    let onMoveFocusedWindow: (String) -> Void
    let onFocusWindow: (UInt32) -> Void
    let onSetLayout: (String, String) -> Void
    let onToggleFloat: (UInt32) -> Void
    let onToggleFullscreen: (UInt32) -> Void

    /// A drag hovers over this cell — highlight it as the drop target.
    @State private var isDropTarget = false

    private var accent: Color { theme.accent.map(Color.init) ?? Color.accentColor }
    private var floatColor: Color { theme.floatColor.map(Color.init) ?? Color.white }
    private var badgeColor: Color { theme.badgeColor.map(Color.init) ?? Color.red }
    private var iconSize: CGFloat { theme.iconSize }

    var body: some View {
        HStack(spacing: theme.cellSpacing) {
            if let icon = workspace.icon {
                Text(icon).font(.system(size: theme.fontSize))
            }
            if workspace.showNumber {
                Text(workspace.name)
                    .font(theme.font(size: theme.fontSize, weight: workspace.isActive ? .semibold : .regular))
                    .foregroundStyle(workspace.isActive ? Color.primary : Color.secondary)
            }
            if let displayName = workspace.displayName {
                Text(displayName)
                    .font(theme.font(size: theme.fontSize - 1, weight: workspace.isActive ? .medium : .regular))
                    .foregroundStyle(workspace.isActive ? Color.primary : Color.secondary)
            }
            ForEach(Array(workspace.windows.prefix(theme.maxIcons).enumerated()), id: \.element.windowID) { _, window in
                if let icon = NSRunningApplication(processIdentifier: window.pid)?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: iconSize, height: iconSize)
                        .opacity(window.isFocused ? 1 : theme.inactiveIconOpacity)
                        .overlay(
                            // Solid accent ring = focused, dashed = floating.
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(
                                    window.isFocused ? accent : floatColor,
                                    style: StrokeStyle(lineWidth: window.isFocused || window.isFloating ? theme.ringWidth : 0, dash: window.isFloating && !window.isFocused ? [2.5] : [])
                                )
                        )
                        .overlay(alignment: .topTrailing) {
                            if let badge = window.badge {
                                Text(badge.count > 2 ? "9+" : badge)
                                    .font(.system(size: max(6, theme.fontSize / 2), weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 2.5)
                                    .padding(.vertical, 0.5)
                                    .background(Capsule().fill(badgeColor))
                                    .offset(x: 4, y: -4)
                            }
                        }
                        .draggable(dragPrefix + String(window.windowID)) {
                            // Bigger preview so the drag is clearly visible.
                            Image(nsImage: icon).resizable().frame(width: 32, height: 32)
                        }
                        .onTapGesture { onFocusWindow(window.windowID) }
                        .contextMenu {
                            Button(L10n.focusWindow) { onFocusWindow(window.windowID) }
                            Button(window.isFloating ? L10n.tileWindow : L10n.floatWindow) { onToggleFloat(window.windowID) }
                            Button(L10n.toggleFullscreen) { onToggleFullscreen(window.windowID) }
                            Menu(L10n.moveTo) {
                                ForEach(allWorkspaceNames.filter { $0.name != workspace.name }, id: \.name) { target in
                                    Button(target.title) { onMoveWindow(window.windowID, target.name) }
                                }
                            }
                        }
                }
            }
            if isDropTarget {
                // Placeholder slot where the dragged window's icon will land.
                RoundedRectangle(cornerRadius: 4)
                    .stroke(accent, style: StrokeStyle(lineWidth: theme.ringWidth, dash: [3]))
                    .frame(width: iconSize, height: iconSize)
            }
        }
        .padding(.vertical, theme.cellPaddingY)
        .padding(.horizontal, theme.cellPaddingX)
        .background(
            RoundedRectangle(cornerRadius: theme.cellRadius)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cellRadius)
                .stroke(accent, style: StrokeStyle(lineWidth: theme.ringWidth, dash: [4]))
                .opacity(isDropTarget ? 1 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: theme.cellRadius))
        .onTapGesture { onSelect(workspace.name) }
        .help(L10n.workspaceTooltip(name: workspace.name, displayName: workspace.displayName, layout: workspace.layoutName, windowCount: workspace.windows.count))
        .contextMenu {
            Button(L10n.switchToWorkspace(workspace.name)) { onSelect(workspace.name) }
            Button(L10n.moveFocusedHere) { onMoveFocusedWindow(workspace.name) }
            Menu(L10n.layoutMenu(workspace.layoutName)) {
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
        guard workspace.isActive else { return Color.clear }
        // Custom accent = colored highlight; native default = the subtle
        // menu-bar-style primary tint that adapts to light/dark.
        if theme.accent != nil {
            return accent.opacity(isFocusedMonitor ? theme.activeOpacity : theme.activeOpacity * 0.55)
        }
        return Color.primary.opacity(isFocusedMonitor ? 0.16 : 0.09)
    }
}
