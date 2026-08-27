---
title: Config reference
description: Every ancre.toml key in one place — types, defaults, allowed values, validation.
sidebar:
  order: 10
---

Complete catalog of every key the config loader actually parses, extracted
from `Sources/Config/Config.swift`. The config lives at
`~/.config/ancre/ancre.toml`; changes apply via **Reload config** (menu bar
or `ancrectl reload-config`). A config error never crashes the app — it falls
back to defaults with a warning in the log. For a guided tour see
[Configuration](/ancre/configuration/).

## `[general]`

| Key | Type | Default | Allowed / range | Notes |
|---|---|---|---|---|
| `gaps-inner` | number | `8` | ≥ 0 (negative clamps to 0 with a warning) | gap between windows |
| `gaps-outer` | number | `8` | ≥ 0 (clamped) | gap to the screen edge |
| `animations` | bool | `true` | — | enable animations |
| `animation-duration-ms` | int | `180` | ms, silently clamped to 50-500 | animation length |
| `default-layout` | string | `"dwindle"` | `dwindle` \| `scroll` \| `stack` \| any `[custom-layouts]` name; unknown → warning + fallback | default layout |
| `animations-exclude` | string array | `[]` | bundle IDs | apps that always place instantly |
| `language` | string | `"en"` | `"en"` \| `"cs"` (not validated) | bar menu/tooltip language |
| `follow-native-focus` | bool | `true` | — | switch to a window's workspace when macOS activates its app |
| `auto-stack` | bool | `true` | — | a workspace whose windows can't fit its monitor temporarily stacks (checked on every window change) |
| `auto-stack-min-width` | number | `300` | — | threshold: `count × min-width > monitor width` triggers auto-stack |
| `auto-stack-thrash-limit` | number | `8` | — | refused frames in one burst before a workspace is force-stacked (with a notification) — catches windows whose min-size defeats the width heuristic |
| `move-log` | bool | `true` | — | log manual moves to `move-log.jsonl` (bundle ID + workspaces, no titles) |
| `ignore-apps` | string[] | `[]` | bundle ids | apps ancre never manages; reload releases already-managed windows |
| `float-apps` | string[] | `[]` | bundle ids | new windows of these apps start floating |
| `update-check` | bool | `true` | — | daily GitHub Releases check; newer version = menubar menu item, nothing is installed |

## `[hyper]`

| Key | Type | Default | Allowed | Notes |
|---|---|---|---|---|
| `key` | string | `"caps_lock"` | `caps_lock`, `f13`–`f20`, `right_cmd`, `right_option`; anything else → warning + default | physical key remapped to hyper |

## `[keybindings]`

Free-form map: binding string → command string.

```toml
[keybindings]
"hyper-g" = "workspace 5"   # add a binding
"hyper-p" = ""              # empty string = unbind a default
```

- Merged key-by-key with the built-in defaults.
- An unparseable command string logs a warning and the binding is dropped.
- The full default set is listed in [Controls](/ancre/controls/).

## `[workspaces]`

Map: workspace name → monitor matcher. The value is either a **single
string** or an **array** (priority list — the first connected monitor wins):

```toml
[workspaces]
"1" = "Built-in"
"9" = ["PHL", "Built-in"]   # prefer PHL, fall back to Built-in
```

A matcher is a stable monitor ID (`vendor:model:serial`) or a
case-insensitive substring of the display name. Entries with an
empty/whitespace matcher are dropped with a warning.

## `[workspace-labels]`

Sub-key = workspace name, value = a table:

| Key | Type | Default | Notes |
|---|---|---|---|
| `name` | string | — | custom label |
| `icon` | string | — | emoji/text before the label |
| `show-number` | bool | `true` | show the workspace number |
| `hide-when-empty` | bool | `false` | hide when it has no windows (the active workspace is always shown) |
| `layout` | string | `general.default-layout` | `dwindle` \| `scroll` \| `stack` \| a `[custom-layouts]` name |

## `[app-workspaces]`

Map: bundle ID → workspace name for new windows. No validation.

```toml
[app-workspaces]
"com.spotify.client" = "9"
```

## `[custom-layouts]`

Map: layout name → template string. Names extend the set of valid layouts
for `default-layout`, `workspace-labels.layout`, and the `layout` command.
Template grammar: see [Layouts](/ancre/layouts/).

```toml
[custom-layouts]
"master" = "h(0.6, *, v(0.5, *, *))"
```

## `[theme]`

| Key | Type | Default | Notes |
|---|---|---|---|
| `accent` | string | system accent | `"#RRGGBB"` / `"#RRGGBBAA"` |
| `background` | string | system material | shared surface background |

## `[bar]`

| Key | Type | Default | Allowed / range | Notes |
|---|---|---|---|---|
| `enabled` | bool | `true` | — | enable the bar |
| `position` | string | `"top"` | `top` \| `bottom` \| `left` \| `right` \| `menubar` \| `notch`; invalid → warning + fallback | see [Workspace bar](/ancre/bar/) |
| `opacity` | number | `1.0` | 0–1 | pill background opacity |
| `height` | number | `28` | — | strip height / thickness |
| `align` | string | `"center"` | `center` \| `left` \| `right` (not validated) | pill placement along the edge |
| `notch-side` | string | `"left"` | `left` \| `right` (not validated) | side of the notch for `menubar` position |
| `offset-x` | number | `0` | — | shift along the edge |
| `offset-y` | number | `0` | — | push away from the screen edge |
| `background-color` | string | system material | `"#RRGGBB[AA]"` | pill background |
| `accent-color` | string | system accent | `"#RRGGBB"` | highlight |
| `float-color` | string | white | `"#RRGGBB"` | dashed ring on floating windows |
| `badge-color` | string | system red | `"#RRGGBB"` | notification badge |
| `icon-size` | number | `17` | — | app icon size |
| `font-size` | number | `13` | — | workspace number; label 1 pt smaller, badge ~half |
| `font-family` | string | system font | — | numbers are monospaced when unset |
| `spacing` | number | `6` | — | between workspace cells |
| `cell-spacing` | number | `4` | — | inside a cell |
| `cell-radius` | number | `6` | — | cell corner radius |
| `cell-padding-x` | number | `8` | — | |
| `cell-padding-y` | number | `3` | — | |
| `pill-padding-x` | number | `10` | — | |
| `pill-padding-y` | number | `3` | — | |
| `active-opacity` | number | `0.55` | — | active workspace highlight |
| `inactive-icon-opacity` | number | `0.75` | — | icons of unfocused windows |
| `ring-width` | number | `1.5` | — | focus/float ring thickness |
| `max-icons` | int | `6` | — | max icons per workspace cell |
| `peek` | bool | `false` | — | idle at `idle-opacity`, show fully while hyper is held |
| `idle-opacity` | number | `0` | 0–1 | `0` = hidden, `0.3` = ghost |

## `[bar-overrides]`

Per-monitor overrides of `[bar]` keys. Sub-key = matcher: the literal
`"notch"` matches notched displays; any other key is a monitor matcher
(stable ID exact match, or case-insensitive name substring). Priority:
specific matcher > `notch` > base `[bar]`. Matchers are checked in
alphabetical order; the first match applies.

Overridable keys — **only these**: `position`, `align`, `notch-side`,
`offset-x`, `offset-y`, `height`, `opacity`, `icon-size`, `font-size`,
`peek`, `idle-opacity`. Colors, typography, and cell metrics cannot be
overridden per monitor.

```toml
[bar-overrides.notch]
position = "notch"

[bar-overrides."PHL"]
align = "left"
icon-size = 17
```

## `[border]`

| Key | Type | Default | Notes |
|---|---|---|---|
| `enabled` | bool | `true` | focus border around the focused window |
| `color` | string | theme accent | `"#RRGGBB"` |
| `width` | number | `2` | thickness |
| `radius` | number | `10` | matches the system window corner radius |

## `[help]`

| Key | Type | Default | Notes |
|---|---|---|---|
| `enabled` | bool | `true` | keybinding cheatsheet overlay |
| `delay-ms` | number | `2000` | how long hyper must be held |
| `opacity` | number | `0.85` | |
| `font-size` | number | `11` | |
| `columns` | int | `3` | |
| `corner-radius` | number | `12` | |

## `[scratchpad]`

| Key | Type | Default | Notes |
|---|---|---|---|
| `app` | string | unset (feature off) | bundle ID of the drop-down app; launched when not running |
| `width` | number | `0.6` | fraction of monitor width |
| `height` | number | `0.5` | fraction of monitor height |
| `command` | string | `open -n` on the app | shell command opening a **new** window; the scratchpad owns its own window, never hijacks one you work in, and stays outside tiling (no workspace, no tile, no bar/switcher entry) |

## `[preview]`

| Key | Type | Default | Notes |
|---|---|---|---|
| `color` | string | theme accent | drag&drop placeholder color |
| `opacity` | number | `0.3` | fill of the dragged window's future slot |

## Validation summary

- Clamped: `gaps-inner`/`gaps-outer` to ≥ 0; `animation-duration-ms` to
  50–500 ms.
- Validated with fallback: `default-layout`, `hyper.key`, `bar.position`,
  `[workspaces]` matchers, `[keybindings]` command strings.
- **Not validated** (a wrong value passes through and misbehaves at the
  consumer): `align`, `notch-side`, `language`, color strings.
- `# [[rules]]` in `default.toml` is a placeholder for a future window-rules
  section — the loader does not read it yet.

:::caution
A missing key falls back to its own default and the rest of the config is
kept. A key with the wrong *type* aborts decoding of the whole file, and the
entire user config for that reload falls back to bundled defaults — not just
the offending key. The numeric keys above are the exception: they accept an
int or a float and fall back to their own default otherwise.
:::
