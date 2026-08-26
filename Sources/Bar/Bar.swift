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
    /// Fullscreen windows get a corner glyph on their icon.
    public let isFullscreen: Bool

    public init(windowID: UInt32, pid: pid_t, isFocused: Bool, badge: String?, isFloating: Bool, isFullscreen: Bool) {
        self.windowID = windowID
        self.pid = pid
        self.isFocused = isFocused
        self.badge = badge
        self.isFloating = isFloating
        self.isFullscreen = isFullscreen
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
    /// Menubar mode: `barFrame` is the menu-bar band and the window shrinks
    /// to the pill so the rest of the menu bar stays clickable.
    public let compact: Bool

    public init(monitorID: String, barFrame: NSRect, workspaces: [BarWorkspaceItem], isFocusedMonitor: Bool, allWorkspaceNames: [BarWorkspaceRef], availableLayouts: [String], compact: Bool = false) {
        self.monitorID = monitorID
        self.barFrame = barFrame
        self.workspaces = workspaces
        self.isFocusedMonitor = isFocusedMonitor
        self.allWorkspaceNames = allWorkspaceNames
        self.availableLayouts = availableLayouts
        self.compact = compact
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
    /// Which side of a notch hosts the pill in menubar position.
    public var notchSide = "left"
    /// "top" | "bottom" | "menubar" | "notch" — notch = hidden until the
    /// mouse enters the notch zone, then the pill slides out under it.
    public var position = "top"

    public init() {}

    func font(size: Double, weight: Font.Weight) -> Font {
        if let fontFamily { return .custom(fontFamily, size: size).weight(weight) }
        return .system(size: size, weight: weight)
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
    /// Notch mode: invisible hover zones over the notch and which monitors
    /// currently have their pill revealed.
    private var hoverZones: [String: NSWindow] = [:]
    private var revealed: Set<String> = []

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
            let rootView = BarView(
                workspaces: snapshot.workspaces,
                allWorkspaceNames: snapshot.allWorkspaceNames,
                availableLayouts: snapshot.availableLayouts,
                isFocused: snapshot.isFocusedMonitor,
                fullWidth: !snapshot.compact,
                theme: theme,
                onSelect: onSelect,
                onMoveWindow: onMoveWindow,
                onMoveFocusedWindow: onMoveFocusedWindow,
                onFocusWindow: onFocusWindow,
                onSetLayout: onSetLayout,
                onToggleFloat: onToggleFloat,
                onToggleFullscreen: onToggleFullscreen
            )
            // Reassign rootView so SwiftUI diffs the tree instead of a full
            // NSHostingView teardown on every change (focus ring, badges...).
            let hosting: NSHostingView<BarView>
            if let existing = window.contentView as? NSHostingView<BarView> {
                existing.rootView = rootView
                hosting = existing
            } else if let container = window.contentView as? TrackingView,
                      let inner = container.subviews.first as? NSHostingView<BarView> {
                inner.rootView = rootView
                hosting = inner
            } else {
                hosting = NSHostingView(rootView: rootView)
                window.contentView = hosting
            }
            if snapshot.compact {
                positionCompact(window, hosting: hosting, band: snapshot.barFrame)
            }
            if theme.position == "notch", let screen = notchedScreen(for: snapshot.barFrame) {
                setupNotchMode(monitorID: snapshot.monitorID, window: window, hosting: hosting, screen: screen)
                if !revealed.contains(snapshot.monitorID) {
                    window.orderOut(nil)
                    continue
                }
            }
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
        for zone in hoverZones.values { zone.orderOut(nil) }
        windows.removeAll()
        hoverZones.removeAll()
        lastSnapshots.removeAll()
        revealed.removeAll()
    }

    /// Menubar mode: shrink the window to the pill and place it in the band,
    /// dodging the notch via the screen's auxiliary top areas.
    private func positionCompact(_ window: NSWindow, hosting: NSHostingView<BarView>, band: NSRect) {
        let size = hosting.fittingSize
        var usable = band
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(band) }),
           screen.safeAreaInsets.top > 0 {
            let aux = theme.notchSide == "right" ? screen.auxiliaryTopRightArea : screen.auxiliaryTopLeftArea
            if let aux { usable = aux }
        }
        let x: CGFloat
        switch theme.align {
        case "left": x = usable.minX + 4 + theme.offsetX
        case "right": x = usable.maxX - size.width - 4 - theme.offsetX
        default: x = usable.midX - size.width / 2 + theme.offsetX
        }
        let clampedX = min(max(x, usable.minX), max(usable.minX, usable.maxX - size.width))
        window.setFrame(
            NSRect(x: clampedX, y: band.midY - size.height / 2, width: min(size.width, usable.width), height: size.height),
            display: true
        )
    }

    private func notchedScreen(for band: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(band) && $0.safeAreaInsets.top > 0 }
    }

    /// Creates the invisible hover zone over the notch and parks the pill
    /// right under it; entering the zone slides the pill out, leaving the
    /// pill hides it again.
    private func setupNotchMode(monitorID: String, window: NSWindow, hosting: NSHostingView<BarView>, screen: NSScreen) {
        let safeTop = screen.safeAreaInsets.top
        let auxLeft = screen.auxiliaryTopLeftArea
        let auxRight = screen.auxiliaryTopRightArea
        let notchMinX = auxLeft?.maxX ?? screen.frame.midX - 90
        let notchMaxX = auxRight?.minX ?? screen.frame.midX + 90
        let notchRect = NSRect(x: notchMinX, y: screen.frame.maxY - safeTop, width: notchMaxX - notchMinX, height: safeTop)

        // Pill target: centered under the notch, just below the menu band.
        let size = hosting.fittingSize
        let target = NSRect(
            x: notchRect.midX - size.width / 2,
            y: screen.frame.maxY - safeTop - size.height - 4,
            width: size.width,
            height: size.height
        )
        window.setFrame(target, display: true)
        wrapInTracking(window: window, hosting: hosting) { [weak self] in
            self?.conceal(monitorID: monitorID, window: window)
        }

        if hoverZones[monitorID] == nil {
            let zone = NSWindow(contentRect: notchRect, styleMask: .borderless, backing: .buffered, defer: false)
            zone.isOpaque = false
            zone.backgroundColor = .clear
            zone.hasShadow = false
            zone.level = .statusBar
            zone.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            let tracker = TrackingView(onEnter: { [weak self, weak window] in
                guard let self, let window else { return }
                self.reveal(monitorID: monitorID, window: window, target: target, safeTop: safeTop)
            }, onExit: nil)
            zone.contentView = tracker
            zone.orderFrontRegardless()
            hoverZones[monitorID] = zone
        }
    }

    private func reveal(monitorID: String, window: NSWindow, target: NSRect, safeTop: CGFloat) {
        guard !revealed.contains(monitorID) else { return }
        revealed.insert(monitorID)
        var start = target
        start.origin.y += safeTop + target.height // begin tucked behind the notch band
        window.setFrame(start, display: false)
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            window.animator().setFrame(target, display: true)
            window.animator().alphaValue = 1
        }
    }

    private func conceal(monitorID: String, window: NSWindow) {
        guard revealed.contains(monitorID) else { return }
        revealed.remove(monitorID)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            window.alphaValue = 1
        })
    }

    /// Ensures the pill's content view is wrapped in a tracking container so
    /// mouse-exit can hide it in notch mode.
    private func wrapInTracking(window: NSWindow, hosting: NSHostingView<BarView>, onExit: @escaping () -> Void) {
        if let container = window.contentView as? TrackingView {
            container.onExit = onExit
            if hosting.superview !== container {
                container.subviews.forEach { $0.removeFromSuperview() }
                container.embed(hosting)
            }
            return
        }
        let container = TrackingView(onEnter: nil, onExit: onExit)
        container.embed(hosting)
        window.contentView = container
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
    /// false = menubar mode: just the pill, no full-strip spacers.
    let fullWidth: Bool
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
            if fullWidth, theme.align != "left" { Spacer(minLength: 0) }
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
            .offset(x: fullWidth && theme.align == "center" ? theme.offsetX : 0)
            if fullWidth, theme.align != "right" { Spacer(minLength: 0) }
        }
        .padding(.leading, fullWidth && theme.align == "left" ? 8 + theme.offsetX : 0)
        .padding(.trailing, fullWidth && theme.align == "right" ? 8 + theme.offsetX : 0)
        .frame(maxWidth: fullWidth ? .infinity : nil, maxHeight: fullWidth ? .infinity : nil)
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
                        .overlay(alignment: .bottomTrailing) {
                            if window.isFullscreen {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: max(6, theme.fontSize / 2), weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(1.5)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                    .offset(x: 3, y: 3)
                            }
                        }
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


/// Plain NSView with a full-bounds tracking area calling the given closures.
final class TrackingView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?

    init(onEnter: (() -> Void)?, onExit: (() -> Void)?) {
        self.onEnter = onEnter
        self.onExit = onExit
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    func embed(_ view: NSView) {
        view.frame = bounds
        view.autoresizingMask = [.width, .height]
        addSubview(view)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
}
