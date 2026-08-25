// UI strings for the bar and overlays. English is the built-in default;
// [general].language picks a table (adding a language = adding a dictionary).
// Config-driven on purpose — the WM's language follows the user's config,
// not the system locale, so no .strings/Bundle machinery.

import Foundation

public enum L10n {
    /// Set once at startup from config, before any UI is built.
    public static var language = "en"

    public static func switchToWorkspace(_ name: String) -> String {
        String(format: t("switch_to_workspace"), name)
    }
    public static var moveFocusedHere: String { t("move_focused_here") }
    public static var focusWindow: String { t("focus_window") }
    public static var moveTo: String { t("move_to") }
    public static var floatWindow: String { t("float_window") }
    public static var tileWindow: String { t("tile_window") }
    public static var toggleFullscreen: String { t("toggle_fullscreen") }
    public static var pauseTiling: String { t("pause_tiling") }
    public static var retile: String { t("retile") }
    public static var monitors: String { t("monitors") }
    public static var openConfig: String { t("open_config") }
    public static var reloadConfig: String { t("reload_config") }
    public static func layoutMenu(_ current: String) -> String {
        String(format: t("layout_menu"), current)
    }
    public static func workspaceTooltip(name: String, displayName: String?, layout: String, windowCount: Int) -> String {
        let title = displayName.map { "\(name) · \($0)" } ?? name
        return String(format: t("workspace_tooltip"), title, layout, windowCount)
    }

    // MARK: - Tables

    private static func t(_ key: String) -> String {
        tables[language]?[key] ?? english[key] ?? key
    }

    private static let english: [String: String] = [
        "switch_to_workspace": "Switch to workspace %@",
        "move_focused_here": "Move focused window here",
        "focus_window": "Focus window",
        "move_to": "Move to",
        "layout_menu": "Layout: %@",
        "workspace_tooltip": "workspace %@ — layout: %@, windows: %d",
        "float_window": "Float window",
        "tile_window": "Return to tiling",
        "toggle_fullscreen": "Toggle fullscreen",
        "pause_tiling": "Pause tiling",
        "retile": "Retile windows",
        "monitors": "Monitors (click to copy id)",
        "open_config": "Open config",
        "reload_config": "Reload config",
    ]

    private static let tables: [String: [String: String]] = [
        "en": english,
        "cs": [
            "switch_to_workspace": "Přepnout na workspace %@",
            "move_focused_here": "Přesunout fokusované okno sem",
            "focus_window": "Fokusovat okno",
            "move_to": "Přesunout do",
            "layout_menu": "Layout: %@",
            "workspace_tooltip": "workspace %@ — layout: %@, oken: %d",
            "float_window": "Floatovat okno",
            "tile_window": "Vrátit do dlaždic",
            "toggle_fullscreen": "Přepnout fullscreen",
            "pause_tiling": "Pozastavit tiling",
            "retile": "Přeskládat okna",
            "monitors": "Monitory (klik zkopíruje id)",
            "open_config": "Otevřít config",
            "reload_config": "Znovu načíst config",
        ],
    ]
}
