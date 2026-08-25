// CGEventTap that watches for the hyper carrier key (F18 by default) and,
// while held, resolves other keydowns into binding identifiers like
// "hyper-shift-h" and hands them to a callback for dispatch.

import Foundation
import CoreGraphics
import Carbon.HIToolbox

final class EventTapManager {
    typealias Handler = (String) -> Bool

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hyperActive = false
    /// Fires on the tap thread when the carrier key goes down/up. Receivers
    /// must only dispatch async — anything heavier risks the tap timeout.
    var onHyperStateChange: ((Bool) -> Void)?

    private let hyperKeycode: Int64
    private let handler: Handler

    /// - Parameters:
    ///   - hyperKeycode: virtual keycode the hyper carrier key arrives as after
    ///     the hidutil remap (kVK_F18 = 79 by default).
    ///   - handler: called with a binding identifier ("hyper-shift-h"); return
    ///     true if handled, to swallow the event.
    init(hyperKeycode: Int64 = Int64(kVK_F18), handler: @escaping Handler) {
        self.hyperKeycode = hyperKeycode
        self.handler = handler
    }

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        ) else {
            NSLog("applland: failed to create event tap — check Accessibility/Input Monitoring permissions")
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        hyperActive = false
    }

    // Must stay trivial: resolve identifier + call handler, nothing blocking.
    // Handler implementations are expected to dispatch async themselves.
    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("applland: event tap disabled (\(type == .tapDisabledByTimeout ? "timeout" : "user input")), re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }

        let keycode = event.getIntegerValueField(.keyboardEventKeycode)

        if keycode == hyperKeycode {
            switch type {
            case .keyDown:
                if !hyperActive { onHyperStateChange?(true) }
                hyperActive = true
            case .keyUp:
                hyperActive = false
                onHyperStateChange?(false)
            default: break
            }
            return nil // always swallow the carrier key itself
        }

        guard hyperActive, type == .keyDown, let name = KeycodeTable.name(forKeycode: keycode) else {
            return Unmanaged.passRetained(event)
        }

        let identifier = bindingIdentifier(for: name, flags: event.flags)
        if handler(identifier) {
            return nil
        }
        return Unmanaged.passRetained(event)
    }

    private func bindingIdentifier(for keyName: String, flags: CGEventFlags) -> String {
        var parts = ["hyper"]
        if flags.contains(.maskShift) { parts.append("shift") }
        if flags.contains(.maskControl) { parts.append("ctrl") }
        if flags.contains(.maskAlternate) { parts.append("alt") }
        if flags.contains(.maskCommand) { parts.append("cmd") }
        parts.append(keyName)
        return parts.joined(separator: "-")
    }
}
