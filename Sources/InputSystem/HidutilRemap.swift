// Manages CapsLock -> F18 (or configurable) remap via `hidutil`, so a physical
// key can act as the "hyper" modifier without a kernel extension.

import Foundation
#if canImport(IOKit)
import IOKit.hid
#endif

/// HID usage codes (page 0x07, keyboard/keypad) for keys we care about.
enum HIDUsage {
    static let byName: [String: UInt64] = [
        "caps_lock": 0x700000039,
        "f13": 0x700000068, "f14": 0x700000069, "f15": 0x70000006A,
        "f16": 0x70000006B, "f17": 0x70000006C, "f18": 0x70000006D,
        "f19": 0x70000006E, "f20": 0x70000006F,
        "right_cmd": 0x7000000E7, "right_option": 0x7000000E6,
    ]

    static func code(for name: String) -> UInt64? { byName[name] }
}

final class HidutilRemap {
    private let srcUsage: UInt64
    private let dstUsage: UInt64
    private var deviceWatcher: HIDDeviceWatcher?

    init(srcName: String = "caps_lock", dstName: String = "f18") {
        srcUsage = HIDUsage.code(for: srcName) ?? HIDUsage.byName["caps_lock"]!
        dstUsage = HIDUsage.code(for: dstName) ?? HIDUsage.byName["f18"]!

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: nil
        ) { [weak self] _ in self?.reapply() }

        deviceWatcher = HIDDeviceWatcher { [weak self] in self?.reapply() }
    }

    func apply() {
        run(mapping: "[{\"HIDKeyboardModifierMappingSrc\":\(srcUsage),\"HIDKeyboardModifierMappingDst\":\(dstUsage)}]")
    }

    func revert() {
        run(mapping: "[]")
    }

    func reapply() {
        apply()
    }

    private func run(mapping: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", "{\"UserKeyMapping\":\(mapping)}"]

        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: data, encoding: .utf8) ?? "unknown error"
                NSLog("applland: hidutil remap failed (status \(process.terminationStatus)): \(message)")
            }
        } catch {
            NSLog("applland: failed to launch hidutil: \(error)")
        }
    }
}

/// Watches for keyboard devices being plugged in so the remap can be reapplied
/// (hidutil's mapping is not always retained across device attach events).
final class HIDDeviceWatcher {
    private var manager: IOHIDManager?
    private let onDeviceMatched: () -> Void
    private let queue = DispatchQueue(label: "applland.hiddevicewatcher")

    init(onDeviceMatched: @escaping () -> Void) {
        self.onDeviceMatched = onDeviceMatched
        start()
    }

    private func start() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, _ in
            guard let context else { return }
            let watcher = Unmanaged<HIDDeviceWatcher>.fromOpaque(context).takeUnretainedValue()
            watcher.onDeviceMatched()
        }, context)

        queue.async {
            IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            if result != kIOReturnSuccess {
                NSLog("applland: IOHIDManagerOpen failed: \(result)")
            }
            CFRunLoopRun()
        }

        self.manager = manager
    }
}

#if canImport(AppKit)
import AppKit
#endif
