import XCTest
import CoreGraphics
@testable import WMCore
import LayoutEngine

final class CommandParsingTests: XCTestCase {
    // Every command string used in Sources/Config/default.toml's [keybindings].
    // Keep in sync with that file.
    static let configuredCommands: [String] = [
        "focus left", "focus down", "focus up", "focus right",
        "move left", "move down", "move up", "move right",
        "resize width -50", "resize width +50", "resize height +50", "resize height -50",
        "workspace 1", "workspace 2", "workspace 3", "workspace 4", "workspace 5",
        "workspace 6", "workspace 7", "workspace 8", "workspace 9",
        "move-to-workspace 1", "move-to-workspace 2", "move-to-workspace 3",
        "move-to-workspace 4", "move-to-workspace 5", "move-to-workspace 6",
        "move-to-workspace 7", "move-to-workspace 8", "move-to-workspace 9",
        "toggle-floating", "toggle-fullscreen", "adopt-window",
        "focus-monitor previous", "focus-monitor next",
    ]

    func testAllConfiguredCommandsParse() {
        for s in Self.configuredCommands {
            XCTAssertNotNil(Command.parse(s), "failed to parse: \(s)")
        }
    }

    func testUnknownCommandFailsToParse() {
        XCTAssertNil(Command.parse("frobnicate left"))
        XCTAssertNil(Command.parse(""))
        XCTAssertNil(Command.parse("resize width notanumber"))
    }

    func testParsedValues() {
        XCTAssertEqual(Command.parse("focus left"), .focus(.left))
        XCTAssertEqual(Command.parse("move-to-workspace 5"), .moveToWorkspace("5"))
        XCTAssertEqual(Command.parse("resize width -50"), .resize(.width, -50))
        XCTAssertEqual(Command.parse("toggle-floating"), .toggleFloating)
    }
}

/// Builds a single-monitor, single-workspace state with `count` windows
/// already laid out in a grid-producing dwindle tree, for focus-nav tests.
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

final class FocusNavigationTests: XCTestCase {
    // 4-window dwindle grid in a 1600x900 container (see DwindleLayoutFrameTests
    // for the exact frames): w0 fills the left column; w1 top-right; w2 and w3
    // split the bottom-right quadrant left/right. w0's center is nearest to
    // w2's center among windows to its right.
    func testFocusNavigatesToGeometricNeighbor() {
        var (state, ids) = makeState(windowCount: 4)
        let w0 = ids[0], w2 = ids[2]

        state.monitors[0].activeWorkspace.focusedWindow = w0
        let effects = WM.dispatch(.focus(.right), state: &state)
        XCTAssertEqual(effects, [.focusWindow(w2)])
        XCTAssertEqual(state.monitors[0].activeWorkspace.focusedWindow, w2)
    }

    func testFocusWithNoNeighborReturnsNoEffects() {
        var (state, ids) = makeState(windowCount: 1)
        state.monitors[0].activeWorkspace.focusedWindow = ids[0]
        let effects = WM.dispatch(.focus(.left), state: &state)
        XCTAssertEqual(effects, [])
    }
}

final class WorkspaceSwitchTests: XCTestCase {
    func testDispatchWorkspaceReturnsHideAndShowEffects() {
        var (state, ids) = makeState(windowCount: 2)
        // Add an empty second workspace to switch to.
        let emptyWorkspace = Workspace(name: "2", layout: DwindleLayout())
        state.monitors[0].workspaces.append(emptyWorkspace)

        let effects = WM.dispatch(.workspace("2"), state: &state)

        XCTAssertTrue(effects.contains { if case .hideWorkspace(let hidden) = $0 { return Set(hidden) == Set(ids) } else { return false } })
        XCTAssertTrue(effects.contains { if case .showWorkspace(let shown) = $0 { return shown.isEmpty } else { return false } })
        XCTAssertEqual(state.monitors[0].activeWorkspaceIndex, 1)
    }

    func testMoveToWorkspaceMovesTheWindow() {
        var (state, ids) = makeState(windowCount: 2)
        let target = Workspace(name: "2", layout: DwindleLayout())
        state.monitors[0].workspaces.append(target)
        state.monitors[0].activeWorkspace.focusedWindow = ids[0]

        _ = WM.dispatch(.moveToWorkspace("2"), state: &state)

        XCTAssertEqual(state.windowLocation[ids[0]]?.workspaceName, "2")
        XCTAssertFalse(state.monitors[0].workspaces[0].tiledWindows.contains(ids[0]))
        XCTAssertTrue(state.monitors[0].workspaces[1].tiledWindows.contains(ids[0]))
    }
}
