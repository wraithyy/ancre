# Configuration

> Nicer rendering: https://wraithyy.github.io/ancre/configuration/ —
> full key catalog: https://wraithyy.github.io/ancre/config-reference/

`~/.config/ancre/ancre.toml`, created from defaults on first run. TOML is
an INI-like plain-text format — edit it with any text editor. The full
annotated catalog of every key lives in
[`Sources/Config/default.toml`](../Sources/Config/default.toml). Apply
changes with **Reload config** in the menu bar menu or
`ancrectl reload-config` — no restart, and a config typo never crashes the
app (it falls back to defaults and logs a warning).

## Sections

| Section | Controls |
|---|---|
| `[general]` | `gaps-inner/outer`, `animations` + `animation-duration-ms` + `animations-exclude` (bundle ids), `default-layout`, `language` (`"en"`/`"cs"`), `follow-native-focus`, `auto-stack` + `auto-stack-min-width`, `move-log` |
| `[hyper]` | physical hyper key (`caps_lock`, `f13`–`f20`, `right_cmd`, `right_option`) |
| `[keybindings]` | shortcut → command; merges with defaults, `""` unbinds |
| `[workspaces]` | workspace → monitor: stable id (`vendor:model:serial`, copy from the menu bar) or a name substring; also a **priority list** `"1" = ["PHL", "Built-in"]` — first connected match wins |
| `[workspace-labels]` | per workspace: `name`, `icon` (emoji), `show-number`, `hide-when-empty`, `layout` |
| `[app-workspaces]` | bundle id → workspace for new windows (an app's bundle id is its stable identifier, e.g. `com.google.Chrome`; `ancrectl state` shows them) |
| `[custom-layouts]` | template layouts: `h(ratio, …)` side-by-side, `v(ratio, …)` stacked, `*` window slot; extra windows stack into the last slot |
| `[theme]` | shared colors: `accent`, `background` (`#RRGGBB` / `#RRGGBBAA`) |
| `[bar]` | `enabled`, `position` (`top`/`bottom`/`left`/`right`/`menubar`/`notch`), `align`, `offset-x/y`, `height`, `notch-side`, `peek` + `idle-opacity` (bar hides or ghosts until hyper is held or hovered), colors (`background-color`, `accent-color`, `float-color`, `badge-color`), typography (`font-size`, `font-family`), metrics (`icon-size`, `spacing`, `cell-*`, `pill-*`, `ring-width`, `max-icons`), `opacity`, `active-opacity`, `inactive-icon-opacity` |
| `[bar-overrides.<matcher>]` | per-monitor overrides of any `[bar]` key; matcher = stable id, name substring, or `notch` for notched displays (specific matcher beats `notch` beats base) |
| `[border]` | focus border: `enabled`, `color`, `width`, `radius` |
| `[preview]` | drag&drop placeholder: `color`, `opacity` |
| `[help]` | cheatsheet: `enabled`, `delay-ms`, `opacity`, `font-size`, `columns`, `corner-radius` |
| `[scratchpad]` | `app` (bundle id), `width`, `height` (fractions of the screen), `command` (shell command opening a new window; default `open -n` on the app). Its window stays outside tiling: own window, no workspace, no tile |

## Vertical bars, menubar mode, notch mode

`left`/`right` render workspaces vertically (number above stacked icons).
`menubar` puts the pill *inside* the system menu bar band — no tiling space
lost; on a notched display it sits beside the notch (`notch-side`). `notch`
hides the bar entirely; move the cursor into the notch (or hold hyper) and
the pill slides out beneath it.

## Multi-monitor behavior

Monitors get hardware-stable ids (`vendor:model:serial`) that survive
replugs and reboots — CGDirectDisplayIDs don't. Workspace placement is a
pure function of (names, config, connected monitors), so disconnecting a
display migrates its workspaces to a connected one and replugging restores
the exact previous arrangement. If a migrated workspace doesn't fit
(too many windows for the monitor's width), **auto-stack** temporarily
switches it to the stack layout and back when space returns.

## Learning your habits

With `move-log = true` (default), every manual window move is logged as
one JSON line (bundle id + source/target workspace, **no window titles**) to
`~/Library/Application Support/ancre/move-log.jsonl`. Feed the file to an
agent and ask it to propose `[app-workspaces]` rules that match how you
actually sort your windows.
