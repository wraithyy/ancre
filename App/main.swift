import AppKit
import ApplicationServices
import AXBridge
import Bar
import Config

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var controller: WindowManagerController?
    private var permissionPollTimer: Timer?
    private var onboarding: OnboardingWindow?
    private var pauseItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "◱"
        buildMenu()
        startWhenTrusted()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    /// Rebuilt after the controller starts so titles use the config language.
    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "ancre", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        if controller != nil {
            let pause = NSMenuItem(title: L10n.pauseTiling, action: #selector(togglePause), keyEquivalent: "p")
            pause.target = self
            menu.addItem(pause)
            pauseItem = pause

            let retile = NSMenuItem(title: L10n.retile, action: #selector(retile), keyEquivalent: "")
            retile.target = self
            menu.addItem(retile)

            menu.addItem(.separator())

            // Monitors with their stable ids — click copies the id for the
            // [workspaces] config section.
            let monitorsItem = NSMenuItem(title: L10n.monitors, action: nil, keyEquivalent: "")
            let monitorsMenu = NSMenu()
            for display in DisplayManager.current() {
                let item = NSMenuItem(title: "\(display.name) — \(display.id)", action: #selector(copyMonitorID(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = display.id
                monitorsMenu.addItem(item)
            }
            monitorsItem.submenu = monitorsMenu
            menu.addItem(monitorsItem)

            menu.addItem(.separator())

            let openConfig = NSMenuItem(title: L10n.openConfig, action: #selector(openConfig), keyEquivalent: "")
            openConfig.target = self
            menu.addItem(openConfig)

            let reload = NSMenuItem(title: L10n.reloadConfig, action: #selector(reloadConfig), keyEquivalent: "r")
            reload.target = self
            menu.addItem(reload)

            menu.addItem(.separator())
        }
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func togglePause() {
        controller?.toggleTilingPause()
    }

    @objc private func retile() {
        controller?.retile()
    }

    @objc private func copyMonitorID(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(id, forType: .string)
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(ConfigLoader.userConfigURL)
    }

    @objc private func reloadConfig() {
        controller?.reloadConfig()
    }

    /// Everything granted = start silently; anything missing = show the
    /// onboarding window and start only after the user hits Start there.
    private func startWhenTrusted() {
        // The onboarding renders before the controller sets the language.
        L10n.language = ConfigLoader.load().config.general.language
        let status = PermissionsModel.check()
        if status.accessibility && status.input {
            startWindowManager()
            return
        }
        NSLog("ancre: permissions missing, showing onboarding")
        onboarding = OnboardingWindow()
        onboarding?.show { [weak self] in
            self?.onboarding = nil
            self?.startWindowManager()
        }
    }

    private func startWindowManager() {
        let (config, warnings) = ConfigLoader.load()
        warnings.forEach { NSLog("ancre: %@", $0) }
        let controller = WindowManagerController(config: config)
        controller.onTilingPausedChanged = { [weak self] paused in
            self?.pauseItem?.state = paused ? .on : .off
            // Paused tiling is visible at a glance on the status item.
            self?.statusItem.button?.title = paused ? "◱✕" : "◱"
        }
        controller.start()
        self.controller = controller
        buildMenu() // full menu, localized per config
        NSLog("ancre: window manager started")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
