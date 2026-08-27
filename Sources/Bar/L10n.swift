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
    public static var adoptWindow: String { t("adopt_window") }
    public static var switcher: String { t("switcher") }
    public static var resumeTiling: String { t("resume_tiling") }
    public static var paletteScratchpad: String { t("palette_scratchpad") }
    public static func paletteLayout(_ name: String) -> String {
        String(format: t("palette_layout"), name)
    }
    public static func palettePreset(_ name: String) -> String {
        String(format: t("palette_preset"), name)
    }
    public static var monitors: String { t("monitors") }
    public static func scratchpad(app: String?, running: Bool) -> String {
        guard let app else { return t("scratchpad_off") }
        return String(format: t(running ? "scratchpad_running" : "scratchpad_idle"), app)
    }
    public static var scratchpadTooltip: String { t("scratchpad_tooltip") }
    public static func updateAvailable(_ version: String) -> String {
        String(format: t("update_available"), version)
    }
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
    public static func autoStacked(_ name: String) -> String {
        String(format: t("auto_stacked"), name)
    }
    public static func autoFloated(_ app: String) -> String {
        String(format: t("auto_floated"), app)
    }
    public static var tapDisabled: String { t("tap_disabled") }
    public static var axPermissionLost: String { t("ax_permission_lost") }
    public static var remapFailed: String { t("remap_failed") }
    public static func configWarnings(first: String, count: Int) -> String {
        count > 1
            ? String(format: t("config_warnings_many"), first, count - 1)
            : String(format: t("config_warnings_one"), first)
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
        "adopt_window": "Adopt frontmost window",
        "switcher": "Window switcher…",
        "resume_tiling": "Resume tiling",
        "palette_scratchpad": "Toggle scratchpad",
        "palette_layout": "Layout: %@",
        "palette_preset": "Preset: %@",
        "monitors": "Monitors (click to copy id)",
        "scratchpad_running": "Scratchpad: %@ (running)",
        "scratchpad_idle": "Scratchpad: %@ (not running)",
        "scratchpad_off": "Scratchpad: not configured",
        "scratchpad_tooltip": "A drop-down window of one app, summoned over any workspace with hyper+s and hidden again. It lives outside tiling: no workspace, no tile, never rearranged. Set [scratchpad].app in the config.",
        "update_available": "Update to %@ available…",
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
        "onboarding_ai": "AI ready: agents can inspect and arrange your windows via the ancrectl CLI or its built-in MCP server — register with: claude mcp add ancre -- ancrectl mcp",
        "auto_stacked": "Workspace %@ can't fit its windows — switched to the stack layout.",
        "auto_floated": "%@ refuses its tile size — window floated.",
        "tap_disabled": "macOS disabled ancre's keyboard shortcuts — re-enabled.",
        "ax_permission_lost": "Accessibility permission lost — ancre can't manage windows. Re-grant it in System Settings → Privacy & Security.",
        "remap_failed": "Hyper key remap failed (hidutil) — hyper shortcuts may not work.",
        "config_warnings_one": "Config: %@",
        "config_warnings_many": "Config: %@ (+%d more warnings)",
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
            "adopt_window": "Adoptovat aktivní okno",
            "switcher": "Přepínač oken…",
            "resume_tiling": "Obnovit tiling",
            "palette_scratchpad": "Přepnout scratchpad",
            "palette_layout": "Layout: %@",
            "palette_preset": "Preset: %@",
            "monitors": "Monitory (klik zkopíruje id)",
            "scratchpad_running": "Scratchpad: %@ (běží)",
            "scratchpad_idle": "Scratchpad: %@ (neběží)",
            "scratchpad_off": "Scratchpad: nenastavený",
            "scratchpad_tooltip": "Vysouvací okno jedné aplikace, přivolané přes hyper+s nad jakoukoli workspace a stejně tak schované. Žije mimo tiling: žádná workspace, žádná dlaždice, nikdy se nepřeskládá. Nastav [scratchpad].app v configu.",
            "update_available": "Aktualizace %@ k dispozici…",
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
            "onboarding_ai": "AI ready: agenti můžou okna číst i přeskládat přes CLI ancrectl nebo jeho vestavěný MCP server. Registrace: claude mcp add ancre -- ancrectl mcp",
            "auto_stacked": "Workspace %@ — okna se nevešla, přepnuto na stack layout.",
            "auto_floated": "%@ odmítá velikost dlaždice — okno floatuje.",
            "tap_disabled": "macOS vypnul klávesové zkratky ancre — znovu zapnuto.",
            "ax_permission_lost": "Ztraceno oprávnění Accessibility — ancre nemůže spravovat okna. Povol znovu v Nastavení systému → Soukromí a zabezpečení.",
            "remap_failed": "Přemapování hyper klávesy selhalo (hidutil) — hyper zkratky nemusí fungovat.",
            "config_warnings_one": "Config: %@",
            "config_warnings_many": "Config: %@ (+%d dalších varování)",
        ],
    ]
}
