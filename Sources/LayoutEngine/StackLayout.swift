// Monocle/stack layout: every window fills the whole usable area, stacked on
// top of each other — only the focused one is visible (focusing raises it).
// The cure for a crowded workspace on a small display.

import CoreGraphics
import WMCore

public struct StackLayout: Layout {
    private var order: [WindowID] = []

    public init() {}

    public var orderedWindows: [WindowID] { order }

    public func frames(container: CGRect, innerGap: Double, outerGap: Double) -> [WindowID: CGRect] {
        let usable = container.insetBy(dx: outerGap, dy: outerGap)
        return Dictionary(uniqueKeysWithValues: order.map { ($0, usable) })
    }

    public mutating func insert(_ window: WindowID, after: WindowID?, container: CGRect, innerGap: Double, outerGap: Double) {
        guard !order.contains(window) else { return }
        if let after, let idx = order.firstIndex(of: after) {
            order.insert(window, at: idx + 1)
        } else {
            order.append(window)
        }
    }

    public mutating func remove(_ window: WindowID) {
        order.removeAll { $0 == window }
    }

    /// All frames are identical, so directional moves just reorder the stack.
    @discardableResult
    public mutating func move(_ window: WindowID, direction: Direction, container: CGRect, innerGap: Double, outerGap: Double) -> Bool {
        guard let idx = order.firstIndex(of: window) else { return false }
        let target = (direction == .left || direction == .up) ? idx - 1 : idx + 1
        guard order.indices.contains(target) else { return false }
        order.swapAt(idx, target)
        return true
    }

    public mutating func resize(_ window: WindowID, dimension: WMCore.Dimension, delta: Double, container: CGRect, innerGap: Double, outerGap: Double) {
        // Monocle has nothing to resize.
    }

    public mutating func insert(_ window: WindowID, near target: WindowID, edge: WMCore.Direction, container: CGRect, innerGap: Double, outerGap: Double) {
        insert(window, after: target, container: container, innerGap: innerGap, outerGap: outerGap)
    }

    public mutating func swapPositions(_ a: WindowID, _ b: WindowID) {
        guard let ia = order.firstIndex(of: a), let ib = order.firstIndex(of: b) else { return }
        order.swapAt(ia, ib)
    }
}
