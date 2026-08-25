// Config — TOML schema + loader (Task 1.7).
//
// User config lives at ~/.config/applland/applland.toml; on first run the
// bundled default.toml is copied there. Invalid config falls back to the
// bundled defaults and reports human-readable warnings instead of crashing —
// a WM that dies on a config typo locks the user out of their keybindings.

import Foundation
import TOMLKit
import WMCore

public struct AppConfig: Codable {
    public struct General: Codable {
        public var gapsInner: Double
        public var gapsOuter: Double
        public var animations: Bool
        public var animationDurationMs: Int
        public var defaultLayout: String

        enum CodingKeys: String, CodingKey {
            case gapsInner = "gaps-inner"
            case gapsOuter = "gaps-outer"
            case animations
            case animationDurationMs = "animation-duration-ms"
            case defaultLayout = "default-layout"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // TOML `8` is an integer and TOMLKit won't coerce it to Double;
            // users naturally write gaps without a decimal point.
            gapsInner = try Self.lenientDouble(c, .gapsInner)
            gapsOuter = try Self.lenientDouble(c, .gapsOuter)
            animations = try c.decode(Bool.self, forKey: .animations)
            animationDurationMs = try c.decode(Int.self, forKey: .animationDurationMs)
            defaultLayout = try c.decode(String.self, forKey: .defaultLayout)
        }

        private static func lenientDouble(
            _ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
        ) throws -> Double {
            if let d = try? c.decode(Double.self, forKey: key) { return d }
            return Double(try c.decode(Int.self, forKey: key))
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
        /// Shift of the pill along the alignment edge (points).
        public var offsetX: Double
        /// Shift of the strip away from the screen edge (points).
        public var offsetY: Double
        /// Pill background "#RRGGBB"/"#RRGGBBAA"; nil = system material.
        public var backgroundColor: String?
        /// Accent (active workspace, rings) "#RRGGBB"; nil = system accent.
        public var accentColor: String?
        /// App icon size in the bar, points.
        public var iconSize: Double

        enum CodingKeys: String, CodingKey {
            case enabled, position, opacity, height, align
            case offsetX = "offset-x"
            case offsetY = "offset-y"
            case backgroundColor = "background-color"
            case accentColor = "accent-color"
            case iconSize = "icon-size"
        }

        // Newer keys are optional with defaults so configs copied before they
        // existed keep decoding instead of falling back to bundled defaults.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decode(Bool.self, forKey: .enabled)
            position = try c.decode(String.self, forKey: .position)
            opacity = try Self.lenientDouble(c, .opacity) ?? 0.35
            height = try Self.lenientDouble(c, .height) ?? 28
            align = try c.decodeIfPresent(String.self, forKey: .align) ?? "center"
            offsetX = try Self.lenientDouble(c, .offsetX) ?? 0
            offsetY = try Self.lenientDouble(c, .offsetY) ?? 0
            backgroundColor = try c.decodeIfPresent(String.self, forKey: .backgroundColor)
            accentColor = try c.decodeIfPresent(String.self, forKey: .accentColor)
            iconSize = try Self.lenientDouble(c, .iconSize) ?? 17
        }

        private static func lenientDouble(
            _ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
        ) throws -> Double? {
            if let d = try? c.decode(Double.self, forKey: key) { return d }
            if let i = try? c.decode(Int.self, forKey: key) { return Double(i) }
            return nil
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
            radius = (try? c.decode(Double.self, forKey: .radius)) ?? Double((try? c.decode(Int.self, forKey: .radius)) ?? 6)
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
    /// `[workspaces]`: workspace name -> monitor, identified by stable id or
    /// (case-insensitive substring of) the display name. Optional: absent means
    /// "spread workspaces across whatever is connected".
    public var workspaces: [String: String]?
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

    enum CodingKeys: String, CodingKey {
        case general, hyper, keybindings, bar, workspaces, theme, border
        case workspaceLabels = "workspace-labels"
        case appWorkspaces = "app-workspaces"
        case customLayouts = "custom-layouts"
    }
}

public enum ConfigLoader {
    public static var userConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/applland/applland.toml")
    }

    /// Loads user config, falling back to bundled defaults on any error.
    /// Returns the config plus warnings to surface in logs/UI.
    public static func load() -> (config: AppConfig, warnings: [String]) {
        var warnings: [String] = []

        let defaults: AppConfig
        do {
            defaults = try decode(try bundledDefaultTOML())
        } catch {
            fatalError("applland: bundled default.toml is invalid: \(error)")
        }

        copyDefaultIfMissing(warnings: &warnings)

        guard let userTOML = try? String(contentsOf: userConfigURL, encoding: .utf8) else {
            warnings.append("config: \(userConfigURL.path) unreadable, using defaults")
            return (defaults, warnings)
        }

        do {
            var config = try decode(userTOML)
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

    private static func bundledDefaultTOML() throws -> String {
        guard let url = Bundle.module.url(forResource: "default", withExtension: "toml") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func copyDefaultIfMissing(warnings: inout [String]) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: userConfigURL.path) else { return }
        do {
            try fm.createDirectory(at: userConfigURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard let bundled = Bundle.module.url(forResource: "default", withExtension: "toml") else { return }
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
        if LayoutKind(rawValue: config.general.defaultLayout) == nil {
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
            let empty = assignments.filter { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }.keys.sorted()
            if !empty.isEmpty {
                warnings.append("config: [workspaces] entries with an empty monitor are ignored: \(empty.joined(separator: ", "))")
                config.workspaces = assignments.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
            }
        }
        if !["top", "bottom"].contains(config.bar.position) {
            warnings.append("config: bar position must be \"top\" or \"bottom\", using \"\(defaults.bar.position)\"")
            config.bar.position = defaults.bar.position
        }
        return warnings
    }
}
