---
title: Configuration
description: ancre.toml — sections, keys, and live reload.
sidebar:
  order: 3
---

The config lives at `~/.config/ancre/ancre.toml` — created from defaults on
first launch. The complete key catalog with types, defaults, and allowed
values: [Config reference](/ancre/config-reference/).

Changes apply via **Reload config** in the menu bar menu (or
`ancrectl reload-config`) without a restart. A config error never crashes the
app — it falls back to defaults with a warning in the log.

:::caution
A *missing* key is always safe — it falls back to that key's default and the
rest of your config is kept. A key with the *wrong type* is not: it aborts the
whole decode, so your **entire** user config is discarded for that reload and
everything falls back to bundled defaults. The exceptions are the numeric keys
(`gaps-inner`, `gaps-outer`, `opacity`, `height`, …), which accept either an
int or a float and fall back to their own default if the value is neither.
:::

## Section overview

| Section | Controls |
|---|---|
| `[general]` | gaps, animations, `default-layout`, `language` ("en"/"cs"), `follow-native-focus`, `auto-stack`, `move-log` |
| `[hyper]` | the physical hyper key |
| `[keybindings]` | shortcuts → commands; **merged with defaults** (disable a default with an empty string) |
| `[workspaces]` | workspace → monitor (stable ID `vendor:model:serial` or part of the display name) |
| `[workspace-labels]` | per-workspace: `name`, `icon` (emoji), `show-number`, `hide-when-empty`, `layout` |
| `[app-workspaces]` | bundle ID → workspace for new windows |
| `[custom-layouts]` | custom layouts from templates — see [Layouts](/ancre/layouts/) |
| `[theme]` | shared colors (`accent`, `background`, hex `#RRGGBB[AA]`) |
| `[bar]` + `[bar-overrides.*]` | workspace bar — see [Bar](/ancre/bar/) |
| `[border]` | focus border: `enabled`, `color`, `width`, `radius` |
| `[help]` | cheatsheet: `enabled`, `delay-ms`, `opacity`, `font-size`, `columns`, `corner-radius` |
| `[scratchpad]` | app + dimensions of the floating scratchpad window |
| `[preview]` | colour/opacity of the drag&drop preview |

## `[general]`

```toml
[general]
gaps-inner = 8
gaps-outer = 8
animations = true
animation-duration-ms = 180   # silently clamped to 50-500 ms
# Apps that animate badly — place instantly:
# animations-exclude = ["com.microsoft.teams2"]
default-layout = "dwindle"   # dwindle | scroll | stack (monocle)
# language = "en"            # bar menu/tooltip language: "en" | "cs"
# follow-native-focus = true # on native app activation, switch to its workspace
# auto-stack = true          # workspace on a too-small monitor temporarily stacks
# auto-stack-min-width = 300
# move-log = true            # log manual moves to move-log.jsonl (for AI rule suggestions)
```

## `[keybindings]`

The key is a binding string (`"hyper-shift-h"`), the value a command string.
Merged with defaults — disable a default with an empty string:

```toml
[keybindings]
"hyper-g" = "workspace 5"   # add
"hyper-p" = ""              # disable a default
```

## `[app-workspaces]`

New windows of an app go straight to a workspace:

```toml
[app-workspaces]
"com.spotify.client" = "9"
"com.microsoft.teams2" = "5"
```

:::tip
Manual window moves are logged to
`~/Library/Application Support/ancre/move-log.jsonl` (bundle ID + workspaces,
no titles). Feed the file to an agent to get `[app-workspaces]` rule
suggestions.
:::

## `[workspace-labels]`

```toml
[workspace-labels]
"1" = { icon = "🌐", name = "web", show-number = false, layout = "scroll" }
"2" = { name = "code", hide-when-empty = true }
```

## `[theme]`, `[border]`, `[scratchpad]`, `[preview]`

```toml
[theme]
accent = "#89b4fa"
background = "#1e1e2eCC"    # absent = system accent/material

[border]
enabled = true
color = "#89b4fa"   # default: theme accent
width = 2
radius = 10         # default matches the system window corner radius

[scratchpad]
app = "com.mitchellh.ghostty"
width = 0.6
height = 0.5

[preview]
color = "#89b4fa"
opacity = 0.3
```
