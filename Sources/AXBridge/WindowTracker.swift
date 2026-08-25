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
            self?.axAsync { self?.apps[pid]?.startObserving() }
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
        let app = AXApplication(pid: pid, tracker: self)
        apps[pid] = app
        app.startObserving()
        for window in app.currentWindows() where window.isStandardWindow {
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
        let id = resolveWindowID(element)
        guard windowCache.removeValue(forKey: id) != nil else { return }
        frameCache.removeValue(forKey: id)
        windowOwner.removeValue(forKey: id)
        delegate?.windowDestroyed(id: id)
    }

    func handleWindowFocused(element: AXUIElement) {
        let id = resolveWindowID(element)
        guard windowCache[id] != nil else { return }
        delegate?.windowFocused(id: id)
    }

    func handleWindowGeometryChanged(element: AXUIElement, moved: Bool) {
        let id = resolveWindowID(element)
        guard let window = windowCache[id] else { return }
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
        let id = resolveWindowID(element)
        guard windowCache[id] != nil else { return }
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
