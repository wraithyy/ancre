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
    public static var switcherPlaceholder: String { t("switcher_placeholder") }
    public static var onboardingSubtitle: String { t("onboarding_subtitle") }
    public static var onboardingAccessibility: String { t("onboarding_accessibility") }
    public static var onboardingInputMonitoring: String { t("onboarding_input") }
    public static var onboardingRemapWarning: String { t("onboarding_remap") }
    public static var onboardingStart: String { t("onboarding_start") }
    public static var onboardingGrant: String { t("onboarding_grant") }
    public static var onboardingHowTo: String { t("onboarding_howto") }
    public static var onboardingAI: String { t("onboarding_ai") }
    public static var onboardingTips: [(String, String)] {
        [
            ("hyper + 1…9", t("tip_workspaces")),
            ("hyper + H J K L", t("tip_focus")),
            ("hyper + ⇧ + H J K L", t("tip_move")),
            ("hyper + mezerník", t("tip_switcher")),
            (t("tip_drag_key"), t("tip_drag")),
            (t("tip_resize_key"), t("tip_resize")),
            (t("tip_hold_key"), t("tip_hold")),
        ]
    }
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
        "switcher_placeholder": "Search windows…",
        "onboarding_subtitle": "Tiling window manager. Two permissions are needed before it can start.",
        "onboarding_accessibility": "Moving and resizing windows of other apps.",
        "onboarding_input": "The hyper key (CapsLock) and keyboard shortcuts.",
        "onboarding_remap": "Starting remaps CapsLock to act as the hyper key and begins tiling your windows.",
        "onboarding_start": "Start ancre",
        "onboarding_grant": "Grant…",
        "onboarding_howto": "The basics",
        "tip_workspaces": "switch workspaces",
        "tip_focus": "move focus between windows",
        "tip_move": "move the focused window",
        "tip_switcher": "search windows (Spotlight-style)",
        "tip_drag_key": "drag a window",
        "tip_drag": "move it — edges insert, center swaps",
        "tip_resize_key": "drag a window edge",
        "tip_resize": "resize — neighbors adjust",
        "tip_hold_key": "hold hyper",
        "tip_hold": "cheatsheet with every shortcut",
        "onboarding_ai": "AI ready: the `ancrectl` CLI and an MCP server (mcp/) let agents inspect and arrange your windows — register with: claude mcp add ancre -- node <repo>/mcp/index.js",
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
            "switcher_placeholder": "Hledat okna…",
            "onboarding_subtitle": "Tiling window manager. Před spuštěním potřebuje dvě oprávnění.",
            "onboarding_accessibility": "Přesouvání a resize oken ostatních aplikací.",
            "onboarding_input": "Hyper klávesa (CapsLock) a klávesové zkratky.",
            "onboarding_remap": "Spuštění přemapuje CapsLock na hyper klávesu a začne skládat okna.",
            "onboarding_start": "Spustit ancre",
            "onboarding_grant": "Povolit…",
            "onboarding_howto": "Základy ovládání",
            "tip_workspaces": "přepínání workspaces",
            "tip_focus": "fokus mezi okny",
            "tip_move": "přesun fokusovaného okna",
            "tip_switcher": "hledání oken (jako Spotlight)",
            "tip_drag_key": "tažení okna",
            "tip_drag": "přesun — kraje vloží, střed prohodí",
            "tip_resize_key": "tažení hrany okna",
            "tip_resize": "resize — sousedi se přizpůsobí",
            "tip_hold_key": "podržet hyper",
            "tip_hold": "nápověda se všemi zkratkami",
            "onboarding_ai": "AI ready: CLI `ancrectl` a MCP server (mcp/) — agenti můžou okna číst i přeskládat. Registrace: claude mcp add ancre -- node <repo>/mcp/index.js",
        ],
    ]
}
