// WMCore: pure state + reducer logic for the window manager.
//
// No AX/AppKit imports here on purpose — Foundation/CoreGraphics types
// (CGRect) are fine, everything else must stay unit-testable without a
// running window server. The AX layer (future AXBridge) executes the
// `Effect`s this module produces; it never mutates `WMState` directly.

import Foundation
import CoreGraphics

// MARK: - Identifiers

/// Opaque handle for a managed window. Wraps a raw id (e.g. an AX element's
/// hash or a synthetic counter in tests) so WMCore never depends on AX types.
public struct WindowID: Hashable, CustomStringConvertible {
    public let rawValue: UInt32
    public init(_ rawValue: UInt32) { self.rawValue = rawValue }
    public var description: String { "Window(\(rawValue))" }
}

// MARK: - Directions / dimensions

/// hjkl-style navigation directions, shared by `Command` and `Layout`.
public enum Direction: String, CaseIterable {
    case left, down, up, right
}

public enum Dimension: String, CaseIterable {
    case width, height
}

// MARK: - Layout protocol (plugin point for concrete layouts)

/// A `Layout` owns the geometric arrangement of one workspace's tiled
/// windows. WMCore only knows this protocol, never a concrete algorithm —
/// new layouts (e.g. a future "scroll" layout) are added by conforming to
/// it in LayoutEngine, without touching WMCore.
///
/// Every mutating operation takes the container rect + gaps rather than
/// caching them: layouts stay stateless value types and always compute
/// frames fresh, which keeps them trivially testable in isolation.
public protocol Layout {
    /// Windows currently managed, in layout (not necessarily z-) order.
    var orderedWindows: [WindowID] { get }

    /// Frame for every managed window inside `container`, honoring gaps.
    func frames(container: CGRect, innerGap: Double, outerGap: Double) -> [WindowID: CGRect]

    /// Insert `window`, splitting `after` (or the last-inserted window).
    mutating func insert(_ window: WindowID, after: WindowID?, container: CGRect, innerGap: Double, outerGap: Double)

    /// Remove `window`, collapsing its split back into its sibling.
    mutating func remove(_ window: WindowID)

    /// Swap `window` with its nearest geometric neighbor in `direction`.
    /// Returns whether a neighbor was found and swapped.
    @discardableResult
    mutating func move(_ window: WindowID, direction: Direction, container: CGRect, innerGap: Double, outerGap: Double) -> Bool

    /// Adjust the split ratio that governs `window`'s size along `dimension` by `delta` points.
    mutating func resize(_ window: WindowID, dimension: WMCore.Dimension, delta: Double, container: CGRect, innerGap: Double, outerGap: Double)

    /// Focus moved to `window`. Viewport layouts (scroll) re-anchor here so
    /// the focused window stays visible; tree layouts ignore it.
    mutating func focusChanged(_ window: WindowID)

    /// Insert `window` on a specific side of `target` (drag&drop edge zones).
    mutating func insert(_ window: WindowID, near target: WindowID, edge: Direction, container: CGRect, innerGap: Double, outerGap: Double)

    /// Exchange the positions of two managed windows (drag&drop center zone).
    mutating func swapPositions(_ a: WindowID, _ b: WindowID)
}

public extension Layout {
    mutating func focusChanged(_ window: WindowID) {}

    mutating func insert(_ window: WindowID, near target: WindowID, edge: Direction, container: CGRect, innerGap: Double, outerGap: Double) {
        insert(window, after: target, container: container, innerGap: innerGap, outerGap: outerGap)
    }

    mutating func swapPositions(_ a: WindowID, _ b: WindowID) {}
}

/// Picks the id whose rect center is nearest `from`'s center among
/// `candidates` that actually lie in `direction`. Shared by `WM.dispatch(.focus)`
/// and by `Layout.move` implementations so both use identical geometry.
public func nearestNeighbor(from: CGRect, direction: Direction, candidates: [WindowID: CGRect]) -> WindowID? {
    let origin = CGPoint(x: from.midX, y: from.midY)
    var best: (WindowID, Double)?
    for (id, rect) in candidates {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dx = Double(center.x - origin.x)
        let dy = Double(center.y - origin.y)
        let inDirection: Bool
        switch direction {
        case .left: inDirection = dx < -1
        case .right: inDirection = dx > 1
        case .up: inDirection = dy < -1
        case .down: inDirection = dy > 1
        }
        guard inDirection else { continue }
        // Weight the perpendicular axis heavily so "down" picks the window
        // straight below, not a nearer diagonal one.
        let dist: Double
        switch direction {
        case .left, .right: dist = abs(dx) + 3 * abs(dy)
        case .up, .down: dist = abs(dy) + 3 * abs(dx)
        }
        if best == nil || dist < best!.1 { best = (id, dist) }
    }
    return best?.0
}

// MARK: - Window / workspace / monitor model

public struct WindowNode {
    public let id: WindowID
    public var appBundleID: String
    public var pid: Int32
    public var title: String
    public var isFloating: Bool
    public var isFullscreen: Bool
    public var frame: CGRect

    public init(id: WindowID, appBundleID: String, pid: Int32, title: String, isFloating: Bool = false, isFullscreen: Bool = false, frame: CGRect = .zero) {
        self.id = id
        self.appBundleID = appBundleID
        self.pid = pid
        self.title = title
        self.isFloating = isFloating
        self.isFullscreen = isFullscreen
        self.frame = frame
    }
}

public struct Workspace {
    public var name: String
    public var layout: any Layout
    /// Floating windows keep their own frame instead of participating in `layout`.
    public var floatingFrames: [WindowID: CGRect]
    public var focusedWindow: WindowID?

    public init(name: String, layout: any Layout, floatingFrames: [WindowID: CGRect] = [:], focusedWindow: WindowID? = nil) {
        self.name = name
        self.layout = layout
        self.floatingFrames = floatingFrames
        self.focusedWindow = focusedWindow
    }

    public var tiledWindows: [WindowID] { layout.orderedWindows }
    public var allWindows: Set<WindowID> { Set(tiledWindows).union(floatingFrames.keys) }
}

public struct Monitor {
    public let id: String
    public var frame: CGRect
    public var visibleFrame: CGRect
    public var workspaces: [Workspace]
    public var activeWorkspaceIndex: Int

    public init(id: String, frame: CGRect, visibleFrame: CGRect, workspaces: [Workspace], activeWorkspaceIndex: Int = 0) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.workspaces = workspaces
        self.activeWorkspaceIndex = activeWorkspaceIndex
    }

    public var activeWorkspace: Workspace {
        get { workspaces[activeWorkspaceIndex] }
        set { workspaces[activeWorkspaceIndex] = newValue }
    }
}

public struct WindowLocation: Equatable {
    public var monitorIndex: Int
    public var workspaceName: String
    public init(monitorIndex: Int, workspaceName: String) {
        self.monitorIndex = monitorIndex
        self.workspaceName = workspaceName
    }
}

public struct WMState {
    public var monitors: [Monitor]
    public var focusedMonitorIndex: Int
    public var windows: [WindowID: WindowNode]
    public var windowLocation: [WindowID: WindowLocation]
    public var innerGap: Double
    public var outerGap: Double
    /// Config `[workspaces]`: workspace name -> monitor matcher (stable id or
    /// display name). Consulted on every display reconfiguration, not just at
    /// startup, so a monitor plugged in later still claims its workspaces.
    /// Workspace name -> preference-ordered monitor matchers; the first
    /// matcher with a connected monitor wins (home vs office externals).
    public var workspaceAssignments: [String: [String]]
    /// Windows floated automatically (couldn't fit their tile), as opposed to
    /// a user's toggle-floating. Retried as tiles on display reconfiguration —
    /// a window squeezed out on a small screen re-tiles on a big one.
    public var autoFloated: Set<WindowID> = []

    public init(monitors: [Monitor], focusedMonitorIndex: Int = 0, windows: [WindowID: WindowNode] = [:], windowLocation: [WindowID: WindowLocation] = [:], innerGap: Double = 8, outerGap: Double = 8, workspaceAssignments: [String: [String]] = [:]) {
        self.monitors = monitors
        self.focusedMonitorIndex = focusedMonitorIndex
        self.windows = windows
        self.windowLocation = windowLocation
        self.innerGap = innerGap
        self.outerGap = outerGap
        self.workspaceAssignments = workspaceAssignments
    }

    func workspaceIndex(_ location: WindowLocation) -> Int? {
        monitors[location.monitorIndex].workspaces.firstIndex { $0.name == location.workspaceName }
    }

    /// Workspace names are globally unique, so a name resolves to exactly one
    /// (monitor, workspace) pair regardless of which display hosts it.
    public func locate(workspace name: String) -> (monitor: Int, workspace: Int)? {
        for (monitorIndex, monitor) in monitors.enumerated() {
            if let workspaceIndex = monitor.workspaces.firstIndex(where: { $0.name == name }) {
                return (monitorIndex, workspaceIndex)
            }
        }
        return nil
    }
}

// MARK: - Commands

/// User-facing actions, as parsed from keybinding strings (see `Config/default.toml`).
public enum Command: Equatable {
    case focus(Direction)
    case move(Direction)
    case resize(Dimension, Double)
    case workspace(String)
    case moveToWorkspace(String)
    case toggleFloating
    case toggleFullscreen
    case focusMonitor(MonitorTarget)
    /// Handled by the controller (needs AX to find the frontmost window);
    /// dispatch() treats it as a no-op.
    case adoptWindow
    /// "layout <name>": switch the focused workspace's layout. Resolved by the
    /// controller (layout construction lives in LayoutEngine); dispatch() no-op.
    case setLayout(String)
    /// Controller-side commands (need AX/AppKit); dispatch() no-ops.
    case pauseTiling
    case retile
    case openConfig
    case switcher
    case scratchpad
    case hints
    case presetApply(String)
    case presetSave(String)
    /// Terminate ancre (panic switch when tiling goes wrong).
    case quit

    /// Parses the command grammar used by `Sources/Config/default.toml`'s
    /// `[keybindings]` values. Keep this in sync with that file.
    public static func parse(_ s: String) -> Command? {
        let parts = s.split(separator: " ").map(String.init)
        guard let head = parts.first else { return nil }
        switch head {
        case "focus":
            guard parts.count == 2, let d = Direction(rawValue: parts[1]) else { return nil }
            return .focus(d)
        case "move":
            guard parts.count == 2, let d = Direction(rawValue: parts[1]) else { return nil }
            return .move(d)
        case "resize":
            guard parts.count == 3, let dim = Dimension(rawValue: parts[1]), let delta = Double(parts[2]) else { return nil }
            return .resize(dim, delta)
        case "workspace":
            guard parts.count == 2 else { return nil }
            return .workspace(parts[1])
        case "move-to-workspace":
            guard parts.count == 2 else { return nil }
            return .moveToWorkspace(parts[1])
        case "toggle-floating":
            guard parts.count == 1 else { return nil }
            return .toggleFloating
        case "toggle-fullscreen":
            guard parts.count == 1 else { return nil }
            return .toggleFullscreen
        case "adopt-window":
            guard parts.count == 1 else { return nil }
            return .adoptWindow
        case "layout":
            guard parts.count == 2 else { return nil }
            return .setLayout(parts[1])
        case "pause-tiling":
            guard parts.count == 1 else { return nil }
            return .pauseTiling
        case "retile":
            guard parts.count == 1 else { return nil }
            return .retile
        case "open-config":
            guard parts.count == 1 else { return nil }
            return .openConfig
        case "switcher":
            guard parts.count == 1 else { return nil }
            return .switcher
        case "scratchpad":
            guard parts.count == 1 else { return nil }
            return .scratchpad
        case "hints":
            guard parts.count == 1 else { return nil }
            return .hints
        case "preset":
            guard parts.count == 2 else { return nil }
            return .presetApply(parts[1])
        case "preset-save":
            guard parts.count == 2 else { return nil }
            return .presetSave(parts[1])
        case "quit":
            guard parts.count == 1 else { return nil }
            return .quit
        case "focus-monitor":
            guard parts.count == 2, let target = MonitorTarget(rawValue: parts[1]) else { return nil }
            return .focusMonitor(target)
        default:
            return nil
        }
    }
}

// MARK: - Effects

/// Side effects the (future) AX layer must execute after a dispatch.
public enum Effect: Equatable {
    case setFrame(WindowID, CGRect)
    case focusWindow(WindowID)
    case hideWorkspace([WindowID])
    case showWorkspace([WindowID: CGRect])
}

// MARK: - Reducer

public enum WM {
    /// Applies `command` to `state`, returning the effects the AX layer must run.
    public static func dispatch(_ command: Command, state: inout WMState) -> [Effect] {
        switch command {
        case .focus(let direction):
            return focus(direction, state: &state)
        case .move(let direction):
            return move(direction, state: &state)
        case .resize(let dimension, let delta):
            return resize(dimension, delta, state: &state)
        case .workspace(let name):
            return switchWorkspace(name, state: &state)
        case .moveToWorkspace(let name):
            return moveFocusedWindow(toWorkspace: name, state: &state)
        case .toggleFloating:
            return toggleFloating(state: &state)
        case .toggleFullscreen:
            return toggleFullscreen(state: &state)
        case .focusMonitor(let target):
            return focusMonitor(target, state: &state)
        case .adoptWindow:
            return [] // AX-side, handled by the controller before dispatch
        case .setLayout:
            return [] // resolved by the controller (needs LayoutEngine)
        case .pauseTiling, .retile, .openConfig, .switcher, .scratchpad, .hints, .presetApply, .presetSave, .quit:
            return [] // controller-side
        }
    }

    /// Replaces the named workspace's layout, re-inserting its tiled windows
    /// in order. Re-places only when that workspace is currently visible —
    /// a hidden one gets fresh frames on its next show anyway.
    public static func setLayout(_ newLayout: any Layout, workspaceNamed name: String, state: inout WMState) -> [Effect] {
        guard let (monitorIdx, wsIdx) = state.locate(workspace: name) else { return [] }
        var monitor = state.monitors[monitorIdx]
        var workspace = monitor.workspaces[wsIdx]
        // A fresh layout is an explicit "rearrange this": auto-floated windows
        // (squeezed out earlier) get another chance as tiles. User floats stay.
        let retryFloats = workspace.floatingFrames.keys.filter { state.autoFloated.contains($0) }
        for window in retryFloats {
            workspace.floatingFrames.removeValue(forKey: window)
            state.windows[window]?.isFloating = false
            state.autoFloated.remove(window)
        }
        // Transplant in GEOMETRIC (reading) order — left to right, top to
        // bottom — so windows land where they visually were, not in a stale
        // insertion order.
        let currentFrames = allFrames(for: workspace, monitor: monitor, state: state)
        let orderedTiled = workspace.tiledWindows.sorted { a, b in
            let fa = currentFrames[a] ?? .zero
            let fb = currentFrames[b] ?? .zero
            if abs(fa.minX - fb.minX) > 1 { return fa.minX < fb.minX }
            return fa.minY < fb.minY
        }
        var layout = newLayout
        for window in orderedTiled + retryFloats.sorted(by: { $0.rawValue < $1.rawValue }) {
            layout.insert(window, after: layout.orderedWindows.last, container: monitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
        }
        workspace.layout = layout
        if let focused = workspace.focusedWindow {
            workspace.layout.focusChanged(focused)
        }
        monitor.workspaces[wsIdx] = workspace
        state.monitors[monitorIdx] = monitor
        guard wsIdx == monitor.activeWorkspaceIndex else { return [] }
        return frameEffects(for: workspace, monitor: monitor, state: state)
    }

    // MARK: External events

    public static func windowAdded(_ node: WindowNode, toWorkspace workspaceName: String, onMonitor monitorIndex: Int, state: inout WMState) -> [Effect] {
        guard monitorIndex < state.monitors.count,
              let wsIdx = state.monitors[monitorIndex].workspaces.firstIndex(where: { $0.name == workspaceName }) else { return [] }
        var monitor = state.monitors[monitorIndex]
        var workspace = monitor.workspaces[wsIdx]
        state.windows[node.id] = node
        state.windowLocation[node.id] = WindowLocation(monitorIndex: monitorIndex, workspaceName: workspaceName)

        if node.isFloating {
            workspace.floatingFrames[node.id] = node.frame
            monitor.workspaces[wsIdx] = workspace
            state.monitors[monitorIndex] = monitor
            return [.setFrame(node.id, node.frame)]
        }

        workspace.layout.insert(node.id, after: workspace.focusedWindow, container: monitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
        workspace.focusedWindow = node.id
        workspace.layout.focusChanged(node.id)
        monitor.workspaces[wsIdx] = workspace
        state.monitors[monitorIndex] = monitor

        guard wsIdx == monitor.activeWorkspaceIndex else {
            // Hidden target (per-app workspace rule) — park the window instead
            // of leaving it visible on top of whatever is on screen.
            return [.hideWorkspace([node.id])]
        }
        // Active workspace tiles on ANY monitor, not just the focused one;
        // AX focus follows only on the focused monitor.
        var effects = frameEffects(for: workspace, monitor: monitor, state: state)
        if monitorIndex == state.focusedMonitorIndex { effects.append(.focusWindow(node.id)) }
        return effects
    }

    public static func windowRemoved(_ id: WindowID, state: inout WMState) -> [Effect] {
        guard let location = state.windowLocation[id], let wsIdx = state.workspaceIndex(location) else { return [] }
        var monitor = state.monitors[location.monitorIndex]
        var workspace = monitor.workspaces[wsIdx]

        workspace.layout.remove(id)
        workspace.floatingFrames.removeValue(forKey: id)
        if workspace.focusedWindow == id { workspace.focusedWindow = workspace.tiledWindows.first }
        monitor.workspaces[wsIdx] = workspace
        state.monitors[location.monitorIndex] = monitor
        state.windows.removeValue(forKey: id)
        state.windowLocation.removeValue(forKey: id)
        // CGWindowIDs get reused over long uptimes — a stale entry here would
        // mislabel a future user-floated window as auto-floated.
        state.autoFloated.remove(id)

        guard location.monitorIndex == state.focusedMonitorIndex, wsIdx == monitor.activeWorkspaceIndex else { return [] }
        return frameEffects(for: workspace, monitor: monitor, state: state)
    }

    public static func focusChangedExternally(_ id: WindowID, state: inout WMState) -> [Effect] {
        guard let location = state.windowLocation[id], let wsIdx = state.workspaceIndex(location) else { return [] }
        state.focusedMonitorIndex = location.monitorIndex
        state.monitors[location.monitorIndex].workspaces[wsIdx].focusedWindow = id
        return reanchor(id, state: &state)
    }

    // MARK: Command implementations

    private static func focus(_ direction: Direction, state: inout WMState) -> [Effect] {
        let monitor = state.monitors[state.focusedMonitorIndex]
        let workspace = monitor.activeWorkspace
        guard let focused = workspace.focusedWindow else { return [] }
        let frames = allFrames(for: workspace, monitor: monitor, state: state)
        guard let myFrame = frames[focused] else { return [] }
        var others = frames
        others.removeValue(forKey: focused)
        var target = nearestNeighbor(from: myFrame, direction: direction, candidates: others)
        if target == nil {
            // Monocle/stack: frames are identical, geometry can't pick — cycle
            // the stack order instead (right/down = next, left/up = previous).
            let stacked = others.contains { abs($0.value.minX - myFrame.minX) < 1 && abs($0.value.minY - myFrame.minY) < 1 }
            let tiled = workspace.tiledWindows
            if stacked, tiled.count > 1, let idx = tiled.firstIndex(of: focused) {
                let step = (direction == .right || direction == .down) ? 1 : tiled.count - 1
                target = tiled[(idx + step) % tiled.count]
            }
        }
        guard let target else { return [] }
        state.monitors[state.focusedMonitorIndex].activeWorkspace.focusedWindow = target
        return [.focusWindow(target)] + reanchor(target, state: &state)
    }

    /// Tells the active workspace's layout about a focus move and re-places
    /// the workspace when that shifted the viewport (scroll layouts).
    static func reanchor(_ window: WindowID, state: inout WMState) -> [Effect] {
        guard let location = state.windowLocation[window],
              let wsIdx = state.workspaceIndex(location),
              wsIdx == state.monitors[location.monitorIndex].activeWorkspaceIndex else { return [] }
        var monitor = state.monitors[location.monitorIndex]
        var workspace = monitor.workspaces[wsIdx]
        let before = allFrames(for: workspace, monitor: monitor, state: state)
        workspace.layout.focusChanged(window)
        let after = allFrames(for: workspace, monitor: monitor, state: state)
        monitor.workspaces[wsIdx] = workspace
        state.monitors[location.monitorIndex] = monitor
        guard before != after else { return [] }
        return frameEffects(for: workspace, monitor: monitor, state: state)
    }

    private static func move(_ direction: Direction, state: inout WMState) -> [Effect] {
        let monitorIdx = state.focusedMonitorIndex
        var monitor = state.monitors[monitorIdx]
        var workspace = monitor.activeWorkspace
        guard let focused = workspace.focusedWindow else { return [] }
        let moved = workspace.layout.move(focused, direction: direction, container: monitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
        guard moved else { return [] }
        monitor.activeWorkspace = workspace
        state.monitors[monitorIdx] = monitor
        workspace = state.monitors[monitorIdx].activeWorkspace
        return frameEffects(for: workspace, monitor: state.monitors[monitorIdx], state: state)
    }

    private static func resize(_ dimension: WMCore.Dimension, _ delta: Double, state: inout WMState) -> [Effect] {
        let monitorIdx = state.focusedMonitorIndex
        var monitor = state.monitors[monitorIdx]
        var workspace = monitor.activeWorkspace
        guard let focused = workspace.focusedWindow else { return [] }
        workspace.layout.resize(focused, dimension: dimension, delta: delta, container: monitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
        monitor.activeWorkspace = workspace
        state.monitors[monitorIdx] = monitor
        return frameEffects(for: workspace, monitor: monitor, state: state)
    }

    /// Activates `name` wherever it lives. A workspace assigned to another
    /// display switches focus to that display instead of doing nothing.
    private static func switchWorkspace(_ name: String, state: inout WMState) -> [Effect] {
        guard let (monitorIdx, wsIdx) = state.locate(workspace: name) else { return [] }
        var effects: [Effect] = []

        if wsIdx != state.monitors[monitorIdx].activeWorkspaceIndex {
            let hidden = Array(state.monitors[monitorIdx].activeWorkspace.allWindows)
            state.monitors[monitorIdx].activeWorkspaceIndex = wsIdx
            let monitor = state.monitors[monitorIdx]
            effects.append(.hideWorkspace(hidden))
            let (visible, offViewport) = splitVisible(allFrames(for: monitor.workspaces[wsIdx], monitor: monitor, state: state), monitor: monitor)
            effects.append(.showWorkspace(visible))
            if !offViewport.isEmpty { effects.append(.hideWorkspace(offViewport)) }
        } else if monitorIdx == state.focusedMonitorIndex {
            return []
        }

        state.focusedMonitorIndex = monitorIdx
        if let focused = state.monitors[monitorIdx].workspaces[wsIdx].focusedWindow {
            effects.append(.focusWindow(focused))
        }
        return effects
    }

    private static func moveFocusedWindow(toWorkspace name: String, state: inout WMState) -> [Effect] {
        guard let window = state.monitors[state.focusedMonitorIndex].activeWorkspace.focusedWindow else { return [] }
        return moveWindow(window, toWorkspace: name, state: &state)
    }

    /// Moves any window (not just the focused one — bar drag&drop needs this)
    /// to the named workspace, wherever both live.
    public static func moveWindow(_ window: WindowID, toWorkspace name: String, state: inout WMState) -> [Effect] {
        guard let location = state.windowLocation[window],
              let sourceWsIdx = state.workspaceIndex(location),
              let (targetMonitorIdx, targetWsIdx) = state.locate(workspace: name),
              (targetMonitorIdx, targetWsIdx) != (location.monitorIndex, sourceWsIdx) else { return [] }
        let sourceMonitorIdx = location.monitorIndex

        let wasFloating = state.windows[window]?.isFloating ?? false

        var source = state.monitors[sourceMonitorIdx].workspaces[sourceWsIdx]
        if wasFloating {
            source.floatingFrames.removeValue(forKey: window)
        } else {
            source.layout.remove(window)
        }
        if source.focusedWindow == window {
            source.focusedWindow = source.tiledWindows.first ?? source.floatingFrames.keys.first
        }
        state.monitors[sourceMonitorIdx].workspaces[sourceWsIdx] = source

        let targetMonitor = state.monitors[targetMonitorIdx]
        var target = targetMonitor.workspaces[targetWsIdx]
        if wasFloating {
            // ponytail: a floating window keeps its absolute frame, so moving it
            // across displays leaves it on the old one until the user drags it.
            target.floatingFrames[window] = state.windows[window]?.frame ?? .zero
        } else {
            target.layout.insert(window, after: target.focusedWindow, container: targetMonitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
        }
        target.focusedWindow = window
        target.layout.focusChanged(window)
        state.monitors[targetMonitorIdx].workspaces[targetWsIdx] = target
        state.windowLocation[window] = WindowLocation(monitorIndex: targetMonitorIdx, workspaceName: name)

        var effects = frameEffects(for: source, monitor: state.monitors[sourceMonitorIdx], state: state)
        if targetWsIdx == state.monitors[targetMonitorIdx].activeWorkspaceIndex {
            effects += frameEffects(for: target, monitor: state.monitors[targetMonitorIdx], state: state)
        } else {
            // Target workspace is hidden — park the window instead of leaving it
            // visible on top of the workspace it just left.
            effects.append(.hideWorkspace([window]))
        }
        return effects
    }

    /// User finished a native mouse drag-resize: adopt the new size into the
    /// layout by adjusting split ratios (position changes are not adopted —
    /// re-placement snaps the window back into its tile). Floating windows
    /// just remember their new frame.
    public static func windowResizedByUser(_ id: WindowID, to frame: CGRect, state: inout WMState) -> [Effect] {
        guard let location = state.windowLocation[id],
              let wsIdx = state.workspaceIndex(location) else { return [] }
        var monitor = state.monitors[location.monitorIndex]
        var workspace = monitor.workspaces[wsIdx]

        if state.windows[id]?.isFloating == true {
            workspace.floatingFrames[id] = frame
            state.windows[id]?.frame = frame
            monitor.workspaces[wsIdx] = workspace
            state.monitors[location.monitorIndex] = monitor
            return []
        }

        let current = allFrames(for: workspace, monitor: monitor, state: state)[id] ?? frame
        let dw = frame.width - current.width
        let dh = frame.height - current.height
        if abs(dw) > 1 {
            workspace.layout.resize(id, dimension: .width, delta: dw, container: monitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
        }
        if abs(dh) > 1 {
            workspace.layout.resize(id, dimension: .height, delta: dh, container: monitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
        }
        monitor.workspaces[wsIdx] = workspace
        state.monitors[location.monitorIndex] = monitor
        guard wsIdx == monitor.activeWorkspaceIndex else { return [] }
        return frameEffects(for: workspace, monitor: monitor, state: state)
    }

    /// Drops a window into the grid next to `target` — the hyper+drag drop.
    /// `edge` picks the side (nil = layout's default insert). Works for
    /// floating and tiled sources, across workspaces/monitors.
    public static func tileWindow(_ id: WindowID, after target: WindowID, edge: Direction? = nil, state: inout WMState) -> [Effect] {
        guard id != target,
              var node = state.windows[id],
              let targetLocation = state.windowLocation[target],
              let targetWsIdx = state.workspaceIndex(targetLocation) else { return [] }

        if let sourceLocation = state.windowLocation[id], let sourceWsIdx = state.workspaceIndex(sourceLocation) {
            var source = state.monitors[sourceLocation.monitorIndex].workspaces[sourceWsIdx]
            source.floatingFrames.removeValue(forKey: id)
            source.layout.remove(id)
            if source.focusedWindow == id {
                source.focusedWindow = source.tiledWindows.first ?? source.floatingFrames.keys.first
            }
            state.monitors[sourceLocation.monitorIndex].workspaces[sourceWsIdx] = source
        }

        node.isFloating = false
        state.windows[id] = node
        state.autoFloated.remove(id)

        var monitor = state.monitors[targetLocation.monitorIndex]
        var workspace = monitor.workspaces[targetWsIdx]
        if let edge {
            workspace.layout.insert(id, near: target, edge: edge, container: monitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
        } else {
            workspace.layout.insert(id, after: target, container: monitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
        }
        workspace.focusedWindow = id
        workspace.layout.focusChanged(id)
        monitor.workspaces[targetWsIdx] = workspace
        state.monitors[targetLocation.monitorIndex] = monitor
        state.windowLocation[id] = WindowLocation(monitorIndex: targetLocation.monitorIndex, workspaceName: workspace.name)
        state.focusedMonitorIndex = targetLocation.monitorIndex

        guard targetWsIdx == monitor.activeWorkspaceIndex else { return [.hideWorkspace([id])] }
        return frameEffects(for: workspace, monitor: monitor, state: state) + [.focusWindow(id)]
    }

    /// Exchanges the positions of two tiled windows in the same workspace —
    /// the drag&drop center zone.
    public static func swapWindows(_ a: WindowID, _ b: WindowID, state: inout WMState) -> [Effect] {
        guard a != b,
              let locationA = state.windowLocation[a],
              locationA == state.windowLocation[b],
              let wsIdx = state.workspaceIndex(locationA) else { return [] }
        var monitor = state.monitors[locationA.monitorIndex]
        var workspace = monitor.workspaces[wsIdx]
        guard workspace.tiledWindows.contains(a), workspace.tiledWindows.contains(b) else { return [] }
        workspace.layout.swapPositions(a, b)
        workspace.focusedWindow = a
        workspace.layout.focusChanged(a)
        monitor.workspaces[wsIdx] = workspace
        state.monitors[locationA.monitorIndex] = monitor
        guard wsIdx == monitor.activeWorkspaceIndex else { return [] }
        return frameEffects(for: workspace, monitor: monitor, state: state) + [.focusWindow(a)]
    }

    /// Auto-float: takes a window that refuses its tile frame (min-size clamp
    /// bigger than the tile) out of the layout at its actual frame, so the
    /// remaining tiles reflow instead of overlapping it. No-op if the window
    /// is already floating or unknown.
    public static func floatWindow(_ id: WindowID, frame: CGRect, state: inout WMState) -> [Effect] {
        guard var node = state.windows[id], !node.isFloating,
              let location = state.windowLocation[id],
              let wsIdx = state.workspaceIndex(location) else { return [] }
        node.isFloating = true
        node.frame = frame
        state.windows[id] = node
        state.autoFloated.insert(id)

        var monitor = state.monitors[location.monitorIndex]
        var workspace = monitor.workspaces[wsIdx]
        workspace.layout.remove(id)
        workspace.floatingFrames[id] = frame
        monitor.workspaces[wsIdx] = workspace
        state.monitors[location.monitorIndex] = monitor

        guard wsIdx == monitor.activeWorkspaceIndex else { return [] }
        return frameEffects(for: workspace, monitor: monitor, state: state)
    }

    private static func toggleFloating(state: inout WMState) -> [Effect] {
        guard state.monitors.indices.contains(state.focusedMonitorIndex),
              let window = state.monitors[state.focusedMonitorIndex].activeWorkspace.focusedWindow,
              let node = state.windows[window] else { return [] }
        return setFloating(window, floating: !node.isFloating, state: &state)
    }

    /// Floats/tiles any window (hyper-v on the focused one, the bar's context
    /// menu on arbitrary ones). Floating keeps the window at its CURRENT
    /// layout frame — node.frame is the stale discovery frame and may lie
    /// outside the monitor, which used to get the float instantly parked.
    public static func setFloating(_ window: WindowID, floating: Bool, state: inout WMState) -> [Effect] {
        guard var node = state.windows[window], node.isFloating != floating,
              let location = state.windowLocation[window],
              let wsIdx = state.workspaceIndex(location) else { return [] }
        let monitorIdx = location.monitorIndex
        var monitor = state.monitors[monitorIdx]
        var workspace = monitor.workspaces[wsIdx]

        // Explicit user choice — stop second-guessing it on reconfigurations.
        state.autoFloated.remove(window)
        node.isFloating = floating

        if floating {
            let current = allFrames(for: workspace, monitor: monitor, state: state)[window] ?? node.frame
            node.frame = current
            workspace.layout.remove(window)
            workspace.floatingFrames[window] = current
        } else {
            workspace.floatingFrames.removeValue(forKey: window)
            workspace.layout.insert(window, after: workspace.tiledWindows.last, container: monitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
        }
        state.windows[window] = node
        workspace.focusedWindow = window
        monitor.workspaces[wsIdx] = workspace
        state.monitors[monitorIdx] = monitor

        guard wsIdx == monitor.activeWorkspaceIndex else { return [] }
        return frameEffects(for: workspace, monitor: monitor, state: state)
    }

    private static func toggleFullscreen(state: inout WMState) -> [Effect] {
        let monitorIdx = state.focusedMonitorIndex
        let monitor = state.monitors[monitorIdx]
        let workspace = monitor.activeWorkspace
        guard let window = workspace.focusedWindow, var node = state.windows[window] else { return [] }
        node.isFullscreen.toggle()
        state.windows[window] = node
        // allFrames overrides fullscreen windows to the whole monitor, so a
        // plain reflow both enters and leaves fullscreen correctly.
        return frameEffects(for: workspace, monitor: monitor, state: state) + [.focusWindow(window)]
    }

    // MARK: Helpers

    public static func allFrames(for workspace: Workspace, monitor: Monitor, state: WMState) -> [WindowID: CGRect] {
        var frames = workspace.layout.frames(container: monitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
        for (id, rect) in workspace.floatingFrames { frames[id] = rect }
        // Fullscreen is a sticky per-window state: every re-place (workspace
        // switch, retile, reconcile) keeps such windows covering the monitor.
        for id in frames.keys where state.windows[id]?.isFullscreen == true {
            frames[id] = monitor.visibleFrame
        }
        return frames
    }

    static func frameEffects(for workspace: Workspace, monitor: Monitor, state: WMState) -> [Effect] {
        let (visible, hidden) = splitVisible(allFrames(for: workspace, monitor: monitor, state: state), monitor: monitor)
        var effects: [Effect] = visible.map { .setFrame($0.key, $0.value) }
        if !hidden.isEmpty { effects.append(.hideWorkspace(hidden)) }
        return effects
    }

    /// Scroll layouts position off-viewport columns outside the monitor;
    /// applying such frames would drop the window onto a neighbouring display,
    /// so they get parked instead (and re-placed when scrolled back in).
    static func splitVisible(_ frames: [WindowID: CGRect], monitor: Monitor) -> (visible: [WindowID: CGRect], hidden: [WindowID]) {
        var visible: [WindowID: CGRect] = [:]
        var hidden: [WindowID] = []
        for (id, rect) in frames {
            if rect.intersects(monitor.frame) { visible[id] = rect } else { hidden.append(id) }
        }
        return (visible, hidden)
    }
}
