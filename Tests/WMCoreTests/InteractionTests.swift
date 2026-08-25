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
