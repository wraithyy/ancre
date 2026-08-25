import ApplicationServices
import Foundation

/// Notifications an AXApplication subscribes to for one running app.
private let observedNotifications: [String] = [
    kAXCreatedNotification,
    kAXUIElementDestroyedNotification,
    kAXFocusedWindowChangedNotification,
    kAXWindowMovedNotification,
    kAXWindowResizedNotification,
    kAXWindowMiniaturizedNotification,
    kAXWindowDeminiaturizedNotification,
]

/// Wraps one app's AXUIElement, its window list, and its AXObserver. Owned
/// and driven entirely from AXRunLoopThread.shared.queue.
final class AXApplication {
    let pid: pid_t
    let element: AXUIElement
    private var observer: AXObserver?
    private weak var tracker: WindowTracker?

    init(pid: pid_t, tracker: WindowTracker) {
        self.pid = pid
        self.element = AXUIElementCreateApplication(pid)
        self.tracker = tracker
    }

    /// Enumerates current windows via kAXWindowsAttribute.
    func currentWindows() -> [AXWindow] {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value)
        guard err == .success, let windows = value as? [AXUIElement] else { return [] }
        return windows.map { AXWindow(element: $0, pid: pid) }
    }

    /// Registers the AXObserver, retrying with short backoff since some apps
    /// aren't AX-ready immediately after launch (didLaunchApplicationNotification
    /// can fire before the app's AX server is up).
    func startObserving(retries: Int = 5, delay: TimeInterval = 0.2) {
        var newObserver: AXObserver?
        let err = AXObserverCreate(pid, { _, element, notification, refcon in
            guard let refcon else { return }
            let app = Unmanaged<AXApplication>.fromOpaque(refcon).takeUnretainedValue()
            let name = notification as String
            // Observer callbacks fire on the CFRunLoop thread; tracker state is
            // owned by the axQueue — hop over to avoid cross-thread mutation.
            AXRunLoopThread.shared.async { app.handle(notification: name, element: element) }
        }, &newObserver)

        guard err == .success, let obs = newObserver else {
            if retries > 0 {
                AXRunLoopThread.shared.queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.startObserving(retries: retries - 1, delay: delay * 2)
                }
            }
            return
        }

        observer = obs
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var anyFailed = false
        for name in observedNotifications {
            let addErr = AXObserverAddNotification(obs, element, name as CFString, refcon)
            if addErr != .success { anyFailed = true }
        }

        if let runLoop = AXRunLoopThread.shared.runLoop {
            CFRunLoopAddSource(runLoop, AXObserverGetRunLoopSource(obs), .defaultMode)
        }

        if anyFailed, retries > 0 {
            // App partially ready; retry to catch attributes that weren't available yet.
            AXRunLoopThread.shared.queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.startObserving(retries: retries - 1, delay: delay * 2)
            }
        }
    }

    func stopObserving() {
        guard let obs = observer else { return }
        if let runLoop = AXRunLoopThread.shared.runLoop {
            CFRunLoopRemoveSource(runLoop, AXObserverGetRunLoopSource(obs), .defaultMode)
        }
        for name in observedNotifications {
            AXObserverRemoveNotification(obs, element, name as CFString)
        }
        observer = nil
    }

    private func handle(notification: String, element: AXUIElement) {
        guard let tracker else { return }
        switch notification {
        case kAXCreatedNotification:
            // Filter to windows: role check before treating as a window creation.
            let window = AXWindow(element: element, pid: pid)
            guard window.isStandardWindow else { return }
            tracker.handleWindowDiscovered(window, pid: pid)
        case kAXUIElementDestroyedNotification:
            tracker.handleWindowDestroyed(elementForID: element)
        case kAXFocusedWindowChangedNotification:
            tracker.handleWindowFocused(element: element)
        case kAXWindowMovedNotification:
            tracker.handleWindowGeometryChanged(element: element, moved: true)
        case kAXWindowResizedNotification:
            tracker.handleWindowGeometryChanged(element: element, moved: false)
        case kAXWindowMiniaturizedNotification:
            tracker.handleWindowMiniaturized(element: element, miniaturized: true)
        case kAXWindowDeminiaturizedNotification:
            tracker.handleWindowMiniaturized(element: element, miniaturized: false)
        default:
            break
        }
    }

    deinit {
        stopObserving()
    }
}
