// Columns layout ("scroll" in config): every window is a full-height column,
// side by side in order, and the widths always rescale so ALL columns fit the
// monitor. No viewport, no offscreen columns. Resizing a column takes the
// space from the remaining columns proportionally.

import CoreGraphics
import WMCore

public struct ScrollColumnsLayout: Layout {
    private var order: [WindowID] = []
    /// Desired widths in points from resizes; missing = equal share. frames()
    /// rescales everything so the row always fits exactly.
    private var desiredWidths: [WindowID: Double] = [:]
    private let minColumnWidth: Double = 100

    public init() {}

    public var orderedWindows: [WindowID] { order }

    public func frames(container: CGRect, innerGap: Double, outerGap: Double) -> [WindowID: CGRect] {
        guard !order.isEmpty else { return [:] }
        let usable = container.insetBy(dx: outerGap, dy: outerGap)
        let available = usable.width - innerGap * Double(order.count - 1)
        let equalShare = available / Double(order.count)
        let desired = order.map { desiredWidths[$0] ?? equalShare }
        let scale = available / desired.reduce(0, +)

        var result: [WindowID: CGRect] = [:]
        var x = usable.minX
        for (idx, window) in order.enumerated() {
            let width = desired[idx] * scale
            result[window] = CGRect(x: x, y: usable.minY, width: width, height: usable.height)
            x += width + innerGap
        }
        return result
    }

    public mutating func insert(_ window: WindowID, after: WindowID?, container: CGRect, innerGap: Double, outerGap: Double) {
        if let after, let idx = order.firstIndex(of: after) {
            order.insert(window, at: idx + 1)
        } else {
            order.append(window)
        }
    }

    public mutating func remove(_ window: WindowID) {
        order.removeAll { $0 == window }
        desiredWidths.removeValue(forKey: window)
    }

    public mutating func insert(_ window: WindowID, near target: WindowID, edge: WMCore.Direction, container: CGRect, innerGap: Double, outerGap: Double) {
        guard let idx = order.firstIndex(of: target), !order.contains(window) else {
            insert(window, after: target, container: container, innerGap: innerGap, outerGap: outerGap)
            return
        }
        order.insert(window, at: edge == .left || edge == .up ? idx : idx + 1)
    }

    public mutating func swapPositions(_ a: WindowID, _ b: WindowID) {
        guard let ia = order.firstIndex(of: a), let ib = order.firstIndex(of: b) else { return }
        order.swapAt(ia, ib)
    }

    @discardableResult
    public mutating func move(_ window: WindowID, direction: Direction, container: CGRect, innerGap: Double, outerGap: Double) -> Bool {
        guard let idx = order.firstIndex(of: window) else { return false }
        let target: Int
        switch direction {
        case .left: target = idx - 1
        case .right: target = idx + 1
        case .up, .down: return false // single row
        }
        guard order.indices.contains(target) else { return false }
        order.swapAt(idx, target)
        return true
    }

    public mutating func resize(_ window: WindowID, dimension: WMCore.Dimension, delta: Double, container: CGRect, innerGap: Double, outerGap: Double) {
        guard dimension == .width, order.contains(window), order.count > 1 else { return } // columns are full-height
        let current = frames(container: container, innerGap: innerGap, outerGap: outerGap)
        let usable = container.insetBy(dx: outerGap, dy: outerGap)
        let available = usable.width - innerGap * Double(order.count - 1)
        let currentWidth = current[window]?.width ?? 0
        let newWidth = min(max(minColumnWidth, currentWidth + delta), available - minColumnWidth * Double(order.count - 1))

        // Give/take the difference to the other columns proportionally, and
        // store everything as absolute desired widths (summing to available).
        let othersTotal = available - currentWidth
        let newOthersTotal = available - newWidth
        for other in order where other != window {
            let otherWidth = current[other]?.width ?? 0
            desiredWidths[other] = othersTotal > 0 ? otherWidth / othersTotal * newOthersTotal : newOthersTotal / Double(order.count - 1)
        }
        desiredWidths[window] = newWidth
    }
}
