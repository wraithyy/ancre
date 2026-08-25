// Glue between AXBridge (events + effects execution), WMCore (state) and
// InputSystem (hotkeys). Milestone 1: single monitor, dwindle, workspaces 1-9.
//
// Threading: all state here is owned by the axQueue. WindowTrackerDelegate
// callbacks already arrive on it; hotkey handling marshals in via
// tracker.perform. Never touch `state` from any other context.

import AppKit
import AXBridge
import Bar
import Config
import InputSystem
import LayoutEngine
import WMCore

final class WindowManagerController: WindowTrackerDelegate {
    private let tracker = WindowTracker()
    private let input = InputSystem()
    private let displays = DisplayManager()
    private let config: AppConfig
    private var bindings: [String: Command] = [:]
    private let workspaceNames = (1...9).map(String.init)

    private var state: WMState
    /// Union of all display frames — where hidden windows get parked.
    private var parkingBounds: CGRect = .zero
    private var axWindows: [AXWindowID: AXWindow] = [:]
    private var windowPids: [AXWindowID: pid_t] = [:]
    /// Frames we last assigned to visible tiled windows. A geometry event that
    /// diverges from this means the app resized itself → snap it back. Parked
    /// and floating windows are absent (macOS clamps parked positions, so
    /// enforcing them would fight the clamp forever).
    private var expectedFrames: [AXWindowID: AXFrame] = [:]
    /// Consecutive failed snap-backs per window; after the limit we accept the
    /// app's frame instead of spinning in a setFrame/notification loop with
    /// apps that clamp their own size.
    private var snapBackAttempts: [AXWindowID: Int] = [:]
    private let snapBackLimit = 3
    /// Windows parked offscreen for a hidden workspace. On display
    /// reconfiguration macOS "rescues" offscreen windows onto a remaining
    /// display; tracking membership lets enforceTiling send them back.
    private var parkedWindows: Set<AXWindowID> = []
    /// Created in init, which runs on the main thread (NSWindow requirement);
    /// afterwards touched only via DispatchQueue.main.
    private let focusBorder = FocusBorder()
    /// Created in start() (main thread); nil when disabled in config.
    private var bar: BarController?

    init(config: AppConfig) {
        self.config = config
        // Monitors (and with them the workspaces) are created by the first
        // DisplayManager callback, so startup and replug take the same path.
        self.state = WMState(
            monitors: [],
            innerGap: config.general.gapsInner,
            outerGap: config.general.gapsOuter,
            workspaceAssignments: config.workspaces ?? [:]
        )
    }

    func start() {
        let resolved = ConfigLoader.resolveBindings(config)
        resolved.warnings.forEach { NSLog("applland: %@", $0) }
        bindings = resolved.bindings

        if config.bar.enabled {
            bar = BarController(
                opacity: config.bar.opacity,
                onSelect: { [weak self] name in
                    guard let self else { return }
                    self.tracker.perform { self.run(.workspace(name)) }
                },
                onMoveWindow: { [weak self] windowID, name in
                    guard let self else { return }
                    self.tracker.perform {
                        self.execute(WM.moveWindow(WindowID(windowID), toWorkspace: name, state: &self.state))
                    }
                },
                onMoveFocusedWindow: { [weak self] name in
                    guard let self else { return }
                    self.tracker.perform { self.run(.moveToWorkspace(name)) }
                },
                onFocusWindow: { [weak self] windowID in
                    guard let self else { return }
                    self.tracker.perform {
                        let wid = WindowID(windowID)
                        guard let location = self.state.windowLocation[wid] else { return }
                        // Activate its workspace first (no-op if already active),
                        // then move WM focus and raise the window.
                        self.run(.workspace(location.workspaceName))
                        _ = WM.focusChangedExternally(wid, state: &self.state)
                        self.execute([.focusWindow(wid)])
                    }
                }
            )
        }

        // Displays first: window discovery needs monitors to place windows on.
        displays.start { [weak self] infos in
            self?.applyDisplays(infos)
        }

        tracker.delegate = self
        tracker.start()

        // `bindings` is immutable after this point, so reading it from the
        // event tap thread without marshaling is safe.
        input.start(hyperKeyName: config.hyper.key) { [weak self] combo in
            guard let self, let command = self.bindings[combo] else { return false }
            self.tracker.perform { self.run(command) }
            return true
        }
    }

    func stop() {
        input.stop()
        displays.stop()
        tracker.stop()
    }

    // MARK: - Displays (axQueue)

    private func applyDisplays(_ infos: [DisplayInfo]) {
        guard !infos.isEmpty else { return }
        NSLog("applland: %d display(s): %@", infos.count,
              infos.map { "\($0.name) [\($0.id)]" }.joined(separator: ", "))
        parkingBounds = infos.dropFirst().reduce(infos[0].frame) { $0.union($1.frame) }
        let monitors = infos.map {
            MonitorInfo(id: $0.id, name: $0.name, frame: $0.frame, visibleFrame: reserveBarStrip(in: $0.visibleFrame))
        }
        execute(WM.reconcileMonitors(
            monitors,
            workspaceNames: workspaceNames,
            makeWorkspace: { Workspace(name: $0, layout: DwindleLayout()) },
            state: &state
        ))
    }

    /// Carves the bar strip out of a monitor's usable area so tiles don't
    /// render under it. CG coordinates: top of the screen is minY.
    private func reserveBarStrip(in visibleFrame: CGRect) -> CGRect {
        guard config.bar.enabled else { return visibleFrame }
        var frame = visibleFrame
        frame.size.height -= config.bar.height
        if config.bar.position != "bottom" { frame.origin.y += config.bar.height }
        return frame
    }

    /// Snapshot of workspaces per monitor for the bar, marshaled to main.
    private func updateBar() {
        guard let bar else { return }
        let globallyFocused: WindowID? = state.monitors.indices.contains(state.focusedMonitorIndex)
            ? state.monitors[state.focusedMonitorIndex].activeWorkspace.focusedWindow
            : nil
        let snapshots = state.monitors.enumerated().map { index, monitor -> (String, CGRect, [BarWorkspaceItem], Bool) in
            let strip = CGRect(
                x: monitor.visibleFrame.minX,
                y: config.bar.position == "bottom" ? monitor.visibleFrame.maxY : monitor.visibleFrame.minY - config.bar.height,
                width: monitor.visibleFrame.width,
                height: config.bar.height
            )
            let items = monitor.workspaces.enumerated().map { wsIndex, workspace -> BarWorkspaceItem in
                let windows = (workspace.tiledWindows + Array(workspace.floatingFrames.keys)).compactMap { wid -> BarWindowItem? in
                    guard let pid = state.windows[wid]?.pid else { return nil }
                    return BarWindowItem(windowID: wid.rawValue, pid: pid, isFocused: wid == globallyFocused)
                }
                let label = config.workspaceLabels?[workspace.name]
                return BarWorkspaceItem(
                    name: workspace.name,
                    displayName: label?.name,
                    icon: label?.icon,
                    showNumber: label?.showNumber ?? true,
                    isActive: wsIndex == monitor.activeWorkspaceIndex,
                    windows: windows
                )
            }
            return (monitor.id, strip, items, index == state.focusedMonitorIndex)
        }
        DispatchQueue.main.async {
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            bar.update(snapshots.map { id, strip, items, focused in
                BarMonitorSnapshot(
                    monitorID: id,
                    barFrame: DisplayManager.nsScreenRect(fromCGRect: strip, primaryHeight: primaryHeight),
                    workspaces: items,
                    isFocusedMonitor: focused
                )
            })
        }
    }

    // MARK: - Command / effect pipeline (axQueue)

    private func run(_ command: Command) {
        if command == .adoptWindow { adoptFrontmostWindow(); return }
        execute(WM.dispatch(command, state: &state))
    }

    /// adopt-window: pull the frontmost app's focused window into the focused
    /// workspace — manual rescue for windows discovery missed, and a quick
    /// "bring that here".
    private func adoptFrontmostWindow() {
        guard let id = tracker.frontmostFocusedWindowID(),
              state.monitors.indices.contains(state.focusedMonitorIndex) else { return }
        let wid = WindowID(id)
        let target = state.monitors[state.focusedMonitorIndex].activeWorkspace.name
        execute(WM.moveWindow(wid, toWorkspace: target, state: &state))
        _ = WM.focusChangedExternally(wid, state: &state)
        updateFocusBorder()
        updateBar()
    }

    /// Windows whose setFrame result diverged substantially from their tile —
    /// collected during execute()'s effect loop, resolved after it (calling
    /// WM mid-loop would mutate state the remaining effects were computed from).
    /// First tries adopting the actual size into the layout so neighbors make
    /// room; floats only a window that keeps refusing after adoption.
    private var pendingAdoptions: [(WindowID, CGRect)] = []
    private var pendingAutoFloats: [(WindowID, CGRect)] = []
    /// Consecutive adoption rounds per window; above snapBackLimit the window
    /// can't be satisfied by re-ratioing (container too small for the minimum
    /// sizes involved) and gets floated instead of ping-ponging forever.
    private var adoptAttempts: [AXWindowID: Int] = [:]
    /// Windows currently being resized by a native mouse drag — left alone
    /// until the button is released, then adopted into the layout.
    private var dragResizing: Set<AXWindowID> = []

    /// Nesting depth of execute() — adoption/float drains recurse into it.
    private var executeDepth = 0

    private func execute(_ effects: [Effect]) {
        executeDepth += 1
        // Adoption counters live for one cascade: clearing them mid-cascade
        // (on a transient success) re-arms the ping-pong between two windows
        // whose minimum sizes can't coexist and recursion never terminates.
        defer {
            executeDepth -= 1
            if executeDepth == 0 { adoptAttempts.removeAll() }
        }
        for effect in effects {
            switch effect {
            case .setFrame(let wid, let rect):
                assign(frame: AXFrame(origin: rect.origin, size: rect.size), to: wid)
            case .focusWindow(let wid):
                axWindows[wid.rawValue]?.setFocused()
            case .hideWorkspace(let ids):
                for wid in ids { park(wid) }
            case .showWorkspace(let frames):
                for (wid, rect) in frames {
                    assign(frame: AXFrame(origin: rect.origin, size: rect.size), to: wid)
                }
            }
        }
        // Recursion is bounded: adoptions by adoptAttempts, floats by the
        // floatWindow no-op on already-floating windows.
        while let (wid, frame) = pendingAdoptions.popLast() {
            execute(WM.windowResizedByUser(wid, to: frame, state: &state))
        }
        while let (wid, frame) = pendingAutoFloats.popLast() {
            NSLog("applland: window %u can't fit its tile, floating it", wid.rawValue)
            execute(WM.floatWindow(wid, frame: frame, state: &state))
        }
        updateFocusBorder()
        updateBar()
    }

    /// Outlines the focused window; hides the border when nothing is focused.
    private func updateFocusBorder() {
        guard state.monitors.indices.contains(state.focusedMonitorIndex),
              let wid = state.monitors[state.focusedMonitorIndex].activeWorkspace.focusedWindow,
              let ax = axWindows[wid.rawValue]
        else {
            DispatchQueue.main.async { [focusBorder] in focusBorder.hide() }
            return
        }
        let frame = (expectedFrames[wid.rawValue] ?? ax.frame).cgRect
        // Some windows briefly report a zero/degenerate frame (seen as a tiny
        // border stuck in a screen corner) — hide instead of drawing garbage.
        guard frame.width > 40, frame.height > 40 else {
            NSLog("applland: focus border skipped, window %u reports frame %@",
                  wid.rawValue, String(describing: frame))
            DispatchQueue.main.async { [focusBorder] in focusBorder.hide() }
            return
        }
        DispatchQueue.main.async { [focusBorder] in
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            focusBorder.show(frame: DisplayManager.nsScreenRect(fromCGRect: frame, primaryHeight: primaryHeight))
        }
    }

    private func assign(frame target: AXFrame, to wid: WindowID) {
        guard let ax = axWindows[wid.rawValue] else { return }
        parkedWindows.remove(wid.rawValue)
        snapBackAttempts.removeValue(forKey: wid.rawValue)
        let actual = ax.setFrame(target)
        if state.windows[wid]?.isFloating == true {
            expectedFrames.removeValue(forKey: wid.rawValue)
            return
        }
        // Track what the app actually settled at, not what we asked for —
        // enforcing an unreachable frame against a min-size clamp would loop.
        expectedFrames[wid.rawValue] = actual
        // Small refusals (a menu bar app clamping a few px) stay tiled at the
        // clamped frame. A substantial refusal (min-size bigger than the tile)
        // first adopts the actual size into the layout — neighbors make room —
        // and floats only if adoption keeps failing.
        if actual.diverges(from: target, tolerance: 50) {
            let attempts = (adoptAttempts[wid.rawValue] ?? 0) + 1
            adoptAttempts[wid.rawValue] = attempts
            if attempts > snapBackLimit {
                pendingAutoFloats.append((wid, actual.cgRect))
            } else {
                pendingAdoptions.append((wid, actual.cgRect))
            }
        } else if actual.diverges(from: target, tolerance: 2) {
            NSLog("applland: window %u refused frame (wanted %@, got %@)",
                  wid.rawValue, String(describing: target), String(describing: actual))
        }
    }

    private func park(_ wid: WindowID) {
        guard let ax = axWindows[wid.rawValue], !parkingBounds.isEmpty else { return }
        expectedFrames.removeValue(forKey: wid.rawValue)
        snapBackAttempts.removeValue(forKey: wid.rawValue)
        parkedWindows.insert(wid.rawValue)
        ax.setFrame(OffscreenParking.parkFrame(size: ax.frame.size, bounds: parkingBounds))
    }

    // MARK: - WindowTrackerDelegate (axQueue)

    func windowDiscovered(_ window: AXWindow, app: AXAppInfo) {
        guard axWindows[window.id] == nil, !state.monitors.isEmpty else { return }
        // Native tabs: every tab is its own AXWindow sharing the tab group's
        // frame. A new same-pid window at an existing tracked window's exact
        // frame is a tab, not a new tile. ponytail: if the tracked sibling
        // closes, the remaining tab stays unmanaged until adopt-window.
        let newFrame = window.frame
        if axWindows.values.contains(where: { $0.pid == app.pid && $0.id != window.id && !$0.frame.diverges(from: newFrame, tolerance: 2) }) {
            NSLog("applland: window %u looks like a tab sibling of %@, not tiling it", window.id, app.name ?? "?")
            return
        }
        axWindows[window.id] = window
        windowPids[window.id] = app.pid
        let frame = window.frame.cgRect
        let node = WindowNode(
            id: WindowID(window.id),
            appBundleID: app.bundleIdentifier ?? "",
            pid: app.pid,
            title: window.title,
            frame: frame
        )
        adopt(node, frame: frame)
    }

    func windowDestroyed(id: AXWindowID) {
        removeWindow(id)
    }

    func windowFocused(id: AXWindowID) {
        guard axWindows[id] != nil else { return }
        _ = WM.focusChangedExternally(WindowID(id), state: &state)
        updateFocusBorder()
        updateBar()
    }

    func windowMoved(id: AXWindowID, newFrame: AXFrame) {
        enforceTiling(id: id, newFrame: newFrame)
        updateFocusBorder()
    }

    func windowResized(id: AXWindowID, newFrame: AXFrame) {
        enforceTiling(id: id, newFrame: newFrame)
        updateFocusBorder()
    }

    func windowMiniaturized(id: AXWindowID) {
        // Milestone 1: treat like a closed window so the layout reflows;
        // deminiaturize re-inserts it via windowDeminiaturized.
        guard let ax = axWindows[id] else { return }
        _ = ax // keep AX ref alive in axWindows for deminiaturize
        execute(WM.windowRemoved(WindowID(id), state: &state))
    }

    func windowDeminiaturized(id: AXWindowID) {
        guard let ax = axWindows[id], let pid = windowPids[id], !state.monitors.isEmpty else { return }
        let app = NSRunningApplication(processIdentifier: pid)
        let frame = ax.frame.cgRect
        let node = WindowNode(
            id: WindowID(id),
            appBundleID: app?.bundleIdentifier ?? "",
            pid: pid,
            title: ax.title,
            frame: frame
        )
        adopt(node, frame: frame)
    }

    func appTerminated(pid: pid_t) {
        for id in windowPids.filter({ $0.value == pid }).keys {
            removeWindow(id)
        }
    }

    // MARK: - Helpers (axQueue)

    /// Places a newly seen window on the display it is physically on — an app
    /// restoring its window on the external screen shouldn't jump to whichever
    /// display happens to be focused.
    private func adopt(_ node: WindowNode, frame: CGRect) {
        // Per-app rule wins: [app-workspaces] sends the window straight to its
        // configured workspace (parked if that workspace is hidden).
        if let ruled = config.appWorkspaces?[node.appBundleID],
           let (monitorIdx, _) = state.locate(workspace: ruled) {
            execute(WM.windowAdded(node, toWorkspace: ruled, onMonitor: monitorIdx, state: &state))
            return
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let monitorIdx = state.monitors.firstIndex { $0.frame.contains(center) } ?? state.focusedMonitorIndex
        guard state.monitors.indices.contains(monitorIdx) else { return }
        let wsName = state.monitors[monitorIdx].activeWorkspace.name
        execute(WM.windowAdded(node, toWorkspace: wsName, onMonitor: monitorIdx, state: &state))
    }

    private func removeWindow(_ id: AXWindowID) {
        guard axWindows.removeValue(forKey: id) != nil else { return }
        windowPids.removeValue(forKey: id)
        expectedFrames.removeValue(forKey: id)
        snapBackAttempts.removeValue(forKey: id)
        adoptAttempts.removeValue(forKey: id)
        parkedWindows.remove(id)
        execute(WM.windowRemoved(WindowID(id), state: &state))
    }

    private func enforceTiling(id: AXWindowID, newFrame: AXFrame) {
        guard let ax = axWindows[id] else { return }
        if parkedWindows.contains(id) {
            guard !parkingBounds.isEmpty,
                  !OffscreenParking.isParked(newFrame, bounds: parkingBounds) else { return }
            // macOS rescued the parked window onto a display (typically after
            // monitor unplug) — send it back, with the same give-up limit as
            // snap-back so a window macOS insists on rescuing doesn't loop.
            let attempts = (snapBackAttempts[id] ?? 0) + 1
            guard attempts <= snapBackLimit else {
                NSLog("applland: window %u keeps escaping parking, leaving it visible", id)
                return
            }
            snapBackAttempts[id] = attempts
            ax.setFrame(OffscreenParking.parkFrame(size: newFrame.size, bounds: parkingBounds))
            return
        }
        // Floating windows: no enforcement, but remember where the user put
        // them so focus navigation and layout state stay accurate.
        if state.windows[WindowID(id)]?.isFloating == true {
            execute(WM.windowResizedByUser(WindowID(id), to: newFrame.cgRect, state: &state))
            return
        }
        guard let expected = expectedFrames[id] else { return }
        guard expected.diverges(from: newFrame, tolerance: 2) else {
            snapBackAttempts.removeValue(forKey: id) // converged
            return
        }
        // Native mouse drag: don't fight the user mid-drag; when the button is
        // released, adopt the final size into the layout (splits re-ratio).
        // ponytail: if no event fires after mouse-up, the next divergence for
        // this window adopts instead of snapping — acceptable, it matches the
        // old "accept the app's frame" behavior.
        if CGEventSource.buttonState(.combinedSessionState, button: .left) {
            dragResizing.insert(id)
            return
        }
        if dragResizing.remove(id) != nil {
            execute(WM.windowResizedByUser(WindowID(id), to: newFrame.cgRect, state: &state))
            return
        }
        let attempts = (snapBackAttempts[id] ?? 0) + 1
        if attempts > snapBackLimit {
            // App insists on its own frame — float it so the layout reflows
            // around it instead of leaving a mis-sized tile overlapping others.
            NSLog("applland: window %u keeps resizing itself, floating it", id)
            expectedFrames.removeValue(forKey: id)
            snapBackAttempts.removeValue(forKey: id)
            execute(WM.floatWindow(WindowID(id), frame: newFrame.cgRect, state: &state))
            return
        }
        snapBackAttempts[id] = attempts
        ax.setFrame(expected)
    }
}
