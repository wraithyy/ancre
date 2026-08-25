// Multi-monitor logic (Milestone 2): which workspace lives on which display,
// and what happens when displays come and go.
//
// Still pure state — the AX layer hands in `MonitorInfo` values (see
// AXBridge/DisplayManager) and executes the returned effects.
//
// Model: workspaces are global and each one is *placed* on exactly one
// connected monitor. Placement is a deterministic function of (workspace
// names, config assignments, connected monitors), so unplugging and replugging
// the same display always reproduces the same arrangement — no imperative
// "migrate away / migrate back" bookkeeping that can drift out of sync.

import CoreGraphics
import Foundation

/// A connected display, as reported by the AX/AppKit layer.
///
/// `id` is hardware-derived (vendor/model/serial) and survives reboots and
/// port changes — unlike `CGDirectDisplayID`, which is reassigned per session.
/// `name` is the user-facing display name, accepted in config for readability.
public struct MonitorInfo: Equatable, Sendable {
    public let id: String
    public let name: String
    public let frame: CGRect
    public let visibleFrame: CGRect

    public init(id: String, name: String, frame: CGRect, visibleFrame: CGRect) {
        self.id = id
        self.name = name
        self.frame = frame
        self.visibleFrame = visibleFrame
    }

    /// Whether a config value (`[workspaces]` value) refers to this monitor:
    /// either the exact stable id, or the display name (case-insensitive,
    /// substring — "Studio" matches "Studio Display").
    public func matches(_ matcher: String) -> Bool {
        if matcher == id { return true }
        let needle = matcher.lowercased()
        guard !needle.isEmpty else { return false }
        return name.lowercased().contains(needle)
    }
}

public enum MonitorTarget: String, CaseIterable {
    case next, previous
}

public enum WorkspaceAssignment {
    /// Distributes `workspaceNames` over `monitors`, honoring explicit
    /// `assignments` (workspace name -> monitor matcher). Returns one name list
    /// per monitor, parallel to `monitors`.
    ///
    /// Unassigned workspaces are split into contiguous blocks across the
    /// monitors that no workspace claimed explicitly, so a two-display setup
    /// gets 1-5 / 6-9 rather than an interleaved mess.
    public static func plan(
        workspaceNames: [String],
        assignments: [String: String],
        monitors: [MonitorInfo]
    ) -> [[String]] {
        guard !monitors.isEmpty else { return [] }

        var names = canonicalOrder(workspaceNames)
        // Every monitor must own at least one workspace: `Monitor.activeWorkspace`
        // indexes into the array, so an empty monitor would trap.
        var candidate = 1
        while names.count < monitors.count {
            let name = "\(candidate)"
            candidate += 1
            if !names.contains(name) { names.append(name) }
        }
        names = canonicalOrder(names)

        var result = [[String]](repeating: [], count: monitors.count)
        var unassigned: [String] = []
        for name in names {
            if let matcher = assignments[name],
               let index = monitors.firstIndex(where: { $0.matches(matcher) }) {
                result[index].append(name)
            } else {
                unassigned.append(name)
            }
        }

        let hosts = result.indices.filter { result[$0].isEmpty }
        if hosts.isEmpty {
            result[0].append(contentsOf: unassigned)
        } else if !unassigned.isEmpty {
            for (i, name) in unassigned.enumerated() {
                let block = min(i * hosts.count / unassigned.count, hosts.count - 1)
                result[hosts[block]].append(name)
            }
        }

        // Config can assign every workspace to one display; rather than reject
        // it, borrow from the fullest monitor so no display is left empty.
        for index in result.indices where result[index].isEmpty {
            guard let donor = result.indices.max(by: { result[$0].count < result[$1].count }),
                  result[donor].count > 1 else { continue }
            result[index].append(result[donor].removeLast())
        }

        for index in result.indices { result[index] = canonicalOrder(result[index]) }
        return result
    }

    /// Numeric names numerically ("2" before "10"), everything else after them
    /// alphabetically. Placement must not depend on which monitor a workspace
    /// happened to live on before.
    static func canonicalOrder(_ names: [String]) -> [String] {
        names.sorted { lhs, rhs in
            switch (Int(lhs), Int(rhs)) {
            case let (l?, r?): return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            default: return lhs < rhs
            }
        }
    }
}

extension WM {
    /// Rebuilds `state.monitors` for the currently connected `infos`,
    /// preserving every workspace's contents, layout and per-monitor active
    /// selection. Returns the effects needed to re-place all managed windows.
    ///
    /// `workspaceNames` is the set that must always exist (the configured
    /// workspaces); it is unioned with whatever the state already has, so the
    /// first call on an empty state also seeds the workspaces.
    ///
    /// `makeWorkspace` supplies a fresh workspace — the concrete `Layout` lives
    /// in LayoutEngine, which WMCore must not depend on.
    public static func reconcileMonitors(
        _ infos: [MonitorInfo],
        workspaceNames: [String],
        makeWorkspace: (String) -> Workspace,
        state: inout WMState
    ) -> [Effect] {
        // Display sleep / lid close reports zero displays. Keeping the old
        // arrangement means windows return to their workspaces on wake.
        guard !infos.isEmpty else { return [] }

        var existing: [String: Workspace] = [:]
        var previousActive: [String: String] = [:]
        for monitor in state.monitors {
            if monitor.workspaces.indices.contains(monitor.activeWorkspaceIndex) {
                previousActive[monitor.id] = monitor.workspaces[monitor.activeWorkspaceIndex].name
            }
            for workspace in monitor.workspaces { existing[workspace.name] = workspace }
        }
        let focusedWorkspaceName = state.monitors.indices.contains(state.focusedMonitorIndex)
            ? previousActive[state.monitors[state.focusedMonitorIndex].id]
            : nil

        let plan = WorkspaceAssignment.plan(
            workspaceNames: Array(Set(existing.keys).union(workspaceNames)),
            assignments: state.workspaceAssignments,
            monitors: infos
        )

        state.monitors = infos.enumerated().map { index, info in
            let names = plan[index]
            let activeIndex = previousActive[info.id].flatMap { names.firstIndex(of: $0) } ?? 0
            return Monitor(
                id: info.id,
                frame: info.frame,
                visibleFrame: info.visibleFrame,
                workspaces: names.map { existing[$0] ?? makeWorkspace($0) },
                activeWorkspaceIndex: activeIndex
            )
        }

        state.focusedMonitorIndex = focusedWorkspaceName.flatMap { name in
            state.monitors.firstIndex { monitor in monitor.workspaces.contains { $0.name == name } }
        } ?? 0

        state.windowLocation = [:]
        for (monitorIndex, monitor) in state.monitors.enumerated() {
            for workspace in monitor.workspaces {
                for window in workspace.allWindows {
                    state.windowLocation[window] = WindowLocation(monitorIndex: monitorIndex, workspaceName: workspace.name)
                }
            }
        }

        var effects: [Effect] = []
        for monitor in state.monitors {
            for (index, workspace) in monitor.workspaces.enumerated() {
                if index == monitor.activeWorkspaceIndex {
                    effects.append(.showWorkspace(allFrames(for: workspace, monitor: monitor, state: state)))
                } else if !workspace.allWindows.isEmpty {
                    effects.append(.hideWorkspace(Array(workspace.allWindows)))
                }
            }
        }
        return effects
    }

    static func focusMonitor(_ target: MonitorTarget, state: inout WMState) -> [Effect] {
        let count = state.monitors.count
        guard count > 1 else { return [] }
        let step = target == .next ? 1 : count - 1
        state.focusedMonitorIndex = (state.focusedMonitorIndex + step) % count
        guard let focused = state.monitors[state.focusedMonitorIndex].activeWorkspace.focusedWindow else { return [] }
        return [.focusWindow(focused)]
    }
}
