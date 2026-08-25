// Display enumeration + reconfiguration watching (Milestone 2).
//
// Identity: `CGDirectDisplayID` is reassigned per session, so it can't key a
// config file or survive a replug. The vendor/model/serial triple from
// CoreGraphics is hardware-derived and stable. Cheap external panels often
// report serial 0, so identical models get a positional suffix.
//
// Coordinates: `CGDisplayBounds` is already CG space (top-left origin, global),
// but only NSScreen knows the visible frame (minus menu bar and Dock), and that
// one is bottom-left. This file is the single conversion point.

import AppKit
import CoreGraphics
import Foundation

public struct DisplayInfo: Equatable, Sendable {
    public let id: String
    public let name: String
    /// Full display bounds in CG coordinates (top-left origin).
    public let frame: CGRect
    /// Bounds minus menu bar / Dock, in CG coordinates.
    public let visibleFrame: CGRect
    public let isBuiltin: Bool
}

/// Watches for displays being connected, disconnected or rearranged.
///
/// Uses `NSApplication.didChangeScreenParametersNotification` rather than
/// `CGDisplayRegisterReconfigurationCallback`: same coverage for our purposes
/// (AppKit posts it after the whole reconfiguration settles) with no C callback
/// and no begin/end flag filtering. Swap in the CG callback here if the
/// notification ever proves too coarse.
public final class DisplayManager {
    private var observer: NSObjectProtocol?
    private var coalesceGeneration = 0
    private let coalesceDelay: TimeInterval = 0.3

    public init() {}

    /// Starts watching. Must be called from the main thread (AppKit
    /// notification). `onChange` is delivered on the axQueue, like every other
    /// AXBridge callback, and fires once for the current display set.
    public func start(onChange: @escaping ([DisplayInfo]) -> Void) {
        deliver(onChange)
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // A single plug event produces a burst of notifications while
            // AppKit settles; only the last one matters.
            coalesceGeneration += 1
            let generation = coalesceGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + coalesceDelay) { [weak self] in
                guard let self, generation == coalesceGeneration else { return }
                deliver(onChange)
            }
        }
    }

    public func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    private func deliver(_ onChange: @escaping ([DisplayInfo]) -> Void) {
        let displays = Self.current()
        AXRunLoopThread.shared.async { onChange(displays) }
    }

    /// Connected displays, primary first (NSScreen order).
    public static func current() -> [DisplayInfo] {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var seen: [String: Int] = [:]

        return NSScreen.screens.compactMap { screen -> DisplayInfo? in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }

            var id = "\(CGDisplayVendorNumber(displayID)):\(CGDisplayModelNumber(displayID)):\(CGDisplaySerialNumber(displayID))"
            let duplicates = seen[id, default: 0]
            seen[id] = duplicates + 1
            // Two identical panels reporting serial 0 would collide; disambiguate
            // by position in the screen list. Reordering them swaps their
            // workspaces, which is the best a serial-less panel allows.
            if duplicates > 0 { id += "#\(duplicates)" }

            return DisplayInfo(
                id: id,
                name: screen.localizedName,
                frame: CGDisplayBounds(displayID),
                visibleFrame: cgRect(fromNSScreenRect: screen.visibleFrame, primaryHeight: primaryHeight),
                isBuiltin: CGDisplayIsBuiltin(displayID) != 0
            )
        }
    }

    /// NSScreen rects have a bottom-left origin relative to the primary screen;
    /// AX and CG positions use top-left.
    static func cgRect(fromNSScreenRect rect: NSRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Inverse of `cgRect(fromNSScreenRect:primaryHeight:)` — the flip is its
    /// own inverse. Public for overlay windows that must position themselves
    /// in NSScreen coordinates from AX/CG frames.
    public static func nsScreenRect(fromCGRect rect: CGRect, primaryHeight: CGFloat) -> NSRect {
        NSRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}
