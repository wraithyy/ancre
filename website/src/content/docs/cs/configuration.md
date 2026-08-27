---
title: Konfigurace
description: ancre.toml — sekce, klíče a reload za běhu.
sidebar:
  order: 3
---

Config žije v `~/.config/ancre/ancre.toml` — vytvoří se z defaultů při prvním
spuštění. Kompletní katalog klíčů s typy, defaulty a povolenými hodnotami:
[Config reference](/ancre/cs/config-reference/).

Změny aplikuje **Znovu načíst config** v menubar menu (nebo
`ancrectl reload-config`) bez restartu. Chyba v configu nikdy neshodí app —
fallback na defaulty s warningem v logu.

<!-- media (shotlist: configuration.md):
![ancre.toml v editoru se syntax highlightem](../../../assets/configuration-editor.png)
![Live reload: úprava gap hodnoty a uložení — okna se okamžitě přeskládají](../../../assets/configuration-live-reload.gif)
![Warning po překlepu v configu — app běží dál](../../../assets/configuration-warning.png)
-->


:::caution
*Chybějící* klíč je vždy bezpečný — doplní se jeho default a zbytek configu
zůstane nedotčený. Klíč se *špatným typem* bezpečný není: shodí celé
dekódování, takže se pro daný reload zahodí **celý** uživatelský config a
všechno spadne na bundlované defaulty. Výjimkou jsou číselné klíče
(`gaps-inner`, `gaps-outer`, `opacity`, `height`, …), které přijmou int
i float a při jiné hodnotě použijí vlastní default.
:::

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
| `[scratchpad]` | app, rozměry a spouštěcí `command` plovoucího scratchpad okna |
| `[preview]` | barva/průhlednost drag&drop preview |

## `[general]`

```toml
[general]
gaps-inner = 8
gaps-outer = 8
animations = true
animation-duration-ms = 180   # tiše se clampne na 50-500 ms
# Appky, které se animují špatně — placement okamžitě:
# animations-exclude = ["com.microsoft.teams2"]
default-layout = "dwindle"   # dwindle | scroll | stack (monocle)
# language = "en"            # jazyk bar menu/tooltipů: "en" | "cs"
# follow-native-focus = true # při nativní aktivaci appky přepnout na její workspace
# auto-stack = true          # workspace na malém monitoru dočasně do stack layoutu
# auto-stack-min-width = 300
# move-log = true            # log ručních přesunů do move-log.jsonl (pro AI návrhy pravidel)
# Appky, které ancre nikdy nespravuje — pro appky, co s tilerem válčí (Xcode).
# Nová okna nechá být; reload configu pustí i už spravovaná.
# ignore-apps = ["com.apple.dt.Xcode"]
# Appky, jejichž nová okna začínají jako floating (hyper+v je zadlaždicuje):
# float-apps = ["com.apple.systempreferences"]
# Denní anonymní dotaz na GitHub Releases; novější verze zobrazí položku
# v menubar menu s odkazem na release page. Nikdy nic nestahuje ani neinstaluje.
# update-check = true
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
# command = "open -na Ghostty"   # jak otevřít NOVÉ okno; default: `open -n` na appku

[preview]
color = "#89b4fa"
opacity = 0.3
```

Scratchpad má vlastní okno: `hyper+s` nikdy nepřebere okno, ve kterém právě
pracuješ. První stisk jedno otevře — defaultně druhou instanci appky
(`open -n`), nebo cokoli nastavíš v `command` — a každý další stisk už jen
přepíná to samé okno. `command` nastav, když appka umí otevřít nové okno
levněji než celou druhou instancí.

## Kompletní příklad

Reálné nastavení jednoho uživatele, lehce upravené. Workspaces 1–5 žijí na tom
externím monitoru, který je zrovna připojený, 6–7 zůstávají na notebooku a
aplikace se při spuštění samy zařadí na svůj workspace.

```toml
[general]
gaps-inner = 8
gaps-outer = 4
animations = true
animation-duration-ms = 180
# Aplikace, jejichž okna mění velikost moc pomalu na animaci.
animations-exclude = ["com.microsoft.teams2"]
# Xcode válčí s tilerem, takže ho ancre nechává být.
ignore-apps = ["com.apple.dt.Xcode"]
default-layout = "dwindle"
language = "cs"

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

# Dva monitory, na každém stole jeden. Název se hledá jako podřetězec a
# společný nemají, proto jsou uvedené oba — vyhraje první připojený.
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

# Na vestavěném displeji se bar schová pod notch a vyjede při najetí myší.
[bar-overrides.notch]
position = "notch"

# hyper-s hodí Ghostty přes střed obrazovky, dalším stiskem ho schová.
[scratchpad]
app = "com.mitchellh.ghostty"
width = 0.6
height = 0.5
```
