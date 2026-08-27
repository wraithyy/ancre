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

<!-- media (shotlist: configuration.md):
![ancre.toml in an editor with syntax highlighting](../../assets/configuration-editor.png)
![Live reload: editing a gap value and saving — windows rearrange instantly](../../assets/configuration-live-reload.gif)
![Validation warning after a config typo — the app keeps running](../../assets/configuration-warning.png)
-->


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
# Apps ancre never manages — for apps that fight the tiler (Xcode).
# New windows are left alone; a config reload releases already-managed ones.
# ignore-apps = ["com.apple.dt.Xcode"]
# Apps whose new windows start floating instead of tiled (hyper+v tiles them):
# float-apps = ["com.apple.systempreferences"]
# Daily anonymous check of GitHub Releases; a newer version shows a menubar
# menu item linking to the release page. Never downloads or installs anything.
# update-check = true
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

## A complete example

A real single-user setup, lightly edited. Workspaces 1–5 live on whichever
external monitor is connected, 6–7 stay on the laptop, and apps route
themselves to a workspace on launch.

```toml
[general]
gaps-inner = 8
gaps-outer = 4
animations = true
animation-duration-ms = 180
# Apps whose windows resize too slowly to animate well.
animations-exclude = ["com.microsoft.teams2"]
# Xcode fights the tiler, so ancre leaves it alone.
ignore-apps = ["com.apple.dt.Xcode"]
default-layout = "dwindle"

[hyper]
key = "caps_lock"

[keybindings]
"hyper-h" = "focus left"
"hyper-j" = "focus down"
"hyper-k" = "focus up"
"hyper-l" = "focus right"
"hyper-shift-h" = "move left"
"hyper-shift-j" = "move down"
"hyper-shift-k" = "move up"
"hyper-shift-l" = "move right"
"hyper-left" = "resize width -50"
"hyper-right" = "resize width +50"
"hyper-1" = "workspace 1"
"hyper-shift-1" = "move-to-workspace 1"
"hyper-v" = "toggle-floating"
"hyper-f" = "toggle-fullscreen"
"hyper-a" = "adopt-window"
"hyper-t" = "layout scroll"
"hyper-shift-t" = "layout dwindle"
"hyper-comma" = "focus-monitor previous"
"hyper-period" = "focus-monitor next"

# Two monitors, one at each desk. Name matching is a substring, and the two
# share none, so both are listed - the first connected one wins.
[workspaces]
"1" = ["Studio Display", "U3423WE"]
"2" = ["Studio Display", "U3423WE"]
"3" = ["Studio Display", "U3423WE"]
"6" = "Built-in"
"7" = "Built-in"

[workspace-labels]
"1" = { icon = "\U0001F4BB", name = "term" }
"2" = { icon = "\U0001F310", name = "web" }
"3" = { icon = "\U0001F4AC", name = "chat" }
"4" = { icon = "\U0001F3B5", name = "music", hide-when-empty = true }
"8" = { hide-when-empty = true }
"9" = { hide-when-empty = true }

[app-workspaces]
"com.mitchellh.ghostty" = "1"
"com.microsoft.VSCode" = "1"
"com.google.Chrome" = "2"
"com.apple.Safari" = "2"
"com.microsoft.Outlook" = "3"
"com.spotify.client" = "4"
"com.apple.Music" = "4"
"com.apple.iCal" = "6"
"com.apple.mail" = "6"

[bar]
enabled = true
position = "menubar"
opacity = 0.75
peek = true
idle-opacity = 0.55

# On the built-in display the bar hides under the notch and slides out on hover.
[bar-overrides.notch]
position = "notch"

# hyper-s drops Ghostty over the middle of the screen; press again to hide it.
[scratchpad]
app = "com.mitchellh.ghostty"
width = 0.6
height = 0.5
```
