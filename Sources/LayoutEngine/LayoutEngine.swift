// LayoutEngine: concrete `Layout` implementations.
//
// `Layout` itself lives in WMCore (Workspace needs to store `any Layout`,
// and WMCore can't depend on this module) — this target only supplies
// conforming algorithms. Adding a new layout means adding a new type here
// that conforms to `Layout`; nothing else in the tree needs to change.

import Foundation
import CoreGraphics
import WMCore

/// Hyprland-style dwindle layout: a recursive binary split tree. Each new
/// window splits the leaf it's inserted after; the split axis is chosen
/// from that leaf's current aspect ratio (wider → side-by-side, taller →
/// stacked), matching Hyprland's dwindle behavior.
public struct DwindleLayout: Layout {
    private indirect enum Node {
        case leaf(WindowID)
        case split(axis: Axis, ratio: Double, first: Node, second: Node)
    }

    /// `.vertical` = split line runs vertically (children side by side).
    /// `.horizontal` = split line runs horizontally (children stacked).
    private enum Axis {
        case vertical
        case horizontal
    }

    private var root: Node?
    private var order: [WindowID] = []

    public init() {}

    public var orderedWindows: [WindowID] { order }

    public func frames(container: CGRect, innerGap: Double, outerGap: Double) -> [WindowID: CGRect] {
        guard let root else { return [:] }
        var result: [WindowID: CGRect] = [:]
        place(root, in: container.insetBy(dx: outerGap, dy: outerGap), innerGap: innerGap, into: &result)
        return result
    }

    public mutating func insert(_ window: WindowID, after: WindowID?, container: CGRect, innerGap: Double, outerGap: Double) {
        guard let root else {
            self.root = .leaf(window)
            order.append(window)
            return
        }
        guard let target = after ?? order.last else { return }
        let targetFrame = frames(container: container, innerGap: innerGap, outerGap: outerGap)[target]
            ?? container.insetBy(dx: outerGap, dy: outerGap)
        let axis: Axis = targetFrame.width >= targetFrame.height ? .vertical : .horizontal
        self.root = Self.replacing(target, in: root) { existing in
            .split(axis: axis, ratio: 0.5, first: .leaf(existing), second: .leaf(window))
        }
        order.append(window)
    }

    public mutating func remove(_ window: WindowID) {
        order.removeAll { $0 == window }
        guard let root else { return }
        if case .leaf(let id) = root, id == window {
            self.root = nil
            return
        }
        self.root = Self.removing(window, from: root)
    }

    public mutating func insert(_ window: WindowID, near target: WindowID, edge: WMCore.Direction, container: CGRect, innerGap: Double, outerGap: Double) {
        guard let root, order.contains(target), !order.contains(window) else {
            insert(window, after: target, container: container, innerGap: innerGap, outerGap: outerGap)
            return
        }
        let axis: Axis = (edge == .left || edge == .right) ? .vertical : .horizontal
        let newFirst = edge == .left || edge == .up
        self.root = Self.replacing(target, in: root) { existing in
            .split(
                axis: axis,
                ratio: 0.5,
                first: newFirst ? .leaf(window) : .leaf(existing),
                second: newFirst ? .leaf(existing) : .leaf(window)
            )
        }
        if let idx = order.firstIndex(of: target) {
            order.insert(window, at: newFirst ? idx : idx + 1)
        } else {
            order.append(window)
        }
    }

    public mutating func swapPositions(_ a: WindowID, _ b: WindowID) {
        guard let root, let ia = order.firstIndex(of: a), let ib = order.firstIndex(of: b) else { return }
        self.root = Self.swapping(a, b, in: root)
        order.swapAt(ia, ib)
    }

    @discardableResult
    public mutating func move(_ window: WindowID, direction: Direction, container: CGRect, innerGap: Double, outerGap: Double) -> Bool {
        guard let root else { return false }
        let all = frames(container: container, innerGap: innerGap, outerGap: outerGap)
        guard let myFrame = all[window] else { return false }
        var others = all
        others.removeValue(forKey: window)
        guard let neighbor = nearestNeighbor(from: myFrame, direction: direction, candidates: others) else { return false }
        self.root = Self.swapping(window, neighbor, in: root)
        // Keep `order` in sync with the tree — layout transplants (setLayout)
        // read it, and a stale order scrambles windows on layout switches.
        if let a = order.firstIndex(of: window), let b = order.firstIndex(of: neighbor) {
            order.swapAt(a, b)
        }
        return true
    }

    public mutating func resize(_ window: WindowID, dimension: WMCore.Dimension, delta: Double, container: CGRect, innerGap: Double, outerGap: Double) {
        guard let root else { return }
        let axis: Axis = dimension == .width ? .vertical : .horizontal
        let usable = container.insetBy(dx: outerGap, dy: outerGap)
        self.root = Self.resizing(window, axis: axis, delta: delta, node: root, rect: usable, innerGap: innerGap).0
    }

    // MARK: - Tree geometry

    private func place(_ node: Node, in rect: CGRect, innerGap: Double, into result: inout [WindowID: CGRect]) {
        switch node {
        case .leaf(let id):
            result[id] = rect
        case .split(let axis, let ratio, let first, let second):
            let (firstRect, secondRect) = Self.split(rect, axis: axis, ratio: ratio, innerGap: innerGap)
            place(first, in: firstRect, innerGap: innerGap, into: &result)
            place(second, in: secondRect, innerGap: innerGap, into: &result)
        }
    }

    private static func split(_ rect: CGRect, axis: Axis, ratio: Double, innerGap: Double) -> (CGRect, CGRect) {
        switch axis {
        case .vertical:
            let total = rect.width - innerGap
            let firstWidth = total * ratio
            let secondWidth = total - firstWidth
            let first = CGRect(x: rect.minX, y: rect.minY, width: firstWidth, height: rect.height)
            let second = CGRect(x: rect.minX + firstWidth + innerGap, y: rect.minY, width: secondWidth, height: rect.height)
            return (first, second)
        case .horizontal:
            let total = rect.height - innerGap
            let firstHeight = total * ratio
            let secondHeight = total - firstHeight
            let first = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: firstHeight)
            let second = CGRect(x: rect.minX, y: rect.minY + firstHeight + innerGap, width: rect.width, height: secondHeight)
            return (first, second)
        }
    }

    // MARK: - Tree surgery (value-type rebuilds)

    private static func replacing(_ target: WindowID, in node: Node, with build: (WindowID) -> Node) -> Node {
        switch node {
        case .leaf(let id):
            return id == target ? build(id) : node
        case .split(let axis, let ratio, let first, let second):
            return .split(axis: axis, ratio: ratio, first: replacing(target, in: first, with: build), second: replacing(target, in: second, with: build))
        }
    }

    private static func removing(_ target: WindowID, from node: Node) -> Node? {
        switch node {
        case .leaf(let id):
            return id == target ? nil : node
        case .split(let axis, let ratio, let first, let second):
            if case .leaf(let id) = first, id == target { return second }
            if case .leaf(let id) = second, id == target { return first }
            let newFirst = removing(target, from: first)
            let newSecond = removing(target, from: second)
            switch (newFirst, newSecond) {
            case (nil, nil): return nil
            case (nil, let s?): return s
            case (let f?, nil): return f
            case (let f?, let s?): return .split(axis: axis, ratio: ratio, first: f, second: s)
            }
        }
    }

    private static func swapping(_ a: WindowID, _ b: WindowID, in node: Node) -> Node {
        switch node {
        case .leaf(let id):
            if id == a { return .leaf(b) }
            if id == b { return .leaf(a) }
            return node
        case .split(let axis, let ratio, let first, let second):
            return .split(axis: axis, ratio: ratio, first: swapping(a, b, in: first), second: swapping(a, b, in: second))
        }
    }

    /// Walks to the leaf for `target`, then bumps the ratio of the nearest
    /// ancestor split whose axis matches `axis` by `delta` points.
    /// ponytail: approximates the ancestor's usable size from its own rect
    /// at layout time rather than re-deriving analytically; fine at the
    /// depths dwindle trees reach in practice, revisit if resize precision
    /// matters for deep trees.
    private static func resizing(_ target: WindowID, axis: Axis, delta: Double, node: Node, rect: CGRect, innerGap: Double) -> (Node, Bool) {
        switch node {
        case .leaf(let id):
            return (node, id == target)
        case .split(let splitAxis, let ratio, let first, let second):
            let (firstRect, secondRect) = split(rect, axis: splitAxis, ratio: ratio, innerGap: innerGap)

            let (newFirst, foundInFirst) = resizing(target, axis: axis, delta: delta, node: first, rect: firstRect, innerGap: innerGap)
            if foundInFirst {
                guard splitAxis == axis else {
                    return (.split(axis: splitAxis, ratio: ratio, first: newFirst, second: second), true)
                }
                let total = splitAxis == .vertical ? rect.width - innerGap : rect.height - innerGap
                let currentDim = splitAxis == .vertical ? firstRect.width : firstRect.height
                let newRatio = min(0.9, max(0.1, Double((currentDim + CGFloat(delta)) / total)))
                return (.split(axis: splitAxis, ratio: newRatio, first: newFirst, second: second), true)
            }

            let (newSecond, foundInSecond) = resizing(target, axis: axis, delta: delta, node: second, rect: secondRect, innerGap: innerGap)
            if foundInSecond {
                guard splitAxis == axis else {
                    return (.split(axis: splitAxis, ratio: ratio, first: first, second: newSecond), true)
                }
                let total = splitAxis == .vertical ? rect.width - innerGap : rect.height - innerGap
                let currentDim = splitAxis == .vertical ? secondRect.width : secondRect.height
                let newRatio = min(0.9, max(0.1, 1 - Double((currentDim + CGFloat(delta)) / total)))
                return (.split(axis: splitAxis, ratio: newRatio, first: first, second: newSecond), true)
            }

            return (node, false)
        }
    }
}
