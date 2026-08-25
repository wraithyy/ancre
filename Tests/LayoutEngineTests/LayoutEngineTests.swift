import XCTest
import CoreGraphics
import WMCore
@testable import LayoutEngine

private let container = CGRect(x: 0, y: 0, width: 1600, height: 900)
private let innerGap: Double = 8
private let outerGap: Double = 8

private func insertN(_ n: Int) -> (DwindleLayout, [WindowID]) {
    var layout = DwindleLayout()
    var ids: [WindowID] = []
    for i in 0..<n {
        let id = WindowID(UInt32(i))
        layout.insert(id, after: ids.last, container: container, innerGap: innerGap, outerGap: outerGap)
        ids.append(id)
    }
    return (layout, ids)
}

final class DwindleLayoutFrameTests: XCTestCase {
    // Hyprland-style dwindle in a 1600x900 container with 8/8 gaps.
    // Each new window splits the previously-inserted (focused) leaf; axis
    // alternates because each split changes the leaf's aspect ratio.

    func testOneWindowFillsUsableArea() {
        let (layout, ids) = insertN(1)
        let frames = layout.frames(container: container, innerGap: innerGap, outerGap: outerGap)
        XCTAssertEqual(frames[ids[0]], CGRect(x: 8, y: 8, width: 1584, height: 884))
    }

    func testTwoWindowsSplitVerticallySideBySide() {
        let (layout, ids) = insertN(2)
        let frames = layout.frames(container: container, innerGap: innerGap, outerGap: outerGap)
        XCTAssertEqual(frames[ids[0]], CGRect(x: 8, y: 8, width: 788, height: 884))
        XCTAssertEqual(frames[ids[1]], CGRect(x: 804, y: 8, width: 788, height: 884))
    }

    func testThreeWindowsSplitThirdHorizontally() {
        let (layout, ids) = insertN(3)
        let frames = layout.frames(container: container, innerGap: innerGap, outerGap: outerGap)
        XCTAssertEqual(frames[ids[0]], CGRect(x: 8, y: 8, width: 788, height: 884))
        XCTAssertEqual(frames[ids[1]], CGRect(x: 804, y: 8, width: 788, height: 438))
        XCTAssertEqual(frames[ids[2]], CGRect(x: 804, y: 454, width: 788, height: 438))
    }

    func testFourWindowsSplitFourthVertically() {
        let (layout, ids) = insertN(4)
        let frames = layout.frames(container: container, innerGap: innerGap, outerGap: outerGap)
        XCTAssertEqual(frames[ids[0]], CGRect(x: 8, y: 8, width: 788, height: 884))
        XCTAssertEqual(frames[ids[1]], CGRect(x: 804, y: 8, width: 788, height: 438))
        XCTAssertEqual(frames[ids[2]], CGRect(x: 804, y: 454, width: 390, height: 438))
        XCTAssertEqual(frames[ids[3]], CGRect(x: 1202, y: 454, width: 390, height: 438))
    }

    func testFiveWindowsSplitFifthHorizontally() {
        let (layout, ids) = insertN(5)
        let frames = layout.frames(container: container, innerGap: innerGap, outerGap: outerGap)
        XCTAssertEqual(frames[ids[0]], CGRect(x: 8, y: 8, width: 788, height: 884))
        XCTAssertEqual(frames[ids[1]], CGRect(x: 804, y: 8, width: 788, height: 438))
        XCTAssertEqual(frames[ids[2]], CGRect(x: 804, y: 454, width: 390, height: 438))
        XCTAssertEqual(frames[ids[3]], CGRect(x: 1202, y: 454, width: 390, height: 215))
        XCTAssertEqual(frames[ids[4]], CGRect(x: 1202, y: 677, width: 390, height: 215))
    }
}

final class DwindleLayoutPropertyTests: XCTestCase {
    private func assertNoOverlapAndWithinBounds(_ frames: [WindowID: CGRect], file: StaticString = #filePath, line: UInt = #line) {
        let usable = container.insetBy(dx: outerGap, dy: outerGap)
        let all = Array(frames.values)
        for r in all {
            XCTAssertTrue(usable.contains(r) || usable.intersects(r), "frame \(r) escapes usable area", file: file, line: line)
        }
        for i in 0..<all.count {
            for j in (i + 1)..<all.count {
                let overlap = all[i].intersection(all[j])
                XCTAssertTrue(overlap.isNull || overlap.width <= 0 || overlap.height <= 0,
                              "frames \(all[i]) and \(all[j]) overlap", file: file, line: line)
            }
        }
    }

    func testInsertKeepsFramesNonOverlappingUpToSixWindows() {
        for n in 1...6 {
            let (layout, _) = insertN(n)
            let frames = layout.frames(container: container, innerGap: innerGap, outerGap: outerGap)
            XCTAssertEqual(frames.count, n)
            assertNoOverlapAndWithinBounds(frames)
        }
    }

    func testRemoveCollapsesSplitAndKeepsFramesValid() {
        var (layout, ids) = insertN(5)
        layout.remove(ids[2])
        let remaining = ids.filter { $0 != ids[2] }
        let frames = layout.frames(container: container, innerGap: innerGap, outerGap: outerGap)
        XCTAssertEqual(Set(frames.keys), Set(remaining))
        assertNoOverlapAndWithinBounds(frames)

        // Removing every window one by one must never leave stray/overlapping frames.
        for id in remaining {
            layout.remove(id)
            let f = layout.frames(container: container, innerGap: innerGap, outerGap: outerGap)
            assertNoOverlapAndWithinBounds(f)
        }
        XCTAssertTrue(layout.orderedWindows.isEmpty)
    }
}

final class DwindleLayoutMoveTests: XCTestCase {
    func testMoveSwapsWithGeometricNeighbor() {
        var (layout, ids) = insertN(2)
        let moved = layout.move(ids[0], direction: .right, container: container, innerGap: innerGap, outerGap: outerGap)
        XCTAssertTrue(moved)
        let frames = layout.frames(container: container, innerGap: innerGap, outerGap: outerGap)
        // ids[0] now occupies the right half, ids[1] the left half.
        XCTAssertEqual(frames[ids[0]], CGRect(x: 804, y: 8, width: 788, height: 884))
        XCTAssertEqual(frames[ids[1]], CGRect(x: 8, y: 8, width: 788, height: 884))
    }

    func testMoveWithNoNeighborReturnsFalse() {
        var (layout, ids) = insertN(1)
        let moved = layout.move(ids[0], direction: .left, container: container, innerGap: innerGap, outerGap: outerGap)
        XCTAssertFalse(moved)
    }
}
