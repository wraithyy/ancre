// Animator (Task 4.1): eases window frames to their targets instead of
// jumping. Every AX setFrame is measured; apps whose calls are slow (EMA over
// a threshold) automatically fall back to instant placement — animating a
// laggy AX connection just smears the motion. All methods run on the axQueue.

import AXBridge
import CoreGraphics
import Foundation

public final class Animator {
    public struct Settings {
        public var enabled: Bool
        public var duration: TimeInterval
        /// Bundle ids that always place instantly (config animations-exclude).
        public var excluded: Set<String>

        public init(enabled: Bool, duration: TimeInterval, excluded: Set<String> = []) {
            self.enabled = enabled
            self.duration = duration
            self.excluded = excluded
        }
    }

    private struct Animation {
        let window: AXWindow
        let bundleID: String
        let from: AXFrame
        let to: AXFrame
        let start: TimeInterval
        let completion: (AXFrame) -> Void
    }

    private let settings: Settings
    private var animations: [AXWindowID: Animation] = [:]
    private var timer: DispatchSourceTimer?
    /// EMA of setFrame latency per bundle id, seconds.
    private var latency: [String: Double] = [:]
    /// Above this a bundle animates as pure lag — place instantly instead.
    private let instantThreshold = 0.025
    private let tickInterval = 1.0 / 60.0

    public init(settings: Settings) {
        self.settings = settings
    }

    /// Windows currently mid-animation. The controller ignores geometry
    /// events for these (they are our own setFrames, not app self-resizes).
    public var animatingWindows: Set<AXWindowID> { Set(animations.keys) }

    /// Moves `window` to `target`, animated when the app is fast enough.
    /// `completion` gets the frame the app actually settled at; it runs
    /// synchronously on the instant path.
    public func setFrame(
        _ window: AXWindow,
        bundleID: String,
        to target: AXFrame,
        completion: @escaping (AXFrame) -> Void
    ) {
        let from = window.frame
        let farEnough = from.diverges(from: target, tolerance: 8)
        guard settings.enabled, farEnough, !settings.excluded.contains(bundleID),
              latency[bundleID, default: 0] <= instantThreshold else {
            animations.removeValue(forKey: window.id)
            completion(measuredSetFrame(window, bundleID: bundleID, target))
            return
        }
        animations[window.id] = Animation(
            window: window,
            bundleID: bundleID,
            from: from,
            to: target,
            start: ProcessInfo.processInfo.systemUptime,
            completion: completion
        )
        startTimerIfNeeded()
    }

    /// Drops the animation for `window` (window closed / re-targeted parking).
    public func cancel(_ id: AXWindowID) {
        animations.removeValue(forKey: id)
    }

    // MARK: - Ticking (axQueue)

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: AXQueue.shared)
        timer.schedule(deadline: .now() + tickInterval, repeating: tickInterval)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        for (id, animation) in animations {
            let progress = min(1, (now - animation.start) / settings.duration)
            let eased = 1 - pow(1 - progress, 3) // ease-out cubic
            if progress >= 1 {
                animations.removeValue(forKey: id)
                let actual = measuredSetFrame(animation.window, bundleID: animation.bundleID, animation.to)
                animation.completion(actual)
                continue
            }
            let frame = Self.lerp(animation.from, animation.to, eased)
            _ = measuredSetFrame(animation.window, bundleID: animation.bundleID, frame)
            // The app turned out slow mid-flight — finish instantly next tick.
            if latency[animation.bundleID, default: 0] > instantThreshold {
                animations[id] = Animation(
                    window: animation.window,
                    bundleID: animation.bundleID,
                    from: animation.to,
                    to: animation.to,
                    start: now - settings.duration,
                    completion: animation.completion
                )
            }
        }
        if animations.isEmpty {
            timer?.cancel()
            timer = nil
        }
    }

    private func measuredSetFrame(_ window: AXWindow, bundleID: String, _ target: AXFrame) -> AXFrame {
        let t0 = ProcessInfo.processInfo.systemUptime
        let actual = window.setFrame(target)
        let sample = ProcessInfo.processInfo.systemUptime - t0
        latency[bundleID] = 0.8 * latency[bundleID, default: sample] + 0.2 * sample
        return actual
    }

    private static func lerp(_ a: AXFrame, _ b: AXFrame, _ t: Double) -> AXFrame {
        AXFrame(
            origin: CGPoint(x: a.origin.x + (b.origin.x - a.origin.x) * t, y: a.origin.y + (b.origin.y - a.origin.y) * t),
            size: CGSize(width: a.size.width + (b.size.width - a.size.width) * t, height: a.size.height + (b.size.height - a.size.height) * t)
        )
    }
}
