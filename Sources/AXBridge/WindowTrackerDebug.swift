import Foundation

/// Manual test entry point — requires Accessibility permission granted to the
/// running process. `swift build` compiles this; run interactively to verify
/// tracking against real apps.
public enum WindowTrackerDebug {
    public static func dumpTree(_ tracker: WindowTracker) {
        let snapshot = tracker.debugSnapshot
        print("WindowTracker: \(snapshot.count) window(s)")
        for entry in snapshot.sorted(by: { $0.pid < $1.pid }) {
            print("  [pid \(entry.pid)] id=\(entry.id) \"\(entry.title)\" frame=\(entry.frame.cgRect)")
        }
    }
}
