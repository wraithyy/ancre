// Config — TOML schema + loader (Task 1.7).
//
// User config lives at ~/.config/ancre/ancre.toml; on first run the
// bundled default.toml is copied there. Invalid config falls back to the
// bundled defaults and reports human-readable warnings instead of crashing —
// a WM that dies on a config typo locks the user out of their keybindings.

import Foundation
import TOMLKit
import WMCore

/// TOML integers (`8`) don't coerce to Double in TOMLKit; users naturally
/// write sizes without a decimal point. nil = key absent/not a number.
private func lenientDouble<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
    if let d = try? c.decode(Double.self, forKey: key) { return d }
    if let i = try? c.decode(Int.self, forKey: key) { return Double(i) }
    return nil
}

public struct AppConfig: Codable {
    public struct General: Codable {
        public var gapsInner: Double
        public var gapsOuter: Double
        public var animations: Bool
        public var animationDurationMs: Int
        public var defaultLayout: String
        /// Bundle ids that always place instantly (apps that animate badly).
        public var animationsExclude: [String]
        /// UI language for bar menus/tooltips ("en", "cs"); default "en".
        public var language: String
        /// When macOS activates an app (URL opened in the browser...), switch
        /// to that window's workspace like stock macOS would show it.
        public var followNativeFocus: Bool
        /// Migration crowding: a workspace whose windows can't fit its new
        /// monitor temporarily switches to the stack layout (and back).
        public var autoStack: Bool
        /// Minimum sensible width per tiled window for the fit heuristic.
        public var autoStackMinWidth: Double
        /// Refused frames per workspace within one burst before the workspace
        /// is force-switched to stack (min-sizes the width heuristic missed).
        public var autoStackThrashLimit: Int
        /// Log manual window moves to Application Support/ancre/move-log.jsonl
        /// (input for agent-suggested [app-workspaces] rules).
        public var moveLog: Bool
        /// Bundle ids ancre never manages — windows stay wherever the app
        /// puts them (Xcode & friends that fight the tiler).
        public var ignoreApps: [String]
        /// Bundle ids whose new windows start floating instead of tiled
        /// (still on a workspace; hyper+v tiles them).
        public var floatApps: [String]
        /// Once-a-day anonymous check of GitHub Releases for a newer version;
        /// shows a menubar menu item, never installs anything.
        public var updateCheck: Bool

        enum CodingKeys: String, CodingKey {
            case gapsInner = "gaps-inner"
            case gapsOuter = "gaps-outer"
            case animations
            case animationDurationMs = "animation-duration-ms"
            case defaultLayout = "default-layout"
            case animationsExclude = "animations-exclude"
            case language
            case followNativeFocus = "follow-native-focus"
            case autoStack = "auto-stack"
            case autoStackMinWidth = "auto-stack-min-width"
            case autoStackThrashLimit = "auto-stack-thrash-limit"
            case moveLog = "move-log"
            case ignoreApps = "ignore-apps"
            case floatApps = "float-apps"
            case updateCheck = "update-check"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            gapsInner = lenientDouble(c, .gapsInner) ?? 8
            gapsOuter = lenientDouble(c, .gapsOuter) ?? 8
            animations = try c.decodeIfPresent(Bool.self, forKey: .animations) ?? true
            animationDurationMs = try c.decodeIfPresent(Int.self, forKey: .animationDurationMs) ?? 180
            defaultLayout = try c.decodeIfPresent(String.self, forKey: .defaultLayout) ?? "dwindle"
            animationsExclude = try c.decodeIfPresent([String].self, forKey: .animationsExclude) ?? []
            language = try c.decodeIfPresent(String.self, forKey: .language) ?? "en"
            followNativeFocus = try c.decodeIfPresent(Bool.self, forKey: .followNativeFocus) ?? true
            autoStack = try c.decodeIfPresent(Bool.self, forKey: .autoStack) ?? true
            autoStackMinWidth = lenientDouble(c, .autoStackMinWidth) ?? 300
            autoStackThrashLimit = try c.decodeIfPresent(Int.self, forKey: .autoStackThrashLimit) ?? 8
            moveLog = try c.decodeIfPresent(Bool.self, forKey: .moveLog) ?? true
            ignoreApps = try c.decodeIfPresent([String].self, forKey: .ignoreApps) ?? []
            floatApps = try c.decodeIfPresent([String].self, forKey: .floatApps) ?? []
            updateCheck = try c.decodeIfPresent(Bool.self, forKey: .updateCheck) ?? true
        }
    }

    public struct Hyper: Codable {
        public var key: String
    }

    public struct Bar: Codable {
        public var enabled: Bool
        public var position: String
        public var opacity: Double
        public var height: Double
        /// Horizontal placement of the pill: "center" | "left" | "right".
        public var align: String
        /// With position = "menubar" on a notched display, which side of the
        /// notch hosts the pill: "left" | "right".
        public var notchSide: String
        /// Shift of the pill along the alignment edge (points).
        public var offsetX: Double
        /// Shift of the strip away from the screen edge (points).
        public var offsetY: Double
        /// Pill background "#RRGGBB"/"#RRGGBBAA"; nil = system material.
        public var backgroundColor: String?
        /// Accent (active workspace, rings) "#RRGGBB"; nil = system accent.
        public var accentColor: String?
        /// Dashed ring marking floating windows; nil = white.
        public var floatColor: String?
        /// Notification badge background; nil = system red.
        public var badgeColor: String?
        /// App icon size in the bar, points.
        public var iconSize: Double
        /// Base font size (workspace number; label is 1pt smaller).
        public var fontSize: Double
        /// Font family name; nil = system font (numbers monospaced).
        public var fontFamily: String?
        /// Gap between workspace cells.
        public var spacing: Double
        /// Gap between elements inside a cell (number, label, icons).
        public var cellSpacing: Double
        public var cellRadius: Double
        public var cellPaddingX: Double
        public var cellPaddingY: Double
        public var pillPaddingX: Double
        public var pillPaddingY: Double
        /// Active-workspace highlight opacity (focused monitor).
        public var activeOpacity: Double
        /// Opacity of icons of unfocused windows.
        public var inactiveIconOpacity: Double
        /// Focus/float ring line width.
        public var ringWidth: Double
        /// Max app icons shown per workspace.
        public var maxIcons: Int
        /// Peek mode: the bar idles at idle-opacity (0 = hidden) and shows at
        /// full opacity while hyper is held.
        public var peek: Bool
        public var idleOpacity: Double

        enum CodingKeys: String, CodingKey {
            case enabled, position, opacity, height, align, spacing, peek
            case offsetX = "offset-x"
            case offsetY = "offset-y"
            case backgroundColor = "background-color"
            case accentColor = "accent-color"
            case floatColor = "float-color"
            case badgeColor = "badge-color"
            case iconSize = "icon-size"
            case fontSize = "font-size"
            case fontFamily = "font-family"
            case cellSpacing = "cell-spacing"
            case cellRadius = "cell-radius"
            case cellPaddingX = "cell-padding-x"
            case cellPaddingY = "cell-padding-y"
            case pillPaddingX = "pill-padding-x"
            case pillPaddingY = "pill-padding-y"
            case activeOpacity = "active-opacity"
            case inactiveIconOpacity = "inactive-icon-opacity"
            case ringWidth = "ring-width"
            case maxIcons = "max-icons"
            case notchSide = "notch-side"
            case idleOpacity = "idle-opacity"
        }

        // Newer keys are optional with defaults so configs copied before they
        // existed keep decoding instead of falling back to bundled defaults.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            position = try c.decodeIfPresent(String.self, forKey: .position) ?? "top"
            opacity = lenientDouble(c, .opacity) ?? 1.0
            height = lenientDouble(c, .height) ?? 28
            align = try c.decodeIfPresent(String.self, forKey: .align) ?? "center"
            notchSide = try c.decodeIfPresent(String.self, forKey: .notchSide) ?? "left"
            offsetX = lenientDouble(c, .offsetX) ?? 0
            offsetY = lenientDouble(c, .offsetY) ?? 0
            backgroundColor = try c.decodeIfPresent(String.self, forKey: .backgroundColor)
            accentColor = try c.decodeIfPresent(String.self, forKey: .accentColor)
            floatColor = try c.decodeIfPresent(String.self, forKey: .floatColor)
            badgeColor = try c.decodeIfPresent(String.self, forKey: .badgeColor)
            iconSize = lenientDouble(c, .iconSize) ?? 17
            fontSize = lenientDouble(c, .fontSize) ?? 13
            fontFamily = try c.decodeIfPresent(String.self, forKey: .fontFamily)
            spacing = lenientDouble(c, .spacing) ?? 6
            cellSpacing = lenientDouble(c, .cellSpacing) ?? 4
            cellRadius = lenientDouble(c, .cellRadius) ?? 6
            cellPaddingX = lenientDouble(c, .cellPaddingX) ?? 8
            cellPaddingY = lenientDouble(c, .cellPaddingY) ?? 3
            pillPaddingX = lenientDouble(c, .pillPaddingX) ?? 10
            pillPaddingY = lenientDouble(c, .pillPaddingY) ?? 3
            activeOpacity = lenientDouble(c, .activeOpacity) ?? 0.55
            inactiveIconOpacity = lenientDouble(c, .inactiveIconOpacity) ?? 0.75
            ringWidth = lenientDouble(c, .ringWidth) ?? 1.5
            maxIcons = try c.decodeIfPresent(Int.self, forKey: .maxIcons) ?? 6
            peek = try c.decodeIfPresent(Bool.self, forKey: .peek) ?? false
            idleOpacity = lenientDouble(c, .idleOpacity) ?? 0
        }
    }

    /// Partial [bar] override applied per monitor. Keys of [bar-overrides]:
    /// "notch" matches notched displays, anything else is a monitor matcher
    /// (stable id or name substring). A matcher-specific entry wins over
    /// "notch", which wins over the base [bar].
    public struct BarOverride: Codable {
        public var position: String?
        public var align: String?
        public var notchSide: String?
        public var offsetX: Double?
        public var offsetY: Double?
        public var height: Double?
        public var opacity: Double?
        public var iconSize: Double?
        public var fontSize: Double?
        public var peek: Bool?
        public var idleOpacity: Double?

        enum CodingKeys: String, CodingKey {
            case position, align, opacity, height, peek
            case notchSide = "notch-side"
            case offsetX = "offset-x"
            case offsetY = "offset-y"
            case iconSize = "icon-size"
            case fontSize = "font-size"
            case idleOpacity = "idle-opacity"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            position = try c.decodeIfPresent(String.self, forKey: .position)
            align = try c.decodeIfPresent(String.self, forKey: .align)
            notchSide = try c.decodeIfPresent(String.self, forKey: .notchSide)
            offsetX = lenientDouble(c, .offsetX)
            offsetY = lenientDouble(c, .offsetY)
            height = lenientDouble(c, .height)
            opacity = lenientDouble(c, .opacity)
            iconSize = lenientDouble(c, .iconSize)
            fontSize = lenientDouble(c, .fontSize)
            peek = try c.decodeIfPresent(Bool.self, forKey: .peek)
            idleOpacity = lenientDouble(c, .idleOpacity)
        }

        func applied(to bar: Bar) -> Bar {
            var result = bar
            if let position { result.position = position }
            if let align { result.align = align }
            if let notchSide { result.notchSide = notchSide }
            if let offsetX { result.offsetX = offsetX }
            if let offsetY { result.offsetY = offsetY }
            if let height { result.height = height }
            if let opacity { result.opacity = opacity }
            if let iconSize { result.iconSize = iconSize }
            if let fontSize { result.fontSize = fontSize }
            if let peek { result.peek = peek }
            if let idleOpacity { result.idleOpacity = idleOpacity }
            return result
        }
    }

    /// Shared colors every surface inherits unless it overrides them.
    /// Colors are "#RRGGBB" or "#RRGGBBAA" strings.
    public struct Theme: Codable {
        /// Highlights: active workspace, focus rings/border. nil = system accent.
        public var accent: String?
        /// Surface backgrounds (bar pill). nil = system material.
        public var background: String?
    }

    /// Focus border around the focused window.
    public struct Border: Codable {
        public var enabled: Bool
        /// nil = theme accent.
        public var color: String?
        public var width: Double
        public var radius: Double

        enum CodingKeys: String, CodingKey { case enabled, color, width, radius }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            color = try c.decodeIfPresent(String.self, forKey: .color)
            width = (try? c.decode(Double.self, forKey: .width)) ?? Double((try? c.decode(Int.self, forKey: .width)) ?? 2)
            // 10 ≈ the system window corner radius, so the border hugs frames.
            radius = (try? c.decode(Double.self, forKey: .radius)) ?? Double((try? c.decode(Int.self, forKey: .radius)) ?? 10)
        }
    }

    /// Scratchpad: a dropdown window (terminal, notes) toggled over any
    /// workspace with the `scratchpad` command.
    public struct Scratchpad: Codable {
        /// Bundle id of the scratchpad app; nil disables the feature.
        public var app: String?
        /// Size as fractions of the monitor's usable area.
        public var width: Double
        public var height: Double
        /// Shell command that opens a *new* window of the app; nil = launch a
        /// second instance via `open -n`. The scratchpad never hijacks a window
        /// you already work in — it owns its own.
        public var command: String?

        enum CodingKeys: String, CodingKey { case app, width, height, command }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            app = try c.decodeIfPresent(String.self, forKey: .app)
            command = try c.decodeIfPresent(String.self, forKey: .command)
            width = lenientDouble(c, .width) ?? 0.6
            height = lenientDouble(c, .height) ?? 0.5
        }
    }

    /// Drag&drop layout preview overlay.
    public struct Preview: Codable {
        /// nil = theme accent.
        public var color: String?
        /// Fill opacity of the dragged window's future slot.
        public var opacity: Double

        enum CodingKeys: String, CodingKey { case color, opacity }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            color = try c.decodeIfPresent(String.self, forKey: .color)
            opacity = (try? c.decode(Double.self, forKey: .opacity)) ?? 0.3
        }
    }

    /// Keybind cheatsheet overlay, shown while the hyper key is held.
    public struct Help: Codable {
        public var enabled: Bool
        /// How long hyper must be held before the overlay appears (ms).
        public var delayMs: Double
        public var opacity: Double

        enum CodingKeys: String, CodingKey {
            case enabled, opacity, columns
            case delayMs = "delay-ms"
            case fontSize = "font-size"
            case cornerRadius = "corner-radius"
        }

        public var fontSize: Double
        public var columns: Int
        public var cornerRadius: Double

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            delayMs = (try? c.decode(Double.self, forKey: .delayMs)) ?? Double((try? c.decode(Int.self, forKey: .delayMs)) ?? 2000)
            opacity = (try? c.decode(Double.self, forKey: .opacity)) ?? 0.85
            fontSize = (try? c.decode(Double.self, forKey: .fontSize)) ?? Double((try? c.decode(Int.self, forKey: .fontSize)) ?? 11)
            columns = try c.decodeIfPresent(Int.self, forKey: .columns) ?? 3
            cornerRadius = (try? c.decode(Double.self, forKey: .cornerRadius)) ?? Double((try? c.decode(Int.self, forKey: .cornerRadius)) ?? 12)
        }
    }

    /// User notifications ancre may show (auto-stack, auto-float, tap
    /// re-enabled, lost permissions, remap failure, config warnings).
    public struct Notifications: Codable {
        /// Master switch.
        public var enabled: Bool
        /// Categories to suppress; see `knownCategories`.
        public var disable: [String]

        public static let knownCategories: Set<String> = [
            "auto-stack", "auto-float", "tap-disabled", "ax-permission",
            "remap-failed", "config",
        ]

        enum CodingKeys: String, CodingKey { case enabled, disable }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
            disable = try c.decodeIfPresent([String].self, forKey: .disable) ?? []
        }
    }

    /// Per-workspace appearance in the bar. All fields optional: `name` is a
    /// custom label, `icon` a short string (emoji) shown before it,
    /// `show-number` toggles the workspace number (default on).
    public struct WorkspaceLabel: Codable {
        public var name: String?
        public var icon: String?
        public var showNumber: Bool
        /// Hide the workspace in the bar while it has no windows (the active
        /// workspace is always shown).
        public var hideWhenEmpty: Bool
        /// Layout name: "dwindle" | "scroll" | a [custom-layouts] key.
        /// nil = general.default-layout.
        public var layout: String?

        enum CodingKeys: String, CodingKey {
            case name, icon, layout
            case showNumber = "show-number"
            case hideWhenEmpty = "hide-when-empty"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            icon = try c.decodeIfPresent(String.self, forKey: .icon)
            showNumber = try c.decodeIfPresent(Bool.self, forKey: .showNumber) ?? true
            hideWhenEmpty = try c.decodeIfPresent(Bool.self, forKey: .hideWhenEmpty) ?? false
            layout = try c.decodeIfPresent(String.self, forKey: .layout)
        }
    }

    public var general: General
    public var hyper: Hyper
    public var keybindings: [String: String]
    public var bar: Bar
    /// One monitor matcher or a preference-ordered list: `"1" = "PHL"` or
    /// `"1" = ["PHL", "P34w"]` — the first connected one wins.
    public struct MonitorMatchers: Codable {
        public let values: [String]

        public init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let one = try? c.decode(String.self) {
                values = [one]
            } else {
                values = try c.decode([String].self)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            try c.encode(values)
        }
    }

    /// `[workspaces]`: workspace name -> monitor(s), identified by stable id
    /// or (case-insensitive substring of) the display name. Optional: absent
    /// means "spread workspaces across whatever is connected".
    public var workspaces: [String: MonitorMatchers]?
    /// `[workspace-labels]`: workspace name -> bar appearance.
    public var workspaceLabels: [String: WorkspaceLabel]?
    /// `[app-workspaces]`: bundle id -> workspace name new windows of that
    /// app are placed on.
    public var appWorkspaces: [String: String]?
    /// `[theme]`: shared colors; absent = system look.
    public var theme: Theme?
    /// `[border]`: focus border; absent = defaults (enabled, accent, 2pt).
    public var border: Border?
    /// `[custom-layouts]`: layout name -> template spec, e.g.
    /// "h(0.6, *, v(0.5, *, *))".
    public var customLayouts: [String: String]?
    /// `[help]`: hold-hyper keybind cheatsheet; absent = enabled, 2 s delay.
    public var help: Help?
    /// `[preview]`: drag&drop layout preview; absent = accent, 0.3 fill.
    public var preview: Preview?
    /// `[scratchpad]`: dropdown window app + size; absent = disabled.
    public var scratchpad: Scratchpad?
    /// `[bar-overrides]`: per-monitor partial [bar] overrides.
    public var barOverrides: [String: BarOverride]?
    /// `[notifications]`: master switch + per-category suppression; absent =
    /// everything on.
    public var notifications: Notifications?

    enum CodingKeys: String, CodingKey {
        case general, hyper, keybindings, bar, workspaces, theme, border, help, preview, scratchpad, notifications
        case barOverrides = "bar-overrides"
        case workspaceLabels = "workspace-labels"
        case appWorkspaces = "app-workspaces"
        case customLayouts = "custom-layouts"
    }
}

extension AppConfig {
    /// Effective [bar] config for one monitor: base, then the "notch" override
    /// (if the display has one), then the first matcher-specific override.
    public func bar(forMonitorID id: String, name: String, hasNotch: Bool) -> Bar {
        var result = bar
        guard let overrides = barOverrides else { return result }
        if hasNotch, let notch = overrides["notch"] {
            result = notch.applied(to: result)
        }
        for (key, override) in overrides.sorted(by: { $0.key < $1.key }) where key != "notch" {
            let needle = key.lowercased()
            if key == id || (!needle.isEmpty && name.lowercased().contains(needle)) {
                result = override.applied(to: result)
                break
            }
        }
        return result
    }
}

public enum ConfigLoader {
    public static var userConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ancre/ancre.toml")
    }

    /// Loads user config, falling back to bundled defaults on any error.
    /// Returns the config plus warnings to surface in logs/UI.
    public static func load() -> (config: AppConfig, warnings: [String]) {
        var warnings: [String] = []

        let defaults: AppConfig
        do {
            defaults = try decode(try bundledDefaultTOML())
        } catch {
            fatalError("ancre: bundled default.toml is invalid: \(error)")
        }

        copyDefaultIfMissing(warnings: &warnings)

        guard let userTOML = try? String(contentsOf: userConfigURL, encoding: .utf8) else {
            warnings.append("config: \(userConfigURL.path) unreadable, using defaults")
            return (defaults, warnings)
        }

        do {
            var config = try decode(userTOML)
            // Bundled keybindings are always active; the user config overrides
            // key by key (an empty string value unbinds a default).
            config.keybindings = defaults.keybindings.merging(config.keybindings) { _, user in user }
            warnings.append(contentsOf: validate(&config, defaults: defaults))
            return (config, warnings)
        } catch {
            warnings.append("config: parse error in \(userConfigURL.path): \(error) — using defaults")
            return (defaults, warnings)
        }
    }

    /// Resolves keybinding strings to Commands, dropping (and reporting)
    /// entries whose command string doesn't parse.
    public static func resolveBindings(_ config: AppConfig) -> (bindings: [String: Command], warnings: [String]) {
        var bindings: [String: Command] = [:]
        var warnings: [String] = []
        for (combo, commandString) in config.keybindings {
            if commandString.isEmpty { continue } // explicit unbind of a default
            if let command = Command.parse(commandString) {
                bindings[combo] = command
            } else {
                warnings.append("config: unknown command \"\(commandString)\" for binding \"\(combo)\" — ignored")
            }
        }
        return (bindings, warnings)
    }

    // MARK: - Internals

    private static func decode(_ toml: String) throws -> AppConfig {
        try TOMLDecoder().decode(AppConfig.self, from: toml)
    }

    /// `Bundle.module`'s generated accessor for executables looks next to
    /// `Bundle.main.bundleURL` (the .app root), not Contents/Resources where
    /// bundle.sh puts SPM resource bundles — a bundled ancre.app outside the
    /// repo crashed at launch. Check Resources first, fall back to the accessor.
    private static let resourceBundle: Bundle = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("ancre_Config.bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return Bundle.module
    }()

    private static func bundledDefaultTOML() throws -> String {
        guard let url = resourceBundle.url(forResource: "default", withExtension: "toml") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func copyDefaultIfMissing(warnings: inout [String]) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: userConfigURL.path) else { return }
        do {
            try fm.createDirectory(at: userConfigURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard let bundled = resourceBundle.url(forResource: "default", withExtension: "toml") else { return }
            try fm.copyItem(at: bundled, to: userConfigURL)
        } catch {
            warnings.append("config: could not create \(userConfigURL.path): \(error)")
        }
    }

    private static func validate(_ config: inout AppConfig, defaults: AppConfig) -> [String] {
        var warnings: [String] = []
        if config.general.gapsInner < 0 || config.general.gapsOuter < 0 {
            warnings.append("config: negative gaps clamped to 0")
            config.general.gapsInner = max(0, config.general.gapsInner)
            config.general.gapsOuter = max(0, config.general.gapsOuter)
        }
        let knownLayouts = Set(["dwindle", "scroll", "stack"]).union(config.customLayouts?.keys ?? [:].keys)
        if !knownLayouts.contains(config.general.defaultLayout) {
            warnings.append("config: unknown default-layout \"\(config.general.defaultLayout)\", using \"\(defaults.general.defaultLayout)\"")
            config.general.defaultLayout = defaults.general.defaultLayout
        }
        // Keep in sync with InputSystem's HIDUsage name table.
        let validHyperKeys: Set<String> = ["caps_lock", "f13", "f14", "f15", "f16", "f17", "f18", "f19", "f20", "right_cmd", "right_option"]
        if !validHyperKeys.contains(config.hyper.key) {
            warnings.append("config: unknown hyper key \"\(config.hyper.key)\", using \"\(defaults.hyper.key)\"")
            config.hyper.key = defaults.hyper.key
        }
        if let assignments = config.workspaces {
            let empty = assignments.filter { $0.value.values.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }.keys.sorted()
            if !empty.isEmpty {
                warnings.append("config: [workspaces] entries with an empty monitor are ignored: \(empty.joined(separator: ", "))")
                config.workspaces = assignments.filter { !$0.value.values.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
            }
        }
        if let unknown = config.notifications?.disable.filter({ !AppConfig.Notifications.knownCategories.contains($0) }), !unknown.isEmpty {
            warnings.append("config: unknown [notifications] disable categories ignored: \(unknown.joined(separator: ", ")) (known: \(AppConfig.Notifications.knownCategories.sorted().joined(separator: ", ")))")
        }
        let validPositions = ["top", "bottom", "left", "right", "menubar", "notch"]
        if !validPositions.contains(config.bar.position) {
            warnings.append("config: bar position must be one of \(validPositions.joined(separator: "/")), using \"\(defaults.bar.position)\"")
            config.bar.position = defaults.bar.position
        }
        return warnings
    }
}
