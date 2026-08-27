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
    private var updateTimer: Timer?
    private var availableUpdate: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = AppDelegate.menubarIcon(paused: false)
        statusItem.button?.imagePosition = .imageLeft
        buildMenu()
        startWhenTrusted()
        if ConfigLoader.load().config.general.updateCheck {
            scheduleUpdateChecks()
        }
    }

    private func scheduleUpdateChecks() {
        let check = { [weak self] in
            UpdateChecker.check { version in
                NSLog("ancre: update %@ available", version)
                self?.availableUpdate = version
                self?.buildMenu()
            }
        }
        check()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { _ in check() }
    }

    @objc private func openReleasePage() {
        NSWorkspace.shared.open(UpdateChecker.releasesURL)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    /// Brand menubar mark drawn from the AncreMenuTemplate.svg geometry
    /// (22x22: two corner brackets + center diamond). Normal state is a
    /// template image so macOS tints it; paused swaps to a non-template
    /// variant whose diamond is brand danger red (brackets follow
    /// labelColor, resolved per appearance at draw time).
    static func menubarIcon(paused: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            let s = rect.width / 22.0
            func polygon(_ points: [(CGFloat, CGFloat)]) -> NSBezierPath {
                let path = NSBezierPath()
                path.move(to: NSPoint(x: points[0].0 * s, y: points[0].1 * s))
                for point in points.dropFirst() {
                    path.line(to: NSPoint(x: point.0 * s, y: point.1 * s))
                }
                path.close()
                return path
            }
            let brackets = [
                polygon([(4, 4), (11, 4), (11, 6), (6, 6), (6, 11), (4, 11)]),
                polygon([(18, 18), (11, 18), (11, 16), (16, 16), (16, 11), (18, 11)]),
            ]
            let diamond = polygon([(11, 7), (15, 11), (11, 15), (7, 11)])
            (paused ? NSColor.labelColor : .black).setFill()
            brackets.forEach { $0.fill() }
            (paused ? NSColor(red: 1.0, green: 0.384, blue: 0.384, alpha: 1.0) : .black).setFill()
            diamond.fill()
            return true
        }
        image.isTemplate = !paused
        return image
    }

    /// Rebuilt after the controller starts so titles use the config language.
    private func buildMenu() {
        let menu = NSMenu()
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).map { " \($0)" } ?? ""
        menu.addItem(NSMenuItem(title: "ancre\(version)", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        if let version = availableUpdate {
            let update = NSMenuItem(title: L10n.updateAvailable(version), action: #selector(openReleasePage), keyEquivalent: "")
            update.target = self
            menu.addItem(update)
            menu.addItem(.separator())
        }

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
        // `--onboarding` forces the window even with permissions granted
        // (testing, screenshots).
        let forced = CommandLine.arguments.contains("--onboarding")
        if !forced, status.accessibility && status.input {
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
            // Paused tiling is visible at a glance: the anchor diamond
            // in the menubar mark turns red.
            self?.statusItem.button?.image = AppDelegate.menubarIcon(paused: paused)
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
