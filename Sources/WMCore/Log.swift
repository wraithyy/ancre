import Foundation
import os

// NSLog funnels its payload through a "%s" format string, which unified logging
// treats as private data: every ancre message shows up as "<private>" in
// `log show`, so field problems can't be diagnosed after the fact. Log the
// already-formatted string explicitly as public instead.
private let ancreOSLog = OSLog(subsystem: "com.ancre.wm", category: "wm")

/// Drop-in NSLog replacement whose messages stay readable in `log show`.
public func ancreLog(_ format: String, _ args: CVarArg...) {
    let message = args.isEmpty ? format : String(format: format, arguments: args)
    os_log("%{public}s", log: ancreOSLog, type: .default, message)
}
