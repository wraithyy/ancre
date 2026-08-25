import XCTest
import CoreGraphics
@testable import LayoutEngine
import WMCore

private let container = CGRect(x: 0, y: 0, width: 1000, height: 500)

final class ScrollColumnsLayoutTests: XCTestCase {
    private func makeLayout(_ count: Int) -> (ScrollColumnsLayout, [WindowID]) {
        var layout = ScrollColumnsLayout()
        let ids = (0..<count).map { WindowID(UInt32($0)) }
        for id in ids { layout.insert(id, after: layout.orderedWindows.last, container: container, innerGap: 0, outerGap: 0) }
        return (layout, ids)
    }

    func testColumnsShareTheMonitorEqually() {
        let (layout, ids) = makeLayout(4)
        let frames = layout.frames(container: container, innerGap: 0, outerGap: 0)
        for id in ids {
            XCTAssertEqual(frames[id]!.height, 500)
            XCTAssertEqual(frames[id]!.width, 250, accuracy: 0.5)
        }
        XCTAssertLessThan(frames[ids[0]]!.minX, frames[ids[1]]!.minX)
        XCTAssertLessThan(frames[ids[2]]!.minX, frames[ids[3]]!.minX)
    }

    func testAllColumnsAlwaysFitTheContainer() {
        let (layout, ids) = makeLayout(7)
        let frames = layout.frames(container: container, innerGap: 8, outerGap: 8)
        for id in ids {
            XCTAssertGreaterThanOrEqual(frames[id]!.minX, 8 - 0.5)
            XCTAssertLessThanOrEqual(frames[id]!.maxX, 1000 - 8 + 0.5, "no column may leave the monitor")
        }
    }

    func testMoveSwapsColumns() {
        var (layout, ids) = makeLayout(3)
        XCTAssertTrue(layout.move(ids[0], direction: .right, container: container, innerGap: 0, outerGap: 0))
        XCTAssertEqual(layout.orderedWindows, [ids[1], ids[0], ids[2]])
        XCTAssertFalse(layout.move(ids[2], direction: .down, container: container, innerGap: 0, outerGap: 0))
    }

    func testResizeTakesSpaceFromNeighbors() {
        var (layout, ids) = makeLayout(2)
        layout.resize(ids[0], dimension: .width, delta: 200, container: container, innerGap: 0, outerGap: 0)
        let frames = layout.frames(container: container, innerGap: 0, outerGap: 0)
        XCTAssertEqual(frames[ids[0]]!.width, 700, accuracy: 0.5)
        XCTAssertEqual(frames[ids[1]]!.width, 300, accuracy: 0.5, "neighbor gives up the space")
        XCTAssertEqual(frames[ids[0]]!.width + frames[ids[1]]!.width, 1000, accuracy: 0.5)
    }
}

final class TemplateLayoutTests: XCTestCase {
    func testInvalidSpecsRejected() {
        XCTAssertNil(TemplateLayout(spec: "x(0.5, *, *)"))
        XCTAssertNil(TemplateLayout(spec: "h(0.5, *)"))
        XCTAssertNil(TemplateLayout(spec: "h(1.5, *, *)"))
        XCTAssertNil(TemplateLayout(spec: ""))
        XCTAssertNotNil(TemplateLayout(spec: "h(0.6, *, v(0.5, *, *))"))
    }

    func testSlotsFillInOrderWithMasterRatio() {
        var layout = TemplateLayout(spec: "h(0.6, *, v(0.5, *, *))")!
        let ids = (0..<3).map { WindowID(UInt32($0)) }
        for id in ids { layout.insert(id, after: layout.orderedWindows.last, container: container, innerGap: 0, outerGap: 0) }
        let frames = layout.frames(container: container, innerGap: 0, outerGap: 0)
        XCTAssertEqual(frames[ids[0]]!.width, 600, accuracy: 1)   // master 60 %
        XCTAssertEqual(frames[ids[0]]!.height, 500, accuracy: 1)
        XCTAssertEqual(frames[ids[1]]!.height, 250, accuracy: 1)  // right column halves
        XCTAssertEqual(frames[ids[2]]!.height, 250, accuracy: 1)
    }

    func testSingleWindowTakesWholeContainer() {
        var layout = TemplateLayout(spec: "h(0.6, *, v(0.5, *, *))")!
        layout.insert(WindowID(1), after: nil, container: container, innerGap: 0, outerGap: 0)
        let frames = layout.frames(container: container, innerGap: 0, outerGap: 0)
        XCTAssertEqual(frames[WindowID(1)], container, "unused slots must collapse")
    }

    func testOverflowStacksIntoLastSlot() {
        var layout = TemplateLayout(spec: "h(0.5, *, *)")!
        let ids = (0..<4).map { WindowID(UInt32($0)) }
        for id in ids { layout.insert(id, after: layout.orderedWindows.last, container: container, innerGap: 0, outerGap: 0) }
        let frames = layout.frames(container: container, innerGap: 0, outerGap: 0)
        XCTAssertEqual(frames.count, 4)
        XCTAssertEqual(frames[ids[0]]!.width, 500, accuracy: 1, "first slot keeps one window")
        // Remaining three share the second slot — all inside the right half.
        for id in ids.dropFirst() {
            XCTAssertGreaterThanOrEqual(frames[id]!.minX, 500 - 1)
        }
    }
}

final class LayoutFactoryTests: XCTestCase {
    func testResolvesBuiltinsAndCustoms() {
        XCTAssertTrue(LayoutFactory.make("dwindle") is DwindleLayout)
        XCTAssertTrue(LayoutFactory.make("scroll") is ScrollColumnsLayout)
        XCTAssertTrue(LayoutFactory.make("master", customLayouts: ["master": "h(0.6, *, *)"]) is TemplateLayout)
        XCTAssertNil(LayoutFactory.make("nonsense"))
        XCTAssertNil(LayoutFactory.make("bad", customLayouts: ["bad": "h(?)"]))
    }
}
