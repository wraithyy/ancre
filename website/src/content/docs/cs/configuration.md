---
title: Konfigurace
description: ancre.toml — sekce, klíče a reload za běhu.
sidebar:
  order: 3
---

Config žije v `~/.config/ancre/ancre.toml` — vytvoří se z defaultů při prvním
spuštění. Kompletní katalog klíčů s defaulty: `Sources/Config/default.toml`
v repozitáři.

Změny aplikuje **Reload config** v menubar menu (nebo `ancrectl reload-config`)
bez restartu. Chyba v configu nikdy neshodí app — fallback na defaulty
s warningem v logu.

## Přehled sekcí

| Sekce | Co řídí |
|---|---|
| `[general]` | gaps, animace, `default-layout`, `language` ("en"/"cs"), `follow-native-focus`, `auto-stack`, `move-log` |
| `[hyper]` | fyzická klávesa hyperu |
| `[keybindings]` | zkratky → commandy; **merguje se s defaulty** (default vypneš prázdným stringem) |
| `[workspaces]` | workspace → monitor (stabilní ID `vendor:model:serial` nebo část názvu) |
| `[workspace-labels]` | per-workspace: `name`, `icon` (emoji), `show-number`, `hide-when-empty`, `layout` |
| `[app-workspaces]` | bundle ID → workspace pro nová okna |
| `[custom-layouts]` | vlastní layouty ze šablon — viz [Layouty](/ancre/cs/layouts/) |
| `[theme]` | sdílené barvy (`accent`, `background`, hex `#RRGGBB[AA]`) |
| `[bar]` + `[bar-overrides.*]` | workspace bar — viz [Bar](/ancre/cs/bar/) |
| `[border]` | rámeček fokusu: `enabled`, `color`, `width`, `radius` |
| `[help]` | cheatsheet: `enabled`, `delay-ms`, `opacity`, `font-size`, `columns`, `corner-radius` |
| `[scratchpad]` | app + rozměry plovoucího scratchpad okna |
| `[preview]` | barva/průhlednost drag&drop preview |

## `[general]`

```toml
[general]
gaps-inner = 8
gaps-outer = 8
animations = true
animation-duration-ms = 180
# Appky, které se animují špatně — placement okamžitě:
# animations-exclude = ["com.microsoft.teams2"]
default-layout = "dwindle"   # dwindle | scroll | stack (monocle)
# language = "en"            # jazyk bar menu/tooltipů: "en" | "cs"
# follow-native-focus = true # při nativní aktivaci appky přepnout na její workspace
# auto-stack = true          # workspace na malém monitoru dočasně do stack layoutu
# auto-stack-min-width = 300
# move-log = true            # log ručních přesunů do move-log.jsonl (pro AI návrhy pravidel)
```

## `[keybindings]`

Klíč je binding string (`"hyper-shift-h"`), hodnota command string. Merguje se
s defaulty — default vypneš prázdným stringem:

```toml
[keybindings]
"hyper-g" = "workspace 5"   # přidání
"hyper-p" = ""              # vypnutí defaultu
```

## `[app-workspaces]`

Nová okna appky jdou rovnou na workspace:

```toml
[app-workspaces]
"com.spotify.client" = "9"
"com.microsoft.teams2" = "5"
```

:::tip
Ruční přesuny oken se logují do
`~/Library/Application Support/ancre/move-log.jsonl` (bundle ID + workspaces,
bez titulků). Soubor můžeš předhodit agentovi, ať ti navrhne
`[app-workspaces]` pravidla.
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
background = "#1e1e2eCC"    # absent = systémový accent/materiál

[border]
enabled = true
color = "#89b4fa"   # default: theme accent
width = 2
radius = 10         # default odpovídá systémovému radiusu oken

[scratchpad]
app = "com.mitchellh.ghostty"
width = 0.6
height = 0.5

[preview]
color = "#89b4fa"
opacity = 0.3
```
