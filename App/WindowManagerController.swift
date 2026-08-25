// Glue between AXBridge (events + effects execution), WMCore (state) and
// InputSystem (hotkeys). Milestone 1: single monitor, dwindle, workspaces 1-9.
//
// Threading: all state here is owned by the axQueue. WindowTrackerDelegate
// callbacks already arrive on it; hotkey handling marshals in via
// tracker.perform. Never touch `state` from any other context.

import AppKit
import AXBridge
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
            MonitorInfo(id: $0.id, name: $0.name, frame: $0.frame, visibleFrame: $0.visibleFrame)
        }
        execute(WM.reconcileMonitors(
            monitors,
            workspaceNames: workspaceNames,
            makeWorkspace: { Workspace(name: $0, layout: DwindleLayout()) },
            state: &state
        ))
    }

    // MARK: - Command / effect pipeline (axQueue)

    private func run(_ command: Command) {
        execute(WM.dispatch(command, state: &state))
    }

    private func execute(_ effects: [Effect]) {
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
        updateFocusBorder()
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
        if actual.diverges(from: target, tolerance: 2) {
            // ponytail: log only; Milestone-later auto-floats windows that refuse frames.
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
        guard let expected = expectedFrames[id] else { return }
        guard expected.diverges(from: newFrame, tolerance: 2) else {
            snapBackAttempts.removeValue(forKey: id) // converged
            return
        }
        let attempts = (snapBackAttempts[id] ?? 0) + 1
        if attempts > snapBackLimit {
            // App insists on its own frame — accept it rather than fighting.
            NSLog("applland: window %u keeps resizing itself, accepting its frame", id)
            expectedFrames[id] = newFrame
            snapBackAttempts.removeValue(forKey: id)
            return
        }
        snapBackAttempts[id] = attempts
        ax.setFrame(expected)
    }
}
