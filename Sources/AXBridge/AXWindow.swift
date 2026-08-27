import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

public typealias AXWindowID = UInt32

/// Resolves the private `_AXUIElementGetWindow` symbol via dlsym. This is the
/// well-known exception used by every AX-based window manager (yabai, Amethyst,
/// etc.) to get a stable CGWindowID for an AXUIElement — there is no public API
/// for this. Resolution fails when the symbol is unavailable — see
/// `resolveWindowID` for why there is no fallback.
private typealias AXUIElementGetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> AXError

private let axUIElementGetWindowImpl: AXUIElementGetWindowFn? = {
    guard let handle = dlopen(nil, RTLD_LAZY),
          let sym = dlsym(handle, "_AXUIElementGetWindow") else { return nil }
    return unsafeBitCast(sym, to: AXUIElementGetWindowFn.self)
}()

/// Nil when the ID can't be resolved (transient/dying element, or the private
/// symbol is missing). Callers must skip such windows — a hash fallback would
/// mix hash IDs with real CGWindowIDs for the same window and corrupt state.
func resolveWindowID(_ element: AXUIElement) -> AXWindowID? {
    guard let fn = axUIElementGetWindowImpl else { return nil }
    var windowID: UInt32 = 0
    guard fn(element, &windowID) == .success, windowID != 0 else { return nil }
    return windowID
}

public struct AXFrame: Equatable, Sendable {
    public var origin: CGPoint
    public var size: CGSize

    public init(origin: CGPoint, size: CGSize) {
        self.origin = origin
        self.size = size
    }

    public var cgRect: CGRect { CGRect(origin: origin, size: size) }

    /// Whether two frames diverge beyond a small tolerance (points can be
    /// non-integral after AX rounding).
    public func diverges(from other: AXFrame, tolerance: CGFloat = 1.0) -> Bool {
        abs(origin.x - other.origin.x) > tolerance ||
            abs(origin.y - other.origin.y) > tolerance ||
            abs(size.width - other.size.width) > tolerance ||
            abs(size.height - other.size.height) > tolerance
    }
}

/// Wraps a single window's AXUIElement. All methods must be called on the
/// AXBridge run loop thread's queue (enforced by callers marshaling in via
/// WindowTracker's public API).
public final class AXWindow {
    public let id: AXWindowID
    public let pid: pid_t
    let element: AXUIElement

    init?(element: AXUIElement, pid: pid_t) {
        guard let id = resolveWindowID(element) else { return nil }
        self.element = element
        self.pid = pid
        self.id = id
    }

    private func copyAttribute(_ attribute: String) -> AnyObject? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return err == .success ? value : nil
    }

    private func setAttribute(_ attribute: String, _ value: AnyObject) -> AXError {
        AXUIElementSetAttributeValue(element, attribute as CFString, value)
    }

    public var title: String {
        (copyAttribute(kAXTitleAttribute) as? String) ?? ""
    }

    public var role: String? {
        copyAttribute(kAXRoleAttribute) as? String
    }

    public var subrole: String? {
        copyAttribute(kAXSubroleAttribute) as? String
    }

    /// Only standard, top-level windows — skips sheets/popovers/etc.
    var isStandardWindow: Bool {
        role == kAXWindowRole && (subrole == nil || subrole == kAXStandardWindowSubrole)
    }

    /// A window the WM should manage: standard AND resizable. Notification
    /// toasts (Outlook, Teams) report a standard subrole but are fixed-size;
    /// tiling them leaves phantom slots when they vanish.
    var isTileable: Bool {
        guard isStandardWindow else { return false }
        var settable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable)
        return settable.boolValue
    }

    public var isMinimized: Bool {
        guard let value = copyAttribute(kAXMinimizedAttribute) else { return false }
        return (value as? Bool) ?? false
    }

    public var frame: AXFrame {
        var point = CGPoint.zero
        var size = CGSize.zero
        if let posValue = copyAttribute(kAXPositionAttribute) {
            _ = AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        }
        if let sizeValue = copyAttribute(kAXSizeAttribute) {
            _ = AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }
        return AXFrame(origin: point, size: size)
    }

    /// Sets position + size, re-reads the actual resulting frame, and retries
    /// once if the app didn't honor the request (common with apps enforcing
    /// min/max sizes or aspect ratios). Returns the actual frame after settling.
    @discardableResult
    public func setFrame(_ target: AXFrame) -> AXFrame {
        applyFrame(target)
        var actual = frame
        if actual.diverges(from: target) {
            applyFrame(target)
            actual = frame
        }
        return actual
    }

    private func applyFrame(_ target: AXFrame) {
        var point = target.origin
        var size = target.size
        if let posValue = AXValueCreate(.cgPoint, &point) {
            _ = setAttribute(kAXPositionAttribute, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            _ = setAttribute(kAXSizeAttribute, sizeValue)
        }
    }

    /// Focuses this window: kAXMain + kAXFocused on the element, and activates
    /// the owning app so the window actually comes to the front.
    public func setFocused() {
        _ = setAttribute(kAXFocusedAttribute, kCFBooleanTrue)
        _ = setAttribute("AXMain", kCFBooleanTrue)
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
