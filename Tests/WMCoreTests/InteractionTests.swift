import XCTest
import CoreGraphics
@testable import WMCore
import LayoutEngine

/// Same shape as WMCoreTests.makeState (file-private there): single monitor,
/// one workspace, `count` windows in a dwindle tree.
private func makeState(windowCount: Int, container: CGRect = CGRect(x: 0, y: 0, width: 1600, height: 900)) -> (WMState, [WindowID]) {
    var layout = DwindleLayout()
    var ids: [WindowID] = []
    for i in 0..<windowCount {
        let id = WindowID(UInt32(i))
        layout.insert(id, after: ids.last, container: container, innerGap: 8, outerGap: 8)
        ids.append(id)
    }
    var workspace = Workspace(name: "1", layout: layout)
    workspace.focusedWindow = ids.first
    let monitor = Monitor(id: "main", frame: container, visibleFrame: container, workspaces: [workspace])
    var state = WMState(monitors: [monitor])
    for id in ids {
        state.windows[id] = WindowNode(id: id, appBundleID: "test.app", pid: 1, title: "\(id)")
        state.windowLocation[id] = WindowLocation(monitorIndex: 0, workspaceName: "1")
    }
    return (state, ids)
}

private func frames(_ state: WMState) -> [WindowID: CGRect] {
    let monitor = state.monitors[0]
    return WM.allFrames(for: monitor.activeWorkspace, monitor: monitor, state: state)
}

final class NearestNeighborTests: XCTestCase {
    // 2x2 grid; from top-left, "down" must pick the window straight below,
    // not the nearer-by-euclid bottom-right diagonal.
    func testDownPrefersStraightBelowOverDiagonal() {
        let topLeft = CGRect(x: 0, y: 0, width: 100, height: 100)
        let candidates: [WindowID: CGRect] = [
            WindowID(1): CGRect(x: 0, y: 200, width: 100, height: 100),   // straight below
            WindowID(2): CGRect(x: 110, y: 110, width: 100, height: 100), // closer diagonal
        ]
        XCTAssertEqual(nearestNeighbor(from: topLeft, direction: .down, candidates: candidates), WindowID(1))
    }

    func testRightPrefersStraightOverDiagonal() {
        let topLeft = CGRect(x: 0, y: 0, width: 100, height: 100)
        let candidates: [WindowID: CGRect] = [
            WindowID(1): CGRect(x: 200, y: 0, width: 100, height: 100),
            WindowID(2): CGRect(x: 110, y: 110, width: 100, height: 100),
        ]
        XCTAssertEqual(nearestNeighbor(from: topLeft, direction: .right, candidates: candidates), WindowID(1))
    }
}

final class FloatWindowTests: XCTestCase {
    func testFloatRemovesFromLayoutAndReflows() {
        var (state, ids) = makeState(windowCount: 3)
        let floatFrame = CGRect(x: 10, y: 10, width: 500, height: 400)

        let effects = WM.floatWindow(ids[1], frame: floatFrame, state: &state)

        XCTAssertEqual(state.windows[ids[1]]?.isFloating, true)
        let workspace = state.monitors[0].activeWorkspace
        XCTAssertFalse(workspace.tiledWindows.contains(ids[1]))
        XCTAssertEqual(workspace.floatingFrames[ids[1]], floatFrame)
        XCTAssertFalse(effects.isEmpty, "active workspace must reflow")

        // Remaining two tiles partition the width again (side by side).
        let f = frames(state)
        XCTAssertEqual(f[ids[1]], floatFrame)
        let tiled = [f[ids[0]]!, f[ids[2]]!].sorted { $0.minX < $1.minX }
        XCTAssertLessThanOrEqual(tiled[0].maxX, tiled[1].minX, "tiles must not overlap")
    }

    func testFloatIsNoOpWhenAlreadyFloating() {
        var (state, ids) = makeState(windowCount: 2)
        _ = WM.floatWindow(ids[0], frame: .zero, state: &state)
        XCTAssertTrue(WM.floatWindow(ids[0], frame: .zero, state: &state).isEmpty)
    }
}

final class WindowResizedByUserTests: XCTestCase {
    func testResizeAdjustsSharedSplitWithoutOverlap() {
        var (state, ids) = makeState(windowCount: 2)
        let before = frames(state)
        var wanted = before[ids[0]]!
        wanted.size.width += 200

        _ = WM.windowResizedByUser(ids[0], to: wanted, state: &state)

        let after = frames(state)
        XCTAssertEqual(after[ids[0]]!.width, wanted.width, accuracy: 2)
        XCTAssertEqual(after[ids[1]]!.width, before[ids[1]]!.width - 200, accuracy: 2, "neighbor gives up the space")
        XCTAssertLessThanOrEqual(after[ids[0]]!.maxX, after[ids[1]]!.minX, "no overlap after resize")
    }

    func testResizeOfFloatingWindowJustRemembersFrame() {
        var (state, ids) = makeState(windowCount: 2)
        _ = WM.floatWindow(ids[0], frame: CGRect(x: 0, y: 0, width: 300, height: 300), state: &state)
        let moved = CGRect(x: 50, y: 60, width: 320, height: 330)

        let effects = WM.windowResizedByUser(ids[0], to: moved, state: &state)

        XCTAssertTrue(effects.isEmpty, "floating resize must not re-place tiles")
        XCTAssertEqual(state.monitors[0].activeWorkspace.floatingFrames[ids[0]], moved)
        XCTAssertEqual(state.windows[ids[0]]?.frame, moved)
    }

    func testResizeOfUnknownWindowIsNoOp() {
        var (state, _) = makeState(windowCount: 1)
        XCTAssertTrue(WM.windowResizedByUser(WindowID(99), to: .zero, state: &state).isEmpty)
    }
}

final class AutoFloatRetryTests: XCTestCase {
    private let bigMonitor = MonitorInfo(
        id: "main", name: "Main",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440),
        visibleFrame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    func testAutoFloatedWindowRetilesOnReconfiguration() {
        var (state, ids) = makeState(windowCount: 2)
        _ = WM.floatWindow(ids[0], frame: CGRect(x: 0, y: 0, width: 800, height: 600), state: &state)
        XCTAssertEqual(state.windows[ids[0]]?.isFloating, true)

        _ = WM.reconcileMonitors([bigMonitor], workspaceNames: ["1"], makeWorkspace: { Workspace(name: $0, layout: DwindleLayout()) }, state: &state)

        XCTAssertEqual(state.windows[ids[0]]?.isFloating, false, "auto-float must retry as a tile")
        XCTAssertTrue(state.monitors[0].workspaces[0].tiledWindows.contains(ids[0]))
    }

    func testUserFloatedWindowStaysFloatingOnReconfiguration() {
        var (state, ids) = makeState(windowCount: 2)
        state.monitors[0].workspaces[0].focusedWindow = ids[0]
        _ = WM.dispatch(.toggleFloating, state: &state)
        XCTAssertEqual(state.windows[ids[0]]?.isFloating, true)

        _ = WM.reconcileMonitors([bigMonitor], workspaceNames: ["1"], makeWorkspace: { Workspace(name: $0, layout: DwindleLayout()) }, state: &state)

        XCTAssertEqual(state.windows[ids[0]]?.isFloating, true, "user's explicit float must survive")
    }
}

final class SetFloatingTests: XCTestCase {
    // Regression: toggle-floating used the stale discovery frame (often
    // outside the monitor) — the float got parked and "disappeared".
    func testFloatKeepsCurrentLayoutFrame() {
        var (state, ids) = makeState(windowCount: 4)
        let tileFrame = WM.allFrames(for: state.monitors[0].activeWorkspace, monitor: state.monitors[0], state: state)[ids[2]]!

        _ = WM.setFloating(ids[2], floating: true, state: &state)

        let floatFrame = state.monitors[0].activeWorkspace.floatingFrames[ids[2]]
        XCTAssertEqual(floatFrame, tileFrame, "float must stay where the tile was")
        XCTAssertTrue(floatFrame!.intersects(state.monitors[0].frame), "must not end up off-monitor (parked)")
    }

    func testUnfloatReinsertsIntoLayout() {
        var (state, ids) = makeState(windowCount: 2)
        _ = WM.setFloating(ids[0], floating: true, state: &state)
        _ = WM.setFloating(ids[0], floating: false, state: &state)
        XCTAssertEqual(state.windows[ids[0]]?.isFloating, false)
        XCTAssertTrue(state.monitors[0].activeWorkspace.tiledWindows.contains(ids[0]))
        XCTAssertTrue(state.monitors[0].activeWorkspace.floatingFrames.isEmpty)
    }
}

final class LayoutSwitchOrderTests: XCTestCase {
    // Switching layouts must keep windows in their VISUAL (reading) order —
    // even after swaps desynced the layout's internal insertion order.
    func testSwitchPreservesGeometricOrderAfterSwaps() {
        var (state, ids) = makeState(windowCount: 3)
        state.monitors[0].workspaces[0].focusedWindow = ids[0]
        _ = WM.dispatch(.move(.right), state: &state) // swap 0 with its right neighbor

        let before = frames(state)
        let readingOrder = ids.sorted { a, b in
            let fa = before[a]!, fb = before[b]!
            return abs(fa.minX - fb.minX) > 1 ? fa.minX < fb.minX : fa.minY < fb.minY
        }

        _ = WM.setLayout(ScrollColumnsLayout(), workspaceNamed: "1", state: &state)

        XCTAssertEqual(state.monitors[0].activeWorkspace.tiledWindows, readingOrder,
                       "columns must line up in the pre-switch reading order")
    }

    func testDwindleMoveKeepsOrderInSync() {
        var (state, ids) = makeState(windowCount: 2)
        state.monitors[0].workspaces[0].focusedWindow = ids[0]
        _ = WM.dispatch(.move(.right), state: &state)
        XCTAssertEqual(state.monitors[0].activeWorkspace.tiledWindows, [ids[1], ids[0]],
                       "swap must be reflected in orderedWindows")
    }
}

final class MoveWindowTests: XCTestCase {
    // Bar drag&drop moves arbitrary windows, not just the focused one.
    func testMoveUnfocusedWindowToOtherWorkspaceKeepsSourceFocus() {
        var (state, ids) = makeState(windowCount: 3)
        state.monitors[0].workspaces.append(Workspace(name: "2", layout: DwindleLayout()))
        state.monitors[0].workspaces[0].focusedWindow = ids[0]

        let effects = WM.moveWindow(ids[2], toWorkspace: "2", state: &state)

        XCTAssertEqual(state.windowLocation[ids[2]], WindowLocation(monitorIndex: 0, workspaceName: "2"))
        XCTAssertFalse(state.monitors[0].workspaces[0].tiledWindows.contains(ids[2]))
        XCTAssertTrue(state.monitors[0].workspaces[1].tiledWindows.contains(ids[2]))
        XCTAssertEqual(state.monitors[0].workspaces[0].focusedWindow, ids[0], "focus in source must not change")
        // Target is hidden, so the moved window must be parked.
        XCTAssertTrue(effects.contains { if case .hideWorkspace(let wins) = $0 { return wins == [ids[2]] } else { return false } })
    }

    func testMoveToSameWorkspaceIsNoOp() {
        var (state, ids) = makeState(windowCount: 2)
        XCTAssertTrue(WM.moveWindow(ids[0], toWorkspace: "1", state: &state).isEmpty)
    }
}
