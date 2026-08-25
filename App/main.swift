import AppKit
import ApplicationServices
import Config

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var controller: WindowManagerController?
    private var permissionPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "◱"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "applland", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        startWhenTrusted()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    /// Prompts for Accessibility, then polls until the user grants it —
    /// the system offers no notification for permission changes.
    private func startWhenTrusted() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            startWindowManager()
            return
        }
        NSLog("applland: waiting for Accessibility permission")
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self?.permissionPollTimer = nil
            self?.startWindowManager()
        }
    }

    private func startWindowManager() {
        let (config, warnings) = ConfigLoader.load()
        warnings.forEach { NSLog("applland: %@", $0) }
        let controller = WindowManagerController(config: config)
        controller.start()
        self.controller = controller
        NSLog("applland: window manager started")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
