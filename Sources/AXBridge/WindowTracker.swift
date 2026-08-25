import AppKit
import ApplicationServices
import Foundation

public struct AXAppInfo: Sendable {
    public let pid: pid_t
    public let bundleIdentifier: String?
    public let name: String?
}

/// All methods are called on AXRunLoopThread.shared.queue (the axQueue).
public protocol WindowTrackerDelegate: AnyObject {
    func windowDiscovered(_ window: AXWindow, app: AXAppInfo)
    func windowDestroyed(id: AXWindowID)
    func windowFocused(id: AXWindowID)
    func windowMoved(id: AXWindowID, newFrame: AXFrame)
    func windowResized(id: AXWindowID, newFrame: AXFrame)
    func windowMiniaturized(id: AXWindowID)
    func windowDeminiaturized(id: AXWindowID)
    func appTerminated(pid: pid_t)
}

/// Top-level entry point for AXBridge. Owns the app registry, the window
/// cache, and NSWorkspace launch/terminate subscriptions. All AX work is
/// marshaled onto AXRunLoopThread.shared.queue.
public final class WindowTracker {
    public weak var delegate: WindowTrackerDelegate?

    private var apps: [pid_t: AXApplication] = [:]
    private var windowCache: [AXWindowID: AXWindow] = [:]
    private var frameCache: [AXWindowID: AXFrame] = [:]
    private var windowOwner: [AXWindowID: pid_t] = [:]

    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?
    private var activateObserver: NSObjectProtocol?

    public init() {}

    public func start() {
        AXRunLoopThread.shared.async { [self] in
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                attach(pid: app.processIdentifier)
            }
        }

        let center = NSWorkspace.shared.notificationCenter
        launchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: nil
        ) { [weak self] note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            self?.axAsync { self?.attach(pid: pid) }
        }
        terminateObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: nil
        ) { [weak self] note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            self?.axAsync { self?.detach(pid: pid) }
        }
        activateObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: nil
        ) { [weak self] note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            self?.axAsync {
                guard let self else { return }
                self.apps[pid]?.startObserving()
                // kAXFocusedWindowChanged only fires for in-app focus moves;
                // switching apps must sync focus from the activated app here.
                if let focused = self.apps[pid]?.focusedWindow(), self.windowCache[focused.id] != nil {
                    self.delegate?.windowFocused(id: focused.id)
                }
            }
        }
    }

    public func stop() {
        let center = NSWorkspace.shared.notificationCenter
        [launchObserver, terminateObserver, activateObserver].forEach { obs in
            if let obs { center.removeObserver(obs) }
        }
        AXRunLoopThread.shared.async { [self] in
            for pid in apps.keys { detach(pid: pid) }
        }
    }

    private func axAsync(_ work: @escaping () -> Void) {
        AXRunLoopThread.shared.async(work)
    }

    /// Runs `work` on the axQueue. Consumers (the WM controller) keep their
    /// state on this queue too, so delegate callbacks and command handling
    /// never race.
    public func perform(_ work: @escaping () -> Void) {
        AXRunLoopThread.shared.async(work)
    }

    private func attach(pid: pid_t) {
        guard apps[pid] == nil else { return }
        // Manage only real (dock) apps. Background services like
        // CursorUIViewService own invisible standard-looking windows that
        // would otherwise get tiled and steal focus.
        guard NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular else { return }
        let app = AXApplication(pid: pid, tracker: self)
        apps[pid] = app
        app.startObserving()
        for window in app.currentWindows() where window.isTileable {
            registerDiscovered(window, pid: pid)
        }
    }

    private func detach(pid: pid_t) {
        guard let app = apps.removeValue(forKey: pid) else { return }
        app.stopObserving()
        let ids = windowOwner.filter { $0.value == pid }.map(\.key)
        for id in ids {
            windowCache.removeValue(forKey: id)
            frameCache.removeValue(forKey: id)
            windowOwner.removeValue(forKey: id)
        }
        delegate?.appTerminated(pid: pid)
    }

    private func registerDiscovered(_ window: AXWindow, pid: pid_t) {
        windowCache[window.id] = window
        frameCache[window.id] = window.frame
        windowOwner[window.id] = pid
        let runningApp = NSRunningApplication(processIdentifier: pid)
        let info = AXAppInfo(pid: pid, bundleIdentifier: runningApp?.bundleIdentifier, name: runningApp?.localizedName)
        delegate?.windowDiscovered(window, app: info)
    }

    // MARK: - AXApplication callbacks (invoked on axQueue)

    func handleWindowDiscovered(_ window: AXWindow, pid: pid_t) {
        guard windowCache[window.id] == nil else { return }
        registerDiscovered(window, pid: pid)
    }

    func handleWindowDestroyed(elementForID element: AXUIElement) {
        // A dying element may no longer resolve its CGWindowID — fall back to
        // finding the cached window whose element matches.
        // ponytail: linear scan, fine for tens of windows.
        guard let id = resolveWindowID(element)
            ?? windowCache.first(where: { CFEqual($0.value.element, element) })?.key
        else { return }
        guard windowCache.removeValue(forKey: id) != nil else { return }
        frameCache.removeValue(forKey: id)
        windowOwner.removeValue(forKey: id)
        delegate?.windowDestroyed(id: id)
    }

    func handleWindowFocused(element: AXUIElement) {
        guard let id = resolveWindowID(element) else { return }
        if windowCache[id] == nil {
            // Auto-heal: a window whose ID didn't resolve at creation (skipped
            // by discovery) gets registered on first focus instead of staying
            // invisible to the WM forever.
            var pid: pid_t = 0
            guard AXUIElementGetPid(element, &pid) == .success,
                  let window = AXWindow(element: element, pid: pid), window.isTileable else { return }
            registerDiscovered(window, pid: pid)
        }
        delegate?.windowFocused(id: id)
    }

    /// axQueue only. The frontmost app's focused standard window, registering
    /// it (and the app) if discovery missed them. For the adopt-window command.
    public func frontmostFocusedWindowID() -> AXWindowID? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        if apps[pid] == nil { attach(pid: pid) }
        guard let window = apps[pid]?.focusedWindow(), window.isTileable else { return nil }
        if windowCache[window.id] == nil { registerDiscovered(window, pid: pid) }
        return window.id
    }

    func handleWindowGeometryChanged(element: AXUIElement, moved: Bool) {
        guard let id = resolveWindowID(element), let window = windowCache[id] else { return }
        let newFrame = window.frame
        // Skip redundant delegate calls when nothing actually changed vs cache.
        guard frameCache[id] == nil || frameCache[id]!.diverges(from: newFrame, tolerance: 0.5) else { return }
        frameCache[id] = newFrame
        if moved {
            delegate?.windowMoved(id: id, newFrame: newFrame)
        } else {
            delegate?.windowResized(id: id, newFrame: newFrame)
        }
    }

    func handleWindowMiniaturized(element: AXUIElement, miniaturized: Bool) {
        guard let id = resolveWindowID(element), windowCache[id] != nil else { return }
        if miniaturized {
            delegate?.windowMiniaturized(id: id)
        } else {
            delegate?.windowDeminiaturized(id: id)
        }
    }

    // MARK: - Public queries (marshal onto axQueue)

    public func window(for id: AXWindowID, completion: @escaping (AXWindow?) -> Void) {
        AXRunLoopThread.shared.async { [self] in
            completion(windowCache[id])
        }
    }

    public func allWindows(completion: @escaping ([AXWindow]) -> Void) {
        AXRunLoopThread.shared.async { [self] in
            completion(Array(windowCache.values))
        }
    }

    // MARK: - Debug

    var debugSnapshot: [(id: AXWindowID, pid: pid_t, title: String, frame: AXFrame)] {
        AXRunLoopThread.shared.sync {
            windowCache.values.map { ($0.id, $0.pid, $0.title, frameCache[$0.id] ?? $0.frame) }
        }
    }
}
