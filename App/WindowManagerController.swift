// Glue between AXBridge (events + effects execution), WMCore (state) and
// InputSystem (hotkeys). Milestone 1: single monitor, dwindle, workspaces 1-9.
//
// Threading: all state here is owned by the axQueue. WindowTrackerDelegate
// callbacks already arrive on it; hotkey handling marshals in via
// tracker.perform. Never touch `state` from any other context.

import Animator
import AppKit
import AXBridge
import Bar
import Config
import InputSystem
import LayoutEngine
import UserNotifications
import WMCore

final class WindowManagerController: WindowTrackerDelegate {
    private let tracker = WindowTracker()
    private let input = InputSystem()
    private let displays = DisplayManager()
    /// Mutable for hot-reload; owned by the axQueue after start().
    private var config: AppConfig
    /// Guarded by bindingsLock — the event tap thread reads while hot-reload
    /// replaces the whole dictionary.
    private var bindings: [String: Command] = [:]
    private let bindingsLock = NSLock()
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
    /// Created on the main thread (NSWindow requirement); the reference is
    /// owned by the axQueue, window operations happen via DispatchQueue.main.
    /// Nil when disabled.
    private var focusBorder: FocusBorder?
    /// Created in start() (main thread); nil when disabled in config.
    private var bar: BarController?
    /// Dock notification badges by pid (axQueue). ponytail: polled — macOS
    /// has no public event for badge changes; 2.5 s keeps it invisible in CPU.
    private var dockBadges: [pid_t: String] = [:]
    private var badgeTimer: Timer?
    /// Current layout name per workspace, for the bar (Workspace itself only
    /// stores the layout instance, not its config name).
    private var workspaceLayoutNames: [String: String] = [:]
    /// Effective [bar] config per monitor id ([bar] + [bar-overrides]),
    /// resolved at every display reconfiguration. (axQueue)
    private var barConfigs: [String: AppConfig.Bar] = [:]
    /// Workspaces auto-switched to stack on a cramped monitor, with the
    /// layout to restore once they fit again. (axQueue)
    private var autoStackedOriginals: [String: String] = [:]
    /// Divergence events per workspace within the current refusal burst;
    /// above auto-stack-thrash-limit the workspace is auto-stacked. (axQueue)
    private var thrashCounts: [String: Int] = [:]
    /// Tiled-window count at the moment a workspace was thrash-stacked —
    /// the width heuristic already said "fits" there, so restore the original
    /// layout only once the count drops below it. (axQueue)
    private var thrashStackCounts: [String: Int] = [:]
    /// Refusal counters reset after a quiet period rather than per execute()
    /// cascade: animated completions arrive at depth 0, and a per-cascade
    /// reset wiped the counts every round (endless ping-pong). (axQueue)
    private var lastDivergence = Date.distantPast
    /// Keybind cheatsheet (main thread only). Nil when disabled in config.
    private var helpOverlay: HelpOverlay?
    private var helpTimer: Timer?
    /// Main thread; read by the hyper-hold handler.
    private var helpDelaySeconds: Double = 2
    /// Eases frame changes (axQueue). Slow apps auto-fall back to instant.
    private var animator: Animator
    /// Pause = drop all placement effects and enforcement; state keeps
    /// updating, resume re-places everything from state. (axQueue)
    private var tilingPaused = false
    /// What a left-drag drop will do, decided by the cursor's position within
    /// the target tile: edge zones insert on that side, the center swaps.
    private enum DropAction: Equatable {
        case insert(target: WindowID, edge: Direction)
        case swap(target: WindowID)
    }
    /// Active hyper+mouse drag: left = move, right = resize. A tiled window
    /// keeps its layout slot during the drag (only the AX window follows the
    /// mouse) so the center zone can swap slots on drop.
    private struct MouseDragState {
        let window: WindowID
        let button: HyperMouseButton
        let wasTiled: Bool
        /// Native = the app moves/resizes its own window (no hyper); the WM
        /// only tracks and applies the result — it never setFrames mid-drag.
        let isNative: Bool
        var lastLocation: CGPoint
        var action: DropAction?
        /// Where `action` was last computed — mouse events fire far more often
        /// than visually distinct positions, so the layout simulation only
        /// reruns after the cursor moves a few points.
        var lastActionLocation: CGPoint?
    }
    private var mouseDrag: MouseDragState?
    /// Placement effects bypass animation (live mouse resize). (axQueue)
    private var instantPlacement = false
    /// Future-layout drop preview (main thread windows, axQueue reference).
    private var dropPreview: LayoutPreview?
    /// Fires on main whenever the pause state flips (menu checkbox sync).
    var onTilingPausedChanged: ((Bool) -> Void)?
    /// IPC for ancrectl / MCP.
    private var controlServer: ControlServer?
    /// Spotlight-style window switcher (main thread only).
    private var switcher: SwitcherOverlay?
    /// Letter hints for visible windows (main thread only).
    private var hints: HintsOverlay?

    init(config: AppConfig) {
        self.config = config
        animator = Animator(settings: .init(
            enabled: config.general.animations,
            duration: min(max(Double(config.general.animationDurationMs) / 1000, 0.05), 0.5),
            excluded: Set(config.general.animationsExclude)
        ))
        if config.border?.enabled ?? true {
            let color = (config.border?.color ?? config.theme?.accent)
                .flatMap { NSColor(hex: $0) } ?? .controlAccentColor
            focusBorder = FocusBorder(
                color: color,
                width: config.border?.width ?? 2,
                radius: config.border?.radius ?? 10
            )
        } else {
            focusBorder = nil
        }
        let previewColor = (config.preview?.color ?? config.theme?.accent).flatMap { NSColor(hex: $0) } ?? .controlAccentColor
        dropPreview = LayoutPreview(color: previewColor, fillOpacity: config.preview?.opacity ?? 0.3)
        // Monitors (and with them the workspaces) are created by the first
        // DisplayManager callback, so startup and replug take the same path.
        self.state = WMState(
            monitors: [],
            innerGap: config.general.gapsInner,
            outerGap: config.general.gapsOuter,
            workspaceAssignments: config.workspaces?.mapValues(\.values) ?? [:]
        )
    }

    func start() {
        L10n.language = config.general.language
        let resolved = ConfigLoader.resolveBindings(config)
        resolved.warnings.forEach { NSLog("ancre: %@", $0) }
        setBindings(resolved.bindings)

        bar = makeBarController()
        bar?.onRegionsChanged = { [weak self] regions in self?.input.setPassThroughRegions(regions) }
        rebuildHelpOverlay()

        // Displays first: window discovery needs monitors to place windows on.
        displays.start { [weak self] infos in
            self?.applyDisplays(infos)
        }

        // Dock badge polling; Timer fires on main, work hops to axQueue.
        // Runs even with the bar disabled (a reload may enable it) — the
        // tick is a no-op without a bar.
        badgeTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.tracker.perform {
                guard let self, self.bar != nil else { return }
                let fresh = DockBadges.current()
                if fresh != self.dockBadges {
                    self.dockBadges = fresh
                    self.updateBar()
                }
            }
        }

        tracker.delegate = self
        tracker.start()

        // Starting while the session is locked finds zero AX windows —
        // rescan when the session/screen comes back.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: nil
        ) { [weak self] _ in self?.retile() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: nil
        ) { [weak self] _ in self?.retile() }

        controlServer = ControlServer { [weak self] request, reply in
            guard let self else { reply("error: shutting down"); return }
            self.tracker.perform { reply(self.handleControl(request)) }
        }

        start_inputOnly()
    }

    // MARK: - IPC (axQueue)

    private func handleControl(_ request: String) -> String {
        if request == "state" { return stateJSON() }
        if request == "reload-config" {
            reloadConfig()
            return "ok"
        }

        // IPC-only verbs targeting a specific window by id (from `state`) —
        // the Command grammar stays keybinding-oriented.
        let parts = request.split(separator: " ").map(String.init)
        switch parts.first {
        case "move-window" where parts.count == 3:
            guard let raw = UInt32(parts[1]) else { return "error: bad window id" }
            let wid = WindowID(raw)
            guard state.windows[wid] != nil else { return "error: unknown window \(raw)" }
            guard state.locate(workspace: parts[2]) != nil else { return "error: unknown workspace \(parts[2])" }
            execute(WM.moveWindow(wid, toWorkspace: parts[2], state: &state))
            return "ok"
        case "focus-window" where parts.count == 2:
            guard let raw = UInt32(parts[1]), state.windows[WindowID(raw)] != nil else { return "error: unknown window" }
            let wid = WindowID(raw)
            if let location = state.windowLocation[wid] {
                run(.workspace(location.workspaceName))
            }
            execute(WM.focusChangedExternally(wid, state: &state))
            execute([.focusWindow(wid)])
            return "ok"
        case "set-floating" where parts.count == 3:
            guard let raw = UInt32(parts[1]), state.windows[WindowID(raw)] != nil else { return "error: unknown window" }
            guard let floating = Bool(parts[2]) else { return "error: bad bool" }
            execute(WM.setFloating(WindowID(raw), floating: floating, state: &state))
            return "ok"
        default:
            break
        }

        if request.hasPrefix("arrange ") {
            guard let data = request.dropFirst("arrange ".count).data(using: .utf8),
                  let arrangement = try? JSONDecoder().decode(Arrangement.self, from: data) else {
                return "error: arrange expects JSON {layouts?, apps?, windows?, active?, focus?}"
            }
            return applyArrangement(arrangement)
        }
        if case .presetApply(let name)? = Command.parse(request) { return applyPreset(named: name) }
        if case .presetSave(let name)? = Command.parse(request) { return savePreset(named: name) }
        guard let command = Command.parse(request) else {
            return "error: unknown command \"\(request)\""
        }
        run(command)
        return "ok"
    }

    private struct StateDTO: Encodable {
        struct Window: Encodable {
            let id: UInt32
            let pid: Int32
            let bundleID: String
            let title: String
            let floating: Bool
            let focused: Bool
        }
        struct WorkspaceDTO: Encodable {
            let name: String
            let layout: String
            let active: Bool
            let windows: [Window]
        }
        struct MonitorDTO: Encodable {
            let id: String
            let focused: Bool
            let workspaces: [WorkspaceDTO]
        }
        let tilingPaused: Bool
        let monitors: [MonitorDTO]
    }

    private func stateJSON() -> String {
        let globallyFocused: WindowID? = state.monitors.indices.contains(state.focusedMonitorIndex)
            ? state.monitors[state.focusedMonitorIndex].activeWorkspace.focusedWindow
            : nil
        let dto = StateDTO(
            tilingPaused: tilingPaused,
            monitors: state.monitors.enumerated().map { index, monitor in
                StateDTO.MonitorDTO(
                    id: monitor.id,
                    focused: index == state.focusedMonitorIndex,
                    workspaces: monitor.workspaces.enumerated().map { wsIndex, workspace in
                        StateDTO.WorkspaceDTO(
                            name: workspace.name,
                            layout: workspaceLayoutNames[workspace.name] ?? config.general.defaultLayout,
                            active: wsIndex == monitor.activeWorkspaceIndex,
                            windows: (workspace.tiledWindows + Array(workspace.floatingFrames.keys)).map { wid in
                                StateDTO.Window(
                                    id: wid.rawValue,
                                    pid: state.windows[wid]?.pid ?? 0,
                                    bundleID: state.windows[wid]?.appBundleID ?? "",
                                    title: axWindows[wid.rawValue]?.title ?? "",
                                    floating: state.windows[wid]?.isFloating ?? false,
                                    focused: wid == globallyFocused
                                )
                            }
                        )
                    }
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(dto), let json = String(data: data, encoding: .utf8) else {
            return "error: state encoding failed"
        }
        return json
    }

    /// Re-reads the user config and applies what can change live: bindings,
    /// gaps, workspace assignments, bar, focus border, help overlay, animator,
    /// language. Existing workspace layouts are left alone. Safe from any
    /// thread (marshals itself).
    func reloadConfig() {
        tracker.perform { [self] in
            let (newConfig, warnings) = ConfigLoader.load()
            warnings.forEach { NSLog("ancre: %@", $0) }
            let oldHyperKey = config.hyper.key
            config = newConfig
            NSLog("ancre: config reloaded")

            DispatchQueue.main.async { L10n.language = newConfig.general.language }
            setBindings(ConfigLoader.resolveBindings(newConfig).bindings)
            animator = Animator(settings: .init(
                enabled: newConfig.general.animations,
                duration: min(max(Double(newConfig.general.animationDurationMs) / 1000, 0.05), 0.5),
                excluded: Set(newConfig.general.animationsExclude)
            ))
            state.innerGap = newConfig.general.gapsInner
            state.outerGap = newConfig.general.gapsOuter
            state.workspaceAssignments = newConfig.workspaces?.mapValues(\.values) ?? [:]

            // Newly ignored apps: drop their windows from management (they
            // stay at their current frame); newly un-ignored ones show up on
            // the next rescan/retile.
            let ignored = newConfig.general.ignoreApps
            if !ignored.isEmpty {
                let drop = state.windows.filter { ignored.contains($0.value.appBundleID) }.keys
                for wid in drop { removeWindow(AXWindowID(wid.rawValue)) }
            }

            rebuildFocusBorder()
            let oldPreview = dropPreview
            let previewColor = (newConfig.preview?.color ?? newConfig.theme?.accent).flatMap { NSColor(hex: $0) } ?? .controlAccentColor
            let previewOpacity = newConfig.preview?.opacity ?? 0.3
            DispatchQueue.main.async { [weak self] in
                oldPreview?.hide()
                let preview = LayoutPreview(color: previewColor, fillOpacity: previewOpacity)
                self?.tracker.perform { self?.dropPreview = preview }
            }
            let oldBar = bar
            bar = makeBarController()
            bar?.onRegionsChanged = { [weak self] regions in self?.input.setPassThroughRegions(regions) }
            DispatchQueue.main.async { oldBar?.close() }
            rebuildHelpOverlay()

            if oldHyperKey != newConfig.hyper.key {
                // Hyper key changed — restart the remap + tap. Must happen on
                // the MAIN thread: EventTapManager binds its run-loop source
                // to the current thread's run loop, and startup bound it to
                // main; restarting from the axQueue would silently rebind the
                // tap onto the axQueue's run loop.
                NSLog("ancre: hyper key changed, restarting input")
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.input.stop()
                    self.start_inputOnly()
                }
            }

            // Re-place everything with the new gaps/assignments; workspace
            // contents and layouts are preserved by reconcile.
            applyDisplays(DisplayManager.current())
        }
    }

    /// Restart just the input stack after a hyper key change (reuses the same
    /// closures as start()).
    private func start_inputOnly() {
        input.start(
            hyperKeyName: config.hyper.key,
            handler: { [weak self] combo in
                guard let self, let command = self.binding(for: combo) else { return false }
                self.tracker.perform { self.run(command) }
                // Using a shortcut restarts the cheatsheet hold timer — hjkl
                // navigation while holding hyper shouldn't pop the help.
                DispatchQueue.main.async {
                    guard let pending = self.helpTimer, pending.isValid, let helpOverlay = self.helpOverlay else { return }
                    pending.invalidate()
                    self.helpTimer = Timer.scheduledTimer(withTimeInterval: self.helpDelaySeconds, repeats: false) { _ in
                        helpOverlay.show()
                    }
                }
                return true
            },
            onHyperMouse: { [weak self] button, phase, location in
                guard let self else { return }
                self.tracker.perform { self.handleHyperMouse(button: button, phase: phase, location: location) }
            },
            onObservedMouseUp: { [weak self] button, _ in
                guard let self else { return }
                self.tracker.perform {
                    // Native drags are physically always the left button;
                    // drag.button only encodes move vs resize semantics.
                    guard let drag = self.mouseDrag, drag.isNative, button == .left else { return }
                    _ = drag
                    self.endMouseDrag()
                }
            },
            onHyperStateChange: { [weak self] down in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.bar?.setHyperPeek(down)
                    guard let helpOverlay = self.helpOverlay else { return }
                    self.helpTimer?.invalidate()
                    if down {
                        self.helpTimer = Timer.scheduledTimer(withTimeInterval: self.helpDelaySeconds, repeats: false) { _ in
                            helpOverlay.show()
                        }
                    } else {
                        self.helpTimer = nil
                        helpOverlay.hide()
                    }
                }
            }
        )
    }

    private func binding(for combo: String) -> Command? {
        bindingsLock.lock()
        defer { bindingsLock.unlock() }
        return bindings[combo]
    }

    private func setBindings(_ new: [String: Command]) {
        bindingsLock.lock()
        bindings = new
        bindingsLock.unlock()
    }

    /// Recreates the focus border from config. axQueue; window work on main.
    private func rebuildFocusBorder() {
        let old = focusBorder
        focusBorder = nil
        DispatchQueue.main.async { old?.hide() }
        guard config.border?.enabled ?? true else { return }
        let borderConfig = config.border
        let accent = config.theme?.accent
        DispatchQueue.main.async { [weak self] in
            let color = (borderConfig?.color ?? accent).flatMap { NSColor(hex: $0) } ?? .controlAccentColor
            let border = FocusBorder(color: color, width: borderConfig?.width ?? 2, radius: borderConfig?.radius ?? 10)
            self?.tracker.perform {
                guard let self else { return }
                self.focusBorder = border
                self.updateFocusBorder()
            }
        }
    }

    /// (Re)creates the help overlay from config. Any thread; work on main.
    private func rebuildHelpOverlay() {
        let cfg = config
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.helpTimer?.invalidate()
            self.helpTimer = nil
            self.helpOverlay?.hide()
            self.helpDelaySeconds = (cfg.help?.delayMs ?? 2000) / 1000
            var style = HelpOverlay.Style()
            if let help = cfg.help {
                style.opacity = help.opacity
                style.fontSize = help.fontSize
                style.columns = help.columns
                style.cornerRadius = help.cornerRadius
            }
            self.helpOverlay = (cfg.help?.enabled ?? true)
                ? HelpOverlay(bindings: cfg.keybindings, hyperKeyName: cfg.hyper.key, style: style)
                : nil
        }
    }

    private static func makeTheme(bar barConfig: AppConfig.Bar, config: AppConfig) -> BarTheme {
        var theme = BarTheme()
        theme.opacity = barConfig.opacity
        theme.align = barConfig.align
        theme.offsetX = barConfig.offsetX
        theme.iconSize = barConfig.iconSize
        theme.background = (barConfig.backgroundColor ?? config.theme?.background).flatMap { NSColor(hex: $0) }
        theme.accent = (barConfig.accentColor ?? config.theme?.accent).flatMap { NSColor(hex: $0) }
        theme.floatColor = barConfig.floatColor.flatMap { NSColor(hex: $0) }
        theme.badgeColor = barConfig.badgeColor.flatMap { NSColor(hex: $0) }
        theme.fontSize = barConfig.fontSize
        theme.fontFamily = barConfig.fontFamily
        theme.spacing = barConfig.spacing
        theme.cellSpacing = barConfig.cellSpacing
        theme.cellRadius = barConfig.cellRadius
        theme.cellPaddingX = barConfig.cellPaddingX
        theme.cellPaddingY = barConfig.cellPaddingY
        theme.pillPaddingX = barConfig.pillPaddingX
        theme.pillPaddingY = barConfig.pillPaddingY
        theme.activeOpacity = barConfig.activeOpacity
        theme.inactiveIconOpacity = barConfig.inactiveIconOpacity
        theme.ringWidth = barConfig.ringWidth
        theme.maxIcons = barConfig.maxIcons
        theme.notchSide = barConfig.notchSide
        theme.position = barConfig.position
        theme.peek = barConfig.peek
        theme.idleOpacity = barConfig.idleOpacity
        return theme
    }

    private func makeBarController() -> BarController? {
        guard config.bar.enabled else { return nil }
        let theme = Self.makeTheme(bar: config.bar, config: config)
        return BarController(
                theme: theme,
                onSelect: { [weak self] name in
                    guard let self else { return }
                    self.tracker.perform { self.run(.workspace(name)) }
                },
                onMoveWindow: { [weak self] windowID, name in
                    guard let self else { return }
                    self.tracker.perform {
                        self.logMove(WindowID(windowID), to: name, source: "bar")
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
                        self.execute(WM.focusChangedExternally(wid, state: &self.state))
                        self.execute([.focusWindow(wid)])
                    }
                },
                onSetLayout: { [weak self] workspaceName, layoutName in
                    guard let self else { return }
                    self.tracker.perform { self.applyLayout(named: layoutName, toWorkspace: workspaceName) }
                },
                onToggleFloat: { [weak self] windowID in
                    guard let self else { return }
                    self.tracker.perform {
                        let wid = WindowID(windowID)
                        let floating = self.state.windows[wid]?.isFloating ?? false
                        self.execute(WM.setFloating(wid, floating: !floating, state: &self.state))
                    }
                },
                onToggleFullscreen: { [weak self] windowID in
                    guard let self else { return }
                    self.tracker.perform {
                        // Fullscreen works on the focused window — focus it first.
                        self.execute(WM.focusChangedExternally(WindowID(windowID), state: &self.state))
                        self.execute([.focusWindow(WindowID(windowID))])
                        self.run(.toggleFullscreen)
                    }
                }
        )
    }

    func stop() {
        badgeTimer?.invalidate()
        input.stop()
        displays.stop()
        tracker.stop()
    }

    // MARK: - Displays (axQueue)

    private func applyDisplays(_ infos: [DisplayInfo]) {
        guard !infos.isEmpty else { return }
        NSLog("ancre: %d display(s): %@", infos.count,
              infos.map { "\($0.name) [\($0.id)]" }.joined(separator: ", "))
        parkingBounds = infos.dropFirst().reduce(infos[0].frame) { $0.union($1.frame) }
        barConfigs = Dictionary(uniqueKeysWithValues: infos.map {
            ($0.id, config.bar(forMonitorID: $0.id, name: $0.name, hasNotch: $0.hasNotch))
        })
        let monitors = infos.map {
            MonitorInfo(id: $0.id, name: $0.name, frame: $0.frame, visibleFrame: reserveBarStrip(in: $0.visibleFrame, bar: barConfigs[$0.id] ?? config.bar))
        }
        execute(WM.reconcileMonitors(
            monitors,
            workspaceNames: workspaceNames,
            makeWorkspace: { [config] name in
                let layoutName = config.workspaceLabels?[name]?.layout ?? config.general.defaultLayout
                self.workspaceLayoutNames[name] = layoutName
                return Workspace(name: name, layout: Self.makeLayout(named: layoutName, config: config))
            },
            state: &state
        ))
    }

    /// Carves the bar strip out of a monitor's usable area so tiles don't
    /// render under it. CG coordinates: top of the screen is minY.
    private func reserveBarStrip(in visibleFrame: CGRect, bar: AppConfig.Bar) -> CGRect {
        guard bar.enabled else { return visibleFrame }
        // menubar/notch modes live inside the system menu-bar band — no
        // tiling space is reserved at all.
        guard bar.position != "menubar", bar.position != "notch" else { return visibleFrame }
        var frame = visibleFrame
        let reserved = bar.height + bar.offsetY
        switch bar.position {
        case "left":
            frame.origin.x += reserved
            frame.size.width -= reserved
        case "right":
            frame.size.width -= reserved
        case "bottom":
            frame.size.height -= reserved
        default: // top
            frame.origin.y += reserved
            frame.size.height -= reserved
        }
        return frame
    }

    /// Snapshot of workspaces per monitor for the bar, marshaled to main.
    private func updateBar() {
        guard let bar else { return }
        let globallyFocused: WindowID? = state.monitors.indices.contains(state.focusedMonitorIndex)
            ? state.monitors[state.focusedMonitorIndex].activeWorkspace.focusedWindow
            : nil
        let allWorkspaceNames = state.monitors.flatMap { $0.workspaces.map(\.name) }.sorted().map { name -> BarWorkspaceRef in
            let label = config.workspaceLabels?[name]
            let title = [name, label?.icon, label?.name].compactMap { $0 }.joined(separator: " ")
            return BarWorkspaceRef(name: name, title: title)
        }
        let availableLayouts = ["dwindle", "scroll", "stack"] + (config.customLayouts?.keys.sorted() ?? [])
        let snapshots = state.monitors.enumerated().map { index, monitor -> (String, CGRect, [BarWorkspaceItem], Bool, Bool, BarTheme) in
            let barConfig = barConfigs[monitor.id] ?? config.bar
            let strip: CGRect
            if barConfig.position == "menubar" || barConfig.position == "notch" {
                // The system menu-bar band (frame top to visibleFrame top);
                // fall back to the configured height on displays reporting 0.
                let bandHeight = max(monitor.visibleFrame.minY - monitor.frame.minY, barConfig.height)
                strip = CGRect(x: monitor.frame.minX, y: monitor.frame.minY, width: monitor.frame.width, height: bandHeight)
            } else if barConfig.position == "left" || barConfig.position == "right" {
                strip = CGRect(
                    x: barConfig.position == "left" ? monitor.visibleFrame.minX - barConfig.height : monitor.visibleFrame.maxX,
                    y: monitor.visibleFrame.minY,
                    width: barConfig.height,
                    height: monitor.visibleFrame.height
                )
            } else {
                strip = CGRect(
                    x: monitor.visibleFrame.minX,
                    y: barConfig.position == "bottom" ? monitor.visibleFrame.maxY : monitor.visibleFrame.minY - barConfig.height,
                    width: monitor.visibleFrame.width,
                    height: barConfig.height
                )
            }
            let items = monitor.workspaces.enumerated().compactMap { wsIndex, workspace -> BarWorkspaceItem? in
                // hide-when-empty: skip empty workspaces, except the active one
                // (the user must always see where they are).
                if config.workspaceLabels?[workspace.name]?.hideWhenEmpty == true,
                   workspace.allWindows.isEmpty, wsIndex != monitor.activeWorkspaceIndex {
                    return nil
                }
                let windows = (workspace.tiledWindows + Array(workspace.floatingFrames.keys)).compactMap { wid -> BarWindowItem? in
                    guard let pid = state.windows[wid]?.pid else { return nil }
                    return BarWindowItem(
                        windowID: wid.rawValue,
                        pid: pid,
                        isFocused: wid == globallyFocused,
                        badge: dockBadges[pid],
                        isFloating: state.windows[wid]?.isFloating ?? false,
                        isFullscreen: state.windows[wid]?.isFullscreen ?? false
                    )
                }
                let label = config.workspaceLabels?[workspace.name]
                return BarWorkspaceItem(
                    name: workspace.name,
                    displayName: label?.name,
                    icon: label?.icon,
                    showNumber: label?.showNumber ?? true,
                    isActive: wsIndex == monitor.activeWorkspaceIndex,
                    windows: windows,
                    layoutName: workspaceLayoutNames[workspace.name] ?? config.general.defaultLayout
                )
            }
            let compact = barConfig.position == "menubar" || barConfig.position == "notch"
            return (monitor.id, strip, items, index == state.focusedMonitorIndex, compact, Self.makeTheme(bar: barConfig, config: config))
        }
        DispatchQueue.main.async {
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            bar.update(snapshots.map { id, strip, items, focused, compact, theme in
                BarMonitorSnapshot(
                    monitorID: id,
                    barFrame: DisplayManager.nsScreenRect(fromCGRect: strip, primaryHeight: primaryHeight),
                    workspaces: items,
                    isFocusedMonitor: focused,
                    allWorkspaceNames: allWorkspaceNames,
                    availableLayouts: availableLayouts,
                    compact: compact,
                    theme: theme
                )
            })
        }
    }

    // MARK: - Command / effect pipeline (axQueue)

    private func run(_ command: Command) {
        switch command {
        case .moveToWorkspace(let name):
            if state.monitors.indices.contains(state.focusedMonitorIndex),
               let focused = state.monitors[state.focusedMonitorIndex].activeWorkspace.focusedWindow {
                logMove(focused, to: name, source: "keybind")
            }
        case .adoptWindow:
            adoptFrontmostWindow()
            return
        case .setLayout(let name):
            guard state.monitors.indices.contains(state.focusedMonitorIndex) else { return }
            applyLayout(named: name, toWorkspace: state.monitors[state.focusedMonitorIndex].activeWorkspace.name)
            return
        case .pauseTiling:
            setTilingPausedOnQueue(!tilingPaused)
            return
        case .retile:
            tracker.rescanWindows()
            applyDisplays(DisplayManager.current())
            return
        case .openConfig:
            DispatchQueue.main.async { NSWorkspace.shared.open(ConfigLoader.userConfigURL) }
            return
        case .switcher(let commandsOnly):
            showSwitcher(commandsOnly: commandsOnly)
            return
        case .scratchpad:
            toggleScratchpad()
            return
        case .hints:
            showHints()
            return
        case .presetApply(let name):
            _ = applyPreset(named: name)
            return
        case .presetSave(let name):
            _ = savePreset(named: name)
            return
        case .quit:
            NSLog("ancre: quit command — terminating")
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return
        default:
            break
        }
        execute(WM.dispatch(command, state: &state))
    }

    // MARK: - Menu-facing API (safe from any thread)

    func toggleTilingPause() {
        tracker.perform { self.setTilingPausedOnQueue(!self.tilingPaused) }
    }

    func retile() {
        tracker.rescanWindows()
        tracker.perform { self.applyDisplays(DisplayManager.current()) }
    }

    func adoptWindowFromMenu() {
        tracker.perform { self.adoptFrontmostWindow() }
    }

    func showSwitcherFromMenu() {
        tracker.perform { self.showSwitcher() }
    }

    /// hyper+left drag = move (floats the window first; dropping over a tile
    /// inserts next to it, shown by a live placeholder). hyper+right drag =
    /// resize — a tiled window re-ratios the layout live, neighbors follow,
    /// exactly like the keyboard resize. (axQueue)
    private func handleHyperMouse(button: HyperMouseButton, phase: HyperMousePhase, location: CGPoint) {
        guard !tilingPaused else { return }
        switch phase {
        case .began:
            guard let id = tracker.windowID(at: location), axWindows[id] != nil else { return }
            let wid = WindowID(id)
            execute(WM.focusChangedExternally(wid, state: &state))
            execute([.focusWindow(wid)])
            mouseDrag = MouseDragState(
                window: wid,
                button: button,
                wasTiled: state.windows[wid]?.isFloating != true,
                isNative: false,
                lastLocation: location,
                action: nil
            )
        case .moved:
            guard var drag = mouseDrag, let ax = axWindows[drag.window.rawValue] else { return }
            let dx = location.x - drag.lastLocation.x
            let dy = location.y - drag.lastLocation.y
            drag.lastLocation = location
            animator.cancel(drag.window.rawValue)
            var frame = ax.frame
            if drag.button == .left {
                frame.origin.x += dx
                frame.origin.y += dy
                _ = ax.setFrame(frame)
                if drag.lastActionLocation == nil || abs(location.x - drag.lastActionLocation!.x) >= 5 || abs(location.y - drag.lastActionLocation!.y) >= 5 {
                    drag.action = updateDropAction(for: drag, at: location)
                    drag.lastActionLocation = location
                }
            } else if state.windows[drag.window]?.isFloating == true {
                frame.size.width = max(100, frame.size.width + dx)
                frame.size.height = max(100, frame.size.height + dy)
                _ = ax.setFrame(frame)
            } else {
                // Tiled resize: re-ratio the layout live so neighbors follow.
                frame.size.width = max(100, frame.size.width + dx)
                frame.size.height = max(100, frame.size.height + dy)
                instantPlacement = true
                execute(WM.windowResizedByUser(drag.window, to: frame.cgRect, state: &state))
                instantPlacement = false
            }
            mouseDrag = drag
        case .ended:
            endMouseDrag()
        }
    }

    /// Applies the outcome of a drag (hyper or native) and clears the state.
    private func endMouseDrag() {
        do {
            guard let drag = mouseDrag else { return }
            mouseDrag = nil
            DispatchQueue.main.async { self.dropPreview?.hide() }
            guard let ax = axWindows[drag.window.rawValue] else { return }
            guard drag.button == .left else {
                // Right-drag: floats remember the final frame; a live-resized
                // tile already adopted its ratios.
                execute(WM.windowResizedByUser(drag.window, to: ax.frame.cgRect, state: &state))
                return
            }
            switch drag.action {
            case .insert(let target, let edge):
                if let targetWs = state.windowLocation[target]?.workspaceName {
                    logMove(drag.window, to: targetWs, source: "drag")
                }
                execute(WM.tileWindow(drag.window, after: target, edge: edge, state: &state))
            case .swap(let target):
                execute(WM.swapWindows(drag.window, target, state: &state))
            case nil where drag.wasTiled:
                // Dropped on its own slot = snap back; outside any tile = the
                // tile becomes a float where the user left it (explicit user
                // action, not an auto-float).
                if let location = state.windowLocation[drag.window],
                   state.monitors.indices.contains(location.monitorIndex) {
                    let monitor = state.monitors[location.monitorIndex]
                    if let own = WM.allFrames(for: monitor.activeWorkspace, monitor: monitor, state: state)[drag.window],
                       own.contains(drag.lastLocation) {
                        assign(frame: AXFrame(origin: own.origin, size: own.size), to: drag.window)
                        return
                    }
                }
                execute(WM.floatWindow(drag.window, frame: ax.frame.cgRect, state: &state))
                state.autoFloated.remove(drag.window)
            case nil:
                execute(WM.windowResizedByUser(drag.window, to: ax.frame.cgRect, state: &state))
            }
        }
    }

    /// Current global mouse position in CG (top-left) coordinates.
    private static func mouseLocation() -> CGPoint? {
        CGEvent(source: nil)?.location
    }

    /// Hyprland-style special workspace: the scratchpad window lives entirely
    /// OUTSIDE ancre's model — it is never registered in `state` or
    /// `axWindows`, so it has no workspace, no tile, no bar/switcher/hints
    /// entry, and workspace switches leave it alone. `scratchpadAX` is the one
    /// reference to it; the window it wraps is owned by the scratchpad only,
    /// never a window you were already working in.
    private var scratchpadAX: AXWindow?
    private var scratchpadVisible = false
    /// Set while waiting for the spawned scratchpad window to show up.
    private var scratchpadPending = false
    /// Called on the main thread when the scratchpad shows or hides (menubar).
    var onScratchpadVisibleChanged: ((Bool) -> Void)?

    private func toggleScratchpad() {
        guard let scratchpad = config.scratchpad, let bundleID = scratchpad.app else {
            NSLog("ancre: scratchpad has no [scratchpad].app configured")
            return
        }
        guard let ax = scratchpadAX else {
            spawnScratchpad(scratchpad, bundleID: bundleID)
            return
        }
        if scratchpadVisible {
            hideScratchpad(ax)
        } else {
            showScratchpad(ax)
        }
    }

    /// Opens a window dedicated to the scratchpad; `register` adopts it.
    private func spawnScratchpad(_ scratchpad: AppConfig.Scratchpad, bundleID: String) {
        scratchpadPending = true
        // Don't wait forever: a failed launch would otherwise claim whatever
        // window of that app shows up next.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.tracker.perform { self?.scratchpadPending = false }
        }
        if let command = scratchpad.command {
            NSLog("ancre: scratchpad spawning via command: %@", command)
            DispatchQueue.main.async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/sh")
                task.arguments = ["-c", command]
                try? task.run()
            }
            return
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            NSLog("ancre: scratchpad app %@ not installed", bundleID)
            scratchpadPending = false
            return
        }
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        let configuration = NSWorkspace.OpenConfiguration()
        // A running app just gets activated by openApplication — ask for a
        // separate instance so the scratchpad gets a window of its own.
        configuration.createsNewApplicationInstance = running
        NSLog("ancre: scratchpad launching %@ (new instance: %@)", bundleID, running ? "yes" : "no")
        DispatchQueue.main.async { NSWorkspace.shared.openApplication(at: url, configuration: configuration) }
    }

    /// Drops the scratchpad top-center on the focused monitor and focuses it.
    /// Frames are set straight on the AX element — no WM state involved.
    private func showScratchpad(_ ax: AXWindow) {
        guard state.monitors.indices.contains(state.focusedMonitorIndex) else { return }
        let usable = state.monitors[state.focusedMonitorIndex].visibleFrame
        let width = usable.width * (config.scratchpad?.width ?? 0.6)
        let height = usable.height * (config.scratchpad?.height ?? 0.5)
        let frame = AXFrame(
            origin: CGPoint(x: usable.midX - width / 2, y: usable.minY),
            size: CGSize(width: width, height: height)
        )
        setScratchpadVisible(true)
        animator.setFrame(ax, bundleID: config.scratchpad?.app ?? "", to: frame, animated: !instantPlacement) { _ in }
        ax.setFocused()
    }

    /// Parks the scratchpad offscreen and hands the keyboard back to the
    /// focused window of the active workspace.
    private func hideScratchpad(_ ax: AXWindow) {
        guard !parkingBounds.isEmpty else { return }
        animator.cancel(ax.id)
        setScratchpadVisible(false)
        _ = ax.setFrame(OffscreenParking.parkFrame(size: ax.frame.size, bounds: parkingBounds))
        if state.monitors.indices.contains(state.focusedMonitorIndex),
           let wid = state.monitors[state.focusedMonitorIndex].activeWorkspace.focusedWindow {
            execute([.focusWindow(wid)])
        }
    }

    private func setScratchpadVisible(_ visible: Bool) {
        scratchpadVisible = visible
        DispatchQueue.main.async { [onScratchpadVisibleChanged] in onScratchpadVisibleChanged?(visible) }
    }

    /// Menubar item: same toggle as the `scratchpad` command. (any thread)
    func toggleScratchpadFromMenu() {
        tracker.perform { self.toggleScratchpad() }
    }

    // MARK: - Arrangements & presets (axQueue)

    /// A declarative window arrangement: per-workspace layouts, app→workspace
    /// placement, and which workspaces to activate. Presets are named stored
    /// arrangements; the IPC `arrange <json>` applies one directly (MCP).
    private struct Arrangement: Codable {
        var layouts: [String: String]?
        var apps: [String: String]?
        /// Specific windows (id from state, as string keys) -> workspace —
        /// finer than `apps` when one app's windows should split up.
        var windows: [String: String]?
        var active: [String]?
        /// Window to focus at the end.
        var focus: UInt32?
    }

    private static var presetsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ancre/presets.json")
    }

    private func loadPresets() -> [String: Arrangement] {
        guard let data = try? Data(contentsOf: Self.presetsURL) else { return [:] }
        return (try? JSONDecoder().decode([String: Arrangement].self, from: data)) ?? [:]
    }

    private func savePreset(named name: String) -> String {
        var apps: [String: String] = [:]
        var layouts: [String: String] = [:]
        var active: [String] = []
        for monitor in state.monitors {
            active.append(monitor.activeWorkspace.name)
            for workspace in monitor.workspaces {
                layouts[workspace.name] = workspaceLayoutNames[workspace.name] ?? config.general.defaultLayout
                for wid in workspace.allWindows {
                    guard let bundle = state.windows[wid]?.appBundleID, !bundle.isEmpty else { continue }
                    apps[bundle] = apps[bundle] ?? workspace.name // first placement wins
                }
            }
        }
        var presets = loadPresets()
        presets[name] = Arrangement(layouts: layouts, apps: apps, active: active)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(presets) else { return "error: preset encoding failed" }
        do {
            try data.write(to: Self.presetsURL, options: .atomic)
            NSLog("ancre: preset \"%@\" saved", name)
            return "ok"
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }

    @discardableResult
    private func applyArrangement(_ arrangement: Arrangement) -> String {
        for (workspaceName, layoutName) in arrangement.layouts ?? [:] {
            applyLayout(named: layoutName, toWorkspace: workspaceName)
        }
        for (bundle, workspaceName) in arrangement.apps ?? [:] {
            guard state.locate(workspace: workspaceName) != nil else { continue }
            let windows = state.windows.filter { $0.value.appBundleID == bundle }.keys
            for wid in windows {
                execute(WM.moveWindow(wid, toWorkspace: workspaceName, state: &state))
            }
        }
        for (idString, workspaceName) in arrangement.windows ?? [:] {
            guard let raw = UInt32(idString), state.windows[WindowID(raw)] != nil,
                  state.locate(workspace: workspaceName) != nil else { continue }
            execute(WM.moveWindow(WindowID(raw), toWorkspace: workspaceName, state: &state))
        }
        for workspaceName in arrangement.active ?? [] {
            run(.workspace(workspaceName))
        }
        if let focus = arrangement.focus, state.windows[WindowID(focus)] != nil {
            let wid = WindowID(focus)
            if let location = state.windowLocation[wid] {
                run(.workspace(location.workspaceName))
            }
            execute(WM.focusChangedExternally(wid, state: &state))
            execute([.focusWindow(wid)])
        }
        return "ok"
    }

    private func applyPreset(named name: String) -> String {
        guard let arrangement = loadPresets()[name] else {
            return "error: unknown preset \"\(name)\""
        }
        NSLog("ancre: applying preset \"%@\"", name)
        return applyArrangement(arrangement)
    }

    // MARK: - Event stream (axQueue)

    /// Compact state fingerprint; broadcast only on change.
    private var lastBroadcast = ""

    private func broadcastStateIfChanged() {
        guard let controlServer else { return }
        let focused = state.monitors.indices.contains(state.focusedMonitorIndex)
            ? state.monitors[state.focusedMonitorIndex].activeWorkspace : nil
        let line = "{\"event\":\"state-changed\",\"workspace\":\"\(focused?.name ?? "")\",\"focusedWindow\":\(focused?.focusedWindow?.rawValue ?? 0),\"tilingPaused\":\(tilingPaused)}"
        guard line != lastBroadcast else { return }
        lastBroadcast = line
        controlServer.broadcast(line)
    }

    /// Letter badges over all visible windows; a keypress focuses. (axQueue)
    private func showHints() {
        let letters = Array("asdfghjklqwertyuiopzxcvbnm").map(String.init)
        var entries: [HintEntry] = []
        var visible: [(WindowID, CGRect)] = []
        for monitor in state.monitors {
            let frames = WM.allFrames(for: monitor.activeWorkspace, monitor: monitor, state: state)
            for (wid, rect) in frames where rect.intersects(monitor.frame) && !parkedWindows.contains(wid.rawValue) {
                visible.append((wid, rect))
            }
        }
        visible.sort { a, b in
            abs(a.1.minX - b.1.minX) > 1 ? a.1.minX < b.1.minX : a.1.minY < b.1.minY
        }
        for (index, item) in visible.prefix(letters.count).enumerated() {
            entries.append(HintEntry(letter: letters[index], windowID: item.0.rawValue, frame: item.1))
        }
        let union = parkingBounds
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.hints == nil {
                self.hints = HintsOverlay { [weak self] windowID in
                    guard let self else { return }
                    self.tracker.perform {
                        let wid = WindowID(windowID)
                        self.execute(WM.focusChangedExternally(wid, state: &self.state))
                        self.execute([.focusWindow(wid)])
                    }
                }
            }
            if self.hints?.isVisible == true {
                self.hints?.hide()
            } else {
                self.hints?.show(entries: entries, union: union)
            }
        }
    }

    /// Builds the switcher entries from state and shows the overlay;
    /// `commandsOnly` opens with the ">" palette prefix typed in. (axQueue)
    private func showSwitcher(commandsOnly: Bool = false) {
        var entries: [SwitcherEntry] = []
        for monitor in state.monitors {
            for workspace in monitor.workspaces {
                let label = config.workspaceLabels?[workspace.name]
                let workspaceTitle = [workspace.name, label?.icon, label?.name].compactMap { $0 }.joined(separator: " ")
                let focused = workspace.focusedWindow
                for wid in workspace.tiledWindows + Array(workspace.floatingFrames.keys) {
                    guard let node = state.windows[wid] else { continue }
                    entries.append(SwitcherEntry(
                        id: wid.rawValue,
                        pid: node.pid,
                        appName: NSRunningApplication(processIdentifier: node.pid)?.localizedName ?? node.appBundleID,
                        title: axWindows[wid.rawValue]?.title ?? node.title,
                        workspaceTitle: workspaceTitle,
                        isFocused: wid == focused
                    ))
                }
            }
        }
        entries.sort { ($0.appName, $0.title) < ($1.appName, $1.title) }

        // Command palette (">" prefix in the switcher): layouts, saved
        // presets, and the controller-side toggles.
        var palette: [PaletteEntry] = []
        for layout in ["dwindle", "scroll", "stack"] + (config.customLayouts?.keys.sorted() ?? []) {
            palette.append(PaletteEntry(command: "layout \(layout)", title: L10n.paletteLayout(layout)))
        }
        palette.append(PaletteEntry(command: "pause-tiling", title: tilingPaused ? L10n.resumeTiling : L10n.pauseTiling))
        palette.append(PaletteEntry(command: "retile", title: L10n.retile))
        palette.append(PaletteEntry(command: "adopt-window", title: L10n.adoptWindow))
        palette.append(PaletteEntry(command: "scratchpad", title: L10n.paletteScratchpad))
        palette.append(PaletteEntry(command: "open-config", title: L10n.openConfig))
        for name in loadPresets().keys.sorted() {
            palette.append(PaletteEntry(command: "preset \(name)", title: L10n.palettePreset(name)))
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // hyper+space again = toggle off.
            if self.switcher?.isVisible == true {
                self.switcher?.hide()
                return
            }
            if self.switcher == nil {
                self.switcher = SwitcherOverlay(
                    onChoose: { [weak self] windowID in
                        guard let self else { return }
                        self.tracker.perform {
                            let wid = WindowID(windowID)
                            guard let location = self.state.windowLocation[wid] else { return }
                            self.run(.workspace(location.workspaceName))
                            self.execute(WM.focusChangedExternally(wid, state: &self.state))
                            self.execute([.focusWindow(wid)])
                        }
                    },
                    onCommand: { [weak self] command in
                        guard let self, let parsed = Command.parse(command) else { return }
                        if case .switcher = parsed { return }
                        self.tracker.perform { self.run(parsed) }
                    }
                )
            }
            self.switcher?.show(entries: entries, palette: palette, initialQuery: commandsOnly ? ">" : "")
        }
    }

    /// Decides what a drop at `location` would do (edge insert / center swap),
    /// and shows a preview of the WHOLE future layout — how tiles will sit
    /// after the drop, with the dragged window's slot filled.
    private func updateDropAction(for drag: MouseDragState, at location: CGPoint) -> DropAction? {
        let dragged = drag.window
        var action: DropAction?
        var tiles: [LayoutPreview.Tile] = []
        var monitorFrame: CGRect = .zero

        if let monitorIdx = state.monitors.firstIndex(where: { $0.frame.contains(location) }) {
            let monitor = state.monitors[monitorIdx]
            let workspace = monitor.activeWorkspace
            let frames = WM.allFrames(for: workspace, monitor: monitor, state: state)

            for (wid, rect) in frames
            where wid != dragged && rect.contains(location) && workspace.tiledWindows.contains(wid) {
                // Cursor position within the tile picks the zone: the middle
                // (inner 35 % each axis) swaps, otherwise the dominant offset
                // from center picks the insertion side.
                let rx = (location.x - rect.midX) / (rect.width / 2)
                let ry = (location.y - rect.midY) / (rect.height / 2)
                let sameWorkspace = workspace.tiledWindows.contains(dragged)
                if max(abs(rx), abs(ry)) < 0.35, sameWorkspace {
                    action = .swap(target: wid)
                } else if abs(rx) >= abs(ry) {
                    action = .insert(target: wid, edge: rx < 0 ? .left : .right)
                } else {
                    action = .insert(target: wid, edge: ry < 0 ? .up : .down)
                }
                break
            }

            if let action {
                // Layouts are value types — simulate the drop on a copy.
                var future = workspace
                switch action {
                case .insert(let target, let edge):
                    future.floatingFrames.removeValue(forKey: dragged)
                    future.layout.remove(dragged)
                    future.layout.insert(dragged, near: target, edge: edge, container: monitor.visibleFrame, innerGap: state.innerGap, outerGap: state.outerGap)
                case .swap(let target):
                    future.layout.swapPositions(dragged, target)
                }
                monitorFrame = monitor.frame
                tiles = WM.allFrames(for: future, monitor: monitor, state: state).map { wid, rect in
                    LayoutPreview.Tile(
                        rect: rect.offsetBy(dx: -monitor.frame.minX, dy: -monitor.frame.minY),
                        isDragged: wid == dragged
                    )
                }
            }
        }

        // Same action = same preview; skip redundant window churn.
        if action == mouseDrag?.action { return action }

        DispatchQueue.main.async { [weak self] in
            guard let self, let dropPreview = self.dropPreview else { return }
            if tiles.isEmpty {
                dropPreview.hide()
            } else {
                let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
                dropPreview.show(
                    monitorFrame: DisplayManager.nsScreenRect(fromCGRect: monitorFrame, primaryHeight: primaryHeight),
                    tiles: tiles
                )
            }
        }
        return action
    }

    private func setTilingPausedOnQueue(_ paused: Bool) {
        guard paused != tilingPaused else { return }
        tilingPaused = paused
        NSLog("ancre: tiling %@", paused ? "paused" : "resumed")
        DispatchQueue.main.async { self.onTilingPausedChanged?(paused) }
        if paused {
            updateFocusBorder() // hides it
        } else {
            // State kept evolving while effects were dropped — re-place all.
            applyDisplays(DisplayManager.current())
        }
    }

    private func applyLayout(named name: String, toWorkspace workspaceName: String, isAutoStack: Bool = false) {
        if !isAutoStack {
            // A manual layout choice overrides any pending auto-stack restore.
            autoStackedOriginals.removeValue(forKey: workspaceName)
            thrashStackCounts.removeValue(forKey: workspaceName)
        }
        workspaceLayoutNames[workspaceName] = name
        execute(WM.setLayout(Self.makeLayout(named: name, config: config), workspaceNamed: workspaceName, state: &state))
    }

    /// Crowding: workspaces whose tiled windows can't plausibly fit their
    /// monitor switch to stack; they switch back once space returns. Runs
    /// after every top-level execute(), so incremental window adds count too.
    private func applyAutoStack() {
        guard config.general.autoStack, !tilingPaused else { return }
        let minWidth = config.general.autoStackMinWidth
        for monitor in state.monitors {
            for workspace in monitor.workspaces {
                let name = workspace.name
                let count = workspace.tiledWindows.count
                let fits = count <= 1 || Double(count) * minWidth <= monitor.visibleFrame.width
                let current = workspaceLayoutNames[name] ?? config.general.defaultLayout
                if !fits, current != "stack", autoStackedOriginals[name] == nil {
                    NSLog("ancre: workspace %@ doesn't fit %@ (%d windows), auto-stacking", name, monitor.id, count)
                    autoStackedOriginals[name] = current
                    applyLayout(named: "stack", toWorkspace: name, isAutoStack: true)
                    notify(L10n.autoStacked(name))
                } else if fits, let original = autoStackedOriginals[name],
                          count < thrashStackCounts[name] ?? Int.max {
                    NSLog("ancre: workspace %@ fits again, restoring layout %@", name, original)
                    autoStackedOriginals.removeValue(forKey: name)
                    thrashStackCounts.removeValue(forKey: name)
                    applyLayout(named: original, toWorkspace: name, isAutoStack: true)
                }
            }
        }
    }

    /// Runaway retiling: too many refused frames in one burst means the
    /// workspace can't converge by adoption/floating (min-sizes beat every
    /// tile the width heuristic accepted) — switch it to stack and tell the
    /// user why the layout changed. Returns true when it stacked.
    private func autoStackForThrash(_ wid: WindowID) -> Bool {
        guard config.general.autoStack,
              let name = state.windowLocation[wid]?.workspaceName else { return false }
        let count = (thrashCounts[name] ?? 0) + 1
        thrashCounts[name] = count
        let current = workspaceLayoutNames[name] ?? config.general.defaultLayout
        guard count > config.general.autoStackThrashLimit, current != "stack" else { return false }
        NSLog("ancre: workspace %@ keeps thrashing (%d refusals), auto-stacking", name, count)
        autoStackedOriginals[name] = current
        thrashStackCounts[name] = state.monitors
            .flatMap(\.workspaces).first { $0.name == name }?.tiledWindows.count ?? 0
        thrashCounts.removeValue(forKey: name)
        applyLayout(named: "stack", toWorkspace: name, isAutoStack: true)
        notify(L10n.autoStacked(name))
        return true
    }

    /// Fire-and-forget user notification. Skipped when running unbundled
    /// (swift run) — UNUserNotificationCenter needs a real app bundle.
    private func notify(_ body: String) {
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog("ancre: notification (unbundled): %@", body)
            return
        }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "ancre"
            content.body = body
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    // MARK: - Move log (axQueue)

    private static var moveLogURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ancre/move-log.jsonl")
    }

    /// Appends one manual window-move record — the corpus an agent later
    /// turns into [app-workspaces] suggestions. No window titles (privacy).
    private func logMove(_ wid: WindowID, to target: String, source: String) {
        guard config.general.moveLog,
              let node = state.windows[wid], !node.appBundleID.isEmpty,
              let from = state.windowLocation[wid]?.workspaceName, from != target else { return }
        let line = "{\"ts\":\(Int(Date().timeIntervalSince1970)),\"bundleID\":\"\(node.appBundleID)\",\"from\":\"\(from)\",\"to\":\"\(target)\",\"source\":\"\(source)\"}\n"
        let url = Self.moveLogURL
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }

    /// Unknown names fall back to dwindle with a log instead of crashing —
    /// same philosophy as config warnings.
    private static func makeLayout(named name: String, config: AppConfig) -> any Layout {
        if let layout = LayoutFactory.make(name, customLayouts: config.customLayouts ?? [:]) {
            return layout
        }
        NSLog("ancre: unknown layout \"%@\", using dwindle", name)
        return DwindleLayout()
    }

    /// adopt-window: pull the frontmost app's focused window into the focused
    /// workspace — manual rescue for windows discovery missed, and a quick
    /// "bring that here".
    private func adoptFrontmostWindow() {
        guard let id = tracker.frontmostFocusedWindowID(),
              id != scratchpadAX?.id, // the scratchpad is deliberately unmanaged
              state.monitors.indices.contains(state.focusedMonitorIndex) else { return }
        let wid = WindowID(id)
        let target = state.monitors[state.focusedMonitorIndex].activeWorkspace.name
        logMove(wid, to: target, source: "adopt")
        execute(WM.moveWindow(wid, toWorkspace: target, state: &state))
        execute(WM.focusChangedExternally(wid, state: &state))
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

    /// Nesting depth of execute() — adoption/float drains recurse into it.
    private var executeDepth = 0

    private func execute(_ effects: [Effect]) {
        executeDepth += 1
        defer { executeDepth -= 1 }
        for effect in effects {
            if tilingPaused {
                switch effect {
                case .setFrame, .hideWorkspace, .showWorkspace: continue
                case .focusWindow: break
                }
            }
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
        if executeDepth == 1 {
            applyAutoStack()
            drainPendingPlacements()
            updateFocusBorder()
            updateBar()
            broadcastStateIfChanged()
        }
    }

    /// Resolves queued refusals. Recursion is bounded: adoptions by
    /// adoptAttempts, floats by the floatWindow no-op on floating windows.
    private func drainPendingPlacements() {
        while let (wid, frame) = pendingAdoptions.popLast() {
            execute(WM.windowResizedByUser(wid, to: frame, state: &state))
        }
        while let (wid, frame) = pendingAutoFloats.popLast() {
            NSLog("ancre: window %u can't fit its tile, floating it", wid.rawValue)
            execute(WM.floatWindow(wid, frame: frame, state: &state))
        }
    }

    /// Outlines the focused window; hides the border when nothing is focused.
    private func updateFocusBorder() {
        guard let focusBorder else { return }
        // Paused tiling = no WM chrome at all.
        guard !tilingPaused else {
            DispatchQueue.main.async { focusBorder.hide() }
            return
        }
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
            NSLog("ancre: focus border skipped, window %u reports frame %@",
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
        animator.setFrame(ax, bundleID: state.windows[wid]?.appBundleID ?? "", to: target, animated: !instantPlacement) { [weak self] actual in
            self?.finishAssign(wid: wid, target: target, actual: actual)
        }
    }

    /// Bookkeeping after the frame settled. Runs synchronously for instant
    /// placements, later (axQueue) for animated ones.
    private func finishAssign(wid: WindowID, target: AXFrame, actual: AXFrame) {
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
            let now = Date()
            if now.timeIntervalSince(lastDivergence) > 2 {
                adoptAttempts.removeAll()
                thrashCounts.removeAll()
            }
            lastDivergence = now
            if autoStackForThrash(wid) { return }
            let attempts = (adoptAttempts[wid.rawValue] ?? 0) + 1
            adoptAttempts[wid.rawValue] = attempts
            if attempts > snapBackLimit {
                pendingAutoFloats.append((wid, actual.cgRect))
            } else {
                pendingAdoptions.append((wid, actual.cgRect))
            }
        } else if actual.diverges(from: target, tolerance: 2) {
            NSLog("ancre: window %u refused frame (wanted %@, got %@)",
                  wid.rawValue, String(describing: target), String(describing: actual))
        }
        // Animated completions arrive outside execute() — resolve refusals now.
        if executeDepth == 0 {
            drainPendingPlacements()
            updateFocusBorder()
            updateBar()
        }
    }

    private func park(_ wid: WindowID) {
        guard let ax = axWindows[wid.rawValue], !parkingBounds.isEmpty else { return }
        animator.cancel(wid.rawValue) // parking is instant and offscreen
        expectedFrames.removeValue(forKey: wid.rawValue)
        snapBackAttempts.removeValue(forKey: wid.rawValue)
        parkedWindows.insert(wid.rawValue)
        ax.setFrame(OffscreenParking.parkFrame(size: ax.frame.size, bounds: parkingBounds))
    }

    // MARK: - WindowTrackerDelegate (axQueue)

    func windowDiscovered(_ window: AXWindow, app: AXAppInfo) {
        guard axWindows[window.id] == nil, !state.monitors.isEmpty else { return }
        // Native tabs: every tab is its own AXWindow sharing the tab group's
        // frame — but a genuinely new window also opens at the restored frame
        // of its sibling. Distinguish after the window server settles: a tab
        // group keeps only one member onscreen, two real windows stay visible.
        let newFrame = window.frame
        if let sibling = axWindows.values.first(where: { $0.pid == app.pid && $0.id != window.id && !$0.frame.diverges(from: newFrame, tolerance: 2) }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.tracker.perform {
                    guard let self, self.axWindows[window.id] == nil else { return }
                    if Self.isOnscreen(sibling.id) {
                        self.register(window, app: app)
                    } else {
                        // ponytail: if the tracked sibling tab closes later, the
                        // remaining tab stays unmanaged until focus/adopt-window.
                        NSLog("ancre: window %u is a tab sibling of %@, not tiling it", window.id, app.name ?? "?")
                    }
                }
            }
            return
        }
        register(window, app: app)
    }

    private static func isOnscreen(_ id: AXWindowID) -> Bool {
        guard let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else { return false }
        return list.contains { ($0[kCGWindowNumber as String] as? Int) == Int(id) }
    }

    private func register(_ window: AXWindow, app: AXAppInfo) {
        guard axWindows[window.id] == nil, !state.monitors.isEmpty else { return }
        let bundleID = app.bundleIdentifier ?? ""
        // The scratchpad window stays unmanaged — also on a rescan, which
        // would otherwise pull it into the layout it is meant to hover over.
        if window.id == scratchpadAX?.id { return }
        if scratchpadPending, bundleID == config.scratchpad?.app {
            scratchpadPending = false
            scratchpadAX = window
            NSLog("ancre: scratchpad claimed window %u of %@", window.id, bundleID)
            showScratchpad(window)
            return
        }
        if config.general.ignoreApps.contains(bundleID) {
            NSLog("ancre: ignore-apps: not managing window %u of %@", window.id, bundleID)
            return
        }
        axWindows[window.id] = window
        windowPids[window.id] = app.pid
        let frame = window.frame.cgRect
        let node = WindowNode(
            id: WindowID(window.id),
            appBundleID: bundleID,
            pid: app.pid,
            title: window.title,
            isFloating: config.general.floatApps.contains(bundleID),
            frame: frame
        )
        adopt(node, frame: frame)
        let workspace = state.windowLocation[node.id]?.workspaceName ?? ""
        controlServer?.broadcast(
            "{\"event\":\"window-opened\",\"id\":\(node.id.rawValue),\"bundleID\":\"\(node.appBundleID)\",\"workspace\":\"\(workspace)\"}"
        )
    }

    func windowDestroyed(id: AXWindowID) {
        if id == scratchpadAX?.id {
            scratchpadAX = nil
            setScratchpadVisible(false)
            return
        }
        removeWindow(id)
    }

    func windowFocused(id: AXWindowID) {
        guard axWindows[id] != nil else { return }
        let wid = WindowID(id)
        // Follow native focus: when macOS activates an app (a URL clicked in
        // Teams opening the browser...), pull that window's workspace into
        // view instead of leaving the window parked on a hidden one.
        if config.general.followNativeFocus,
           let location = state.windowLocation[wid],
           state.monitors.indices.contains(location.monitorIndex),
           state.monitors[location.monitorIndex].activeWorkspace.name != location.workspaceName {
            run(.workspace(location.workspaceName))
        }
        execute(WM.focusChangedExternally(wid, state: &state))
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
        let bundleID = app?.bundleIdentifier ?? ""
        let node = WindowNode(
            id: WindowID(id),
            appBundleID: bundleID,
            pid: pid,
            title: ax.title,
            isFloating: config.general.floatApps.contains(bundleID),
            frame: frame
        )
        adopt(node, frame: frame)
    }

    func appTerminated(pid: pid_t) {
        if scratchpadAX?.pid == pid {
            scratchpadAX = nil
            setScratchpadVisible(false)
        }
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
        animator.cancel(id)
        execute(WM.windowRemoved(WindowID(id), state: &state))
    }

    private func enforceTiling(id: AXWindowID, newFrame: AXFrame) {
        guard let ax = axWindows[id], !tilingPaused else { return }
        // Mid-animation geometry events are our own setFrames, not the app's.
        guard !animator.animatingWindows.contains(id) else { return }
        // A drag in progress for this window: hyper drags are fully ours
        // (ignore the event); native drags keep tracking the cursor (move
        // updates drop zones, resize re-ratios live).
        if var drag = mouseDrag, drag.window.rawValue == id {
            guard drag.isNative else { return }
            if drag.button == .left {
                if let location = Self.mouseLocation() {
                    drag.lastLocation = location
                    if drag.lastActionLocation == nil || abs(location.x - drag.lastActionLocation!.x) >= 5 || abs(location.y - drag.lastActionLocation!.y) >= 5 {
                        drag.action = updateDropAction(for: drag, at: location)
                        drag.lastActionLocation = location
                    }
                    mouseDrag = drag
                }
            } else {
                instantPlacement = true
                execute(WM.windowResizedByUser(drag.window, to: newFrame.cgRect, state: &state))
                instantPlacement = false
            }
            return
        }
        if parkedWindows.contains(id) {
            guard !parkingBounds.isEmpty,
                  !OffscreenParking.isParked(newFrame, bounds: parkingBounds) else { return }
            // macOS rescued the parked window onto a display (typically after
            // monitor unplug) — send it back, with the same give-up limit as
            // snap-back so a window macOS insists on rescuing doesn't loop.
            let attempts = (snapBackAttempts[id] ?? 0) + 1
            guard attempts <= snapBackLimit else {
                NSLog("ancre: window %u keeps escaping parking, leaving it visible", id)
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
        // Native mouse manipulation of a tiled window (no hyper): route it
        // into the same drag system as hyper+drag — a size change is a live
        // layout resize, a pure move gets drop zones + preview. Ends on the
        // observed mouse-up from the event tap.
        if CGEventSource.buttonState(.combinedSessionState, button: .left) {
            let isResize = abs(expected.size.width - newFrame.size.width) > 2
                || abs(expected.size.height - newFrame.size.height) > 2
            let location = Self.mouseLocation() ?? CGPoint(x: newFrame.origin.x, y: newFrame.origin.y)
            var drag = MouseDragState(
                window: WindowID(id),
                button: isResize ? .right : .left,
                wasTiled: true,
                isNative: true,
                lastLocation: location,
                action: nil
            )
            if isResize {
                instantPlacement = true
                execute(WM.windowResizedByUser(drag.window, to: newFrame.cgRect, state: &state))
                instantPlacement = false
            } else {
                drag.action = updateDropAction(for: drag, at: location)
                drag.lastActionLocation = location
            }
            mouseDrag = drag
            return
        }
        let attempts = (snapBackAttempts[id] ?? 0) + 1
        if attempts > snapBackLimit {
            // App insists on its own frame — float it so the layout reflows
            // around it instead of leaving a mis-sized tile overlapping others.
            NSLog("ancre: window %u keeps resizing itself, floating it", id)
            expectedFrames.removeValue(forKey: id)
            snapBackAttempts.removeValue(forKey: id)
            execute(WM.floatWindow(WindowID(id), frame: newFrame.cgRect, state: &state))
            return
        }
        snapBackAttempts[id] = attempts
        ax.setFrame(expected)
    }
}
