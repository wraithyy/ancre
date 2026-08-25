// Dock badge reader: the Dock's AX tree exposes each app tile's badge as
// AXStatusLabel (the red notification count). macOS has no public event for
// badge changes, so callers poll — keep the interval lazy.

import AppKit
import ApplicationServices

public enum DockBadges {
    /// Badges of running apps, keyed by pid. Call on the axQueue.
    public static func current() -> [pid_t: String] {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return [:] }
        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        var listRef: AnyObject?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &listRef) == .success,
              let lists = listRef as? [AXUIElement] else { return [:] }

        let running = NSWorkspace.shared.runningApplications
        var badges: [pid_t: String] = [:]
        for list in lists {
            var itemsRef: AnyObject?
            guard AXUIElementCopyAttributeValue(list, kAXChildrenAttribute as CFString, &itemsRef) == .success,
                  let items = itemsRef as? [AXUIElement] else { continue }
            for item in items {
                var labelRef: AnyObject?
                guard AXUIElementCopyAttributeValue(item, "AXStatusLabel" as CFString, &labelRef) == .success,
                      let label = labelRef as? String, !label.isEmpty else { continue }
                var urlRef: AnyObject?
                guard AXUIElementCopyAttributeValue(item, kAXURLAttribute as CFString, &urlRef) == .success,
                      let url = urlRef as? URL else { continue }
                if let app = running.first(where: { $0.bundleURL?.standardizedFileURL == url.standardizedFileURL }) {
                    badges[app.processIdentifier] = label
                }
            }
        }
        return badges
    }
}
