import ApplicationServices
import Foundation

/// Owns the single dedicated thread + CFRunLoop that all AXObserver callbacks
/// run on. AXObserver requires its run loop source to be attached to a
/// running CFRunLoop for notifications to fire.
final class AXRunLoopThread {
    static let shared = AXRunLoopThread()

    let queue: DispatchQueue
    private var thread: Thread!
    private let runLoopReady = DispatchSemaphore(value: 0)
    private(set) var runLoop: CFRunLoop!

    private init() {
        queue = DispatchQueue(label: "com.applland.axbridge.axQueue")
        thread = Thread { [weak self] in
            guard let self else { return }
            self.runLoop = CFRunLoopGetCurrent()
            self.runLoopReady.signal()
            // Keep the run loop alive indefinitely with a dummy source/timer;
            // CFRunLoopRun returns immediately if there's nothing scheduled yet.
            let timer = CFRunLoopTimerCreateWithHandler(nil, .greatestFiniteMagnitude, 0, 0, 0) { _ in }
            CFRunLoopAddTimer(self.runLoop, timer, .defaultMode)
            CFRunLoopRun()
        }
        thread.name = "com.applland.axbridge.runloop"
        thread.start()
        runLoopReady.wait()
    }

    /// Schedule work on the axQueue (all public AXBridge APIs marshal through here).
    func async(_ work: @escaping () -> Void) {
        queue.async(execute: work)
    }

    func sync<T>(_ work: () -> T) -> T {
        queue.sync(execute: work)
    }
}
