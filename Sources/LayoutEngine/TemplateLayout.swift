// User-defined layouts from a config string. Grammar:
//   expr  := '*' | axis '(' ratio ',' expr ',' expr ')'
//   axis  := 'h' (children side by side) | 'v' (children stacked)
// e.g. "h(0.6, *, v(0.5, *, *))" = 60% master column, right side split in two.
// Windows fill the '*' slots in layout order; extra windows beyond the slot
// count stack into the last slot (alternating splits by aspect); unused slots
// collapse and give their space to the filled sibling.

import CoreGraphics
import WMCore

public struct TemplateLayout: Layout {
    indirect enum Node {
        case slot
        /// `horizontal` = children side by side.
        case split(horizontal: Bool, ratio: Double, first: Node, second: Node)

        var slotCount: Int {
            switch self {
            case .slot: return 1
            case .split(_, _, let first, let second): return first.slotCount + second.slotCount
            }
        }
    }

    private let template: Node
    private var order: [WindowID] = []

    public init?(spec: String) {
        var tokens = Substring(spec.filter { !$0.isWhitespace })
        guard let node = Self.parse(&tokens), tokens.isEmpty else { return nil }
        template = node
    }

    public var orderedWindows: [WindowID] { order }

    public func frames(container: CGRect, innerGap: Double, outerGap: Double) -> [WindowID: CGRect] {
        guard !order.isEmpty else { return [:] }
        var result: [WindowID: CGRect] = [:]
        Self.place(template, windows: order[...], in: container.insetBy(dx: outerGap, dy: outerGap), innerGap: innerGap, into: &result)
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
        let all = frames(container: container, innerGap: innerGap, outerGap: outerGap)
        guard let myFrame = all[window] else { return false }
        var others = all
        others.removeValue(forKey: window)
        guard let neighbor = nearestNeighbor(from: myFrame, direction: direction, candidates: others),
              let a = order.firstIndex(of: window), let b = order.firstIndex(of: neighbor) else { return false }
        order.swapAt(a, b)
        return true
    }

    public mutating func resize(_ window: WindowID, dimension: WMCore.Dimension, delta: Double, container: CGRect, innerGap: Double, outerGap: Double) {
        // ponytail: template ratios are fixed by the spec; make them mutable
        // when someone actually misses resizing here.
    }

    // MARK: - Placement

    private static func place(_ node: Node, windows: ArraySlice<WindowID>, in rect: CGRect, innerGap: Double, into result: inout [WindowID: CGRect]) {
        guard !windows.isEmpty else { return }
        switch node {
        case .slot:
            stack(windows, in: rect, innerGap: innerGap, into: &result)
        case .split(let horizontal, let ratio, let first, let second):
            let firstSlots = first.slotCount
            let totalSlots = firstSlots + second.slotCount
            // Fill slots in order; overflow beyond all slots belongs to the
            // last slot, which lives in the second branch.
            let firstCount = windows.count > totalSlots ? firstSlots : min(firstSlots, windows.count)
            let firstWindows = windows.prefix(firstCount)
            let secondWindows = windows.dropFirst(firstCount)
            if secondWindows.isEmpty {
                place(first, windows: firstWindows, in: rect, innerGap: innerGap, into: &result)
                return
            }
            if firstWindows.isEmpty {
                place(second, windows: secondWindows, in: rect, innerGap: innerGap, into: &result)
                return
            }
            let (firstRect, secondRect) = divide(rect, horizontal: horizontal, ratio: ratio, innerGap: innerGap)
            place(first, windows: firstWindows, in: firstRect, innerGap: innerGap, into: &result)
            place(second, windows: secondWindows, in: secondRect, innerGap: innerGap, into: &result)
        }
    }

    /// Overflow windows in one slot: recursive halving, axis by aspect.
    private static func stack(_ windows: ArraySlice<WindowID>, in rect: CGRect, innerGap: Double, into result: inout [WindowID: CGRect]) {
        guard let head = windows.first else { return }
        if windows.count == 1 {
            result[head] = rect
            return
        }
        let (headRect, restRect) = divide(rect, horizontal: rect.width >= rect.height, ratio: 0.5, innerGap: innerGap)
        result[head] = headRect
        stack(windows.dropFirst(), in: restRect, innerGap: innerGap, into: &result)
    }

    private static func divide(_ rect: CGRect, horizontal: Bool, ratio: Double, innerGap: Double) -> (CGRect, CGRect) {
        if horizontal {
            let total = rect.width - innerGap
            let firstWidth = total * ratio
            return (
                CGRect(x: rect.minX, y: rect.minY, width: firstWidth, height: rect.height),
                CGRect(x: rect.minX + firstWidth + innerGap, y: rect.minY, width: total - firstWidth, height: rect.height)
            )
        } else {
            let total = rect.height - innerGap
            let firstHeight = total * ratio
            return (
                CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: firstHeight),
                CGRect(x: rect.minX, y: rect.minY + firstHeight + innerGap, width: rect.width, height: total - firstHeight)
            )
        }
    }

    // MARK: - Parser

    private static func parse(_ s: inout Substring) -> Node? {
        if s.first == "*" {
            s.removeFirst()
            return .slot
        }
        guard let axis = s.first, axis == "h" || axis == "v" else { return nil }
        s.removeFirst()
        guard s.first == "(" else { return nil }
        s.removeFirst()
        guard let comma = s.firstIndex(of: ","), let ratio = Double(s[..<comma]), (0.05...0.95).contains(ratio) else { return nil }
        s = s[s.index(after: comma)...]
        guard let first = parse(&s), s.first == "," else { return nil }
        s.removeFirst()
        guard let second = parse(&s), s.first == ")" else { return nil }
        s.removeFirst()
        return .split(horizontal: axis == "h", ratio: ratio, first: first, second: second)
    }
}

/// Resolves a layout name to an instance: built-ins first, then the user's
/// `[custom-layouts]` templates.
public enum LayoutFactory {
    public static func make(_ name: String, customLayouts: [String: String] = [:]) -> (any Layout)? {
        switch name {
        case "dwindle": return DwindleLayout()
        case "scroll": return ScrollColumnsLayout()
        default: return customLayouts[name].flatMap { TemplateLayout(spec: $0) }
        }
    }
}
