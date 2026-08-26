import XCTest
import CoreGraphics
@testable import WMCore
import LayoutEngine

private let builtin = MonitorInfo(
    id: "1552:41038:4251086178",
    name: "Built-in Retina Display",
    frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
    visibleFrame: CGRect(x: 0, y: 33, width: 1512, height: 949)
)

private let external = MonitorInfo(
    id: "12462:25292:0",
    name: "P34w-20",
    frame: CGRect(x: 1512, y: -1000, width: 3440, height: 1440),
    visibleFrame: CGRect(x: 1512, y: -1000, width: 3440, height: 1440)
)

private let names = (1...9).map(String.init)

private func makeWorkspace(_ name: String) -> Workspace {
    Workspace(name: name, layout: DwindleLayout())
}

/// State with the given displays connected and workspaces 1-9 placed on them.
private func makeState(_ infos: [MonitorInfo], assignments: [String: [String]] = [:]) -> WMState {
    var state = WMState(monitors: [], workspaceAssignments: assignments)
    _ = WM.reconcileMonitors(infos, workspaceNames: names, makeWorkspace: makeWorkspace, state: &state)
    return state
}

private func addWindow(_ id: WindowID, toWorkspace name: String, state: inout WMState) {
    guard let (monitorIndex, _) = state.locate(workspace: name) else {
        XCTFail("workspace \(name) not placed on any monitor")
        return
    }
    let node = WindowNode(id: id, appBundleID: "test.app", pid: 1, title: "\(id)")
    _ = WM.windowAdded(node, toWorkspace: name, onMonitor: monitorIndex, state: &state)
}

final class WorkspaceAssignmentTests: XCTestCase {
    func testSingleMonitorGetsEveryWorkspace() {
        let plan = WorkspaceAssignment.plan(workspaceNames: names, assignments: [:], monitors: [builtin])
        XCTAssertEqual(plan, [names])
    }

    func testUnassignedWorkspacesSplitIntoContiguousBlocks() {
        let plan = WorkspaceAssignment.plan(workspaceNames: names, assignments: [:], monitors: [builtin, external])
        XCTAssertEqual(plan, [["1", "2", "3", "4", "5"], ["6", "7", "8", "9"]])
    }

    func testExplicitAssignmentByDisplayNameWins() {
        let plan = WorkspaceAssignment.plan(
            workspaceNames: names,
            assignments: ["1": ["P34w"], "2": ["12462:25292:0"]],
            monitors: [builtin, external]
        )
        XCTAssertEqual(plan, [["3", "4", "5", "6", "7", "8", "9"], ["1", "2"]])
    }

    func testEveryMonitorEndsUpWithAtLeastOneWorkspace() {
        // Config assigning all workspaces to one display must not leave the
        // other one empty — Monitor.activeWorkspace indexes into the array.
        let assignments = Dictionary(uniqueKeysWithValues: names.map { ($0, ["Built-in"]) })
        let plan = WorkspaceAssignment.plan(workspaceNames: names, assignments: assignments, monitors: [builtin, external])
        XCTAssertEqual(plan[0], ["1", "2", "3", "4", "5", "6", "7", "8"])
        XCTAssertEqual(plan[1], ["9"])
    }

    func testMoreMonitorsThanWorkspacesSynthesizesNames() {
        let plan = WorkspaceAssignment.plan(workspaceNames: ["1"], assignments: [:], monitors: [builtin, external])
        XCTAssertEqual(plan.map(\.count), [1, 1])
        XCTAssertEqual(Set(plan.flatMap { $0 }), ["1", "2"])
    }

    func testUnknownMonitorInConfigFallsBackToAutomaticPlacement() {
        let plan = WorkspaceAssignment.plan(workspaceNames: ["1", "2"], assignments: ["1": ["Nonexistent"]], monitors: [builtin])
        XCTAssertEqual(plan, [["1", "2"]])
    }
}

final class MonitorReconciliationTests: XCTestCase {
    func testReconcileSeedsWorkspacesOnFirstRun() {
        let state = makeState([builtin])
        XCTAssertEqual(state.monitors.count, 1)
        XCTAssertEqual(state.monitors[0].id, builtin.id)
        XCTAssertEqual(state.monitors[0].workspaces.map(\.name), names)
        XCTAssertEqual(state.monitors[0].visibleFrame, builtin.visibleFrame)
    }

    func testDisconnectMigratesWorkspacesAndWindowsToRemainingMonitor() {
        var state = makeState([builtin, external])
        let window = WindowID(1)
        addWindow(window, toWorkspace: "9", state: &state) // "9" lives on the external
        XCTAssertEqual(state.windowLocation[window]?.monitorIndex, 1)

        let effects = WM.reconcileMonitors([builtin], workspaceNames: names, makeWorkspace: makeWorkspace, state: &state)

        XCTAssertEqual(state.monitors.count, 1)
        XCTAssertEqual(state.monitors[0].workspaces.map(\.name), names)
        XCTAssertEqual(state.windowLocation[window], WindowLocation(monitorIndex: 0, workspaceName: "9"))
        XCTAssertTrue(state.monitors[0].workspaces.first { $0.name == "9" }!.tiledWindows.contains(window))
        // "9" is not the active workspace on the built-in display, so the window parks.
        XCTAssertTrue(effects.contains { if case .hideWorkspace(let ids) = $0 { return ids == [window] } else { return false } })
    }

    func testReplugReturnsWorkspacesToTheirDisplay() {
        var state = makeState([builtin, external])
        let window = WindowID(1)
        addWindow(window, toWorkspace: "9", state: &state)

        _ = WM.reconcileMonitors([builtin], workspaceNames: names, makeWorkspace: makeWorkspace, state: &state)
        _ = WM.reconcileMonitors([builtin, external], workspaceNames: names, makeWorkspace: makeWorkspace, state: &state)

        XCTAssertEqual(state.monitors.map(\.id), [builtin.id, external.id])
        XCTAssertEqual(state.monitors[1].workspaces.map(\.name), ["6", "7", "8", "9"])
        XCTAssertEqual(state.windowLocation[window], WindowLocation(monitorIndex: 1, workspaceName: "9"))
        XCTAssertTrue(state.monitors[1].workspaces.last!.tiledWindows.contains(window))
    }

    func testActiveWorkspacePerMonitorSurvivesReconfiguration() {
        var state = makeState([builtin, external])
        _ = WM.dispatch(.workspace("7"), state: &state) // active on the external
        _ = WM.dispatch(.workspace("3"), state: &state) // active on the built-in

        _ = WM.reconcileMonitors([builtin, external], workspaceNames: names, makeWorkspace: makeWorkspace, state: &state)

        XCTAssertEqual(state.monitors[0].activeWorkspace.name, "3")
        XCTAssertEqual(state.monitors[1].activeWorkspace.name, "7")
    }

    func testNoDisplaysKeepsStateUntouched() {
        var state = makeState([builtin, external])
        let effects = WM.reconcileMonitors([], workspaceNames: names, makeWorkspace: makeWorkspace, state: &state)
        XCTAssertEqual(effects, [])
        XCTAssertEqual(state.monitors.count, 2)
    }

    func testLayoutFramesFollowTheNewMonitorGeometry() {
        var state = makeState([builtin, external])
        let window = WindowID(1)
        addWindow(window, toWorkspace: "6", state: &state) // active workspace of the external

        _ = WM.reconcileMonitors([builtin], workspaceNames: names, makeWorkspace: makeWorkspace, state: &state)

        let monitor = state.monitors[0]
        let workspace = monitor.workspaces.first { $0.name == "6" }!
        let frame = WM.allFrames(for: workspace, monitor: monitor, state: state)[window]
        XCTAssertNotNil(frame)
        XCTAssertTrue(builtin.visibleFrame.contains(frame!), "window should be laid out inside the surviving display")
    }
}

final class MonitorFocusTests: XCTestCase {
    func testFocusMonitorWraps() {
        var state = makeState([builtin, external])
        _ = WM.dispatch(.focusMonitor(.next), state: &state)
        XCTAssertEqual(state.focusedMonitorIndex, 1)
        _ = WM.dispatch(.focusMonitor(.next), state: &state)
        XCTAssertEqual(state.focusedMonitorIndex, 0)
        _ = WM.dispatch(.focusMonitor(.previous), state: &state)
        XCTAssertEqual(state.focusedMonitorIndex, 1)
    }

    func testFocusMonitorIsNoOpWithASingleDisplay() {
        var state = makeState([builtin])
        XCTAssertEqual(WM.dispatch(.focusMonitor(.next), state: &state), [])
        XCTAssertEqual(state.focusedMonitorIndex, 0)
    }

    func testSwitchingToAWorkspaceOnAnotherDisplayFocusesThatDisplay() {
        var state = makeState([builtin, external])
        let window = WindowID(1)
        addWindow(window, toWorkspace: "6", state: &state) // external's active workspace

        let effects = WM.dispatch(.workspace("6"), state: &state)

        XCTAssertEqual(state.focusedMonitorIndex, 1)
        XCTAssertEqual(effects, [.focusWindow(window)])
    }

    func testMovingAWindowToAnotherDisplaysWorkspace() {
        var state = makeState([builtin, external])
        let window = WindowID(1)
        addWindow(window, toWorkspace: "1", state: &state) // built-in, active

        _ = WM.dispatch(.moveToWorkspace("6"), state: &state)

        XCTAssertEqual(state.windowLocation[window], WindowLocation(monitorIndex: 1, workspaceName: "6"))
        XCTAssertTrue(state.monitors[1].activeWorkspace.tiledWindows.contains(window))
    }

    func testMovingAWindowToAHiddenWorkspaceParksIt() {
        var state = makeState([builtin])
        let window = WindowID(1)
        addWindow(window, toWorkspace: "1", state: &state)

        let effects = WM.dispatch(.moveToWorkspace("4"), state: &state)

        XCTAssertTrue(effects.contains { if case .hideWorkspace(let ids) = $0 { return ids == [window] } else { return false } })
    }
}
