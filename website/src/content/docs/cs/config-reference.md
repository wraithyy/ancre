---
title: Config reference
description: Všechny klíče ancre.toml na jednom místě — typy, defaulty, povolené hodnoty, validace.
sidebar:
  order: 10
---

Kompletní katalog všech klíčů, které config loader skutečně parsuje —
extrahováno ze `Sources/Config/Config.swift`. Config žije
v `~/.config/ancre/ancre.toml`; změny aplikuje **Reload config** (menubar
nebo `ancrectl reload-config`). Chyba v configu nikdy neshodí app — fallback
na defaulty s warningem v logu. Průvodce: [Konfigurace](/ancre/cs/configuration/).

## `[general]`

| Klíč | Typ | Default | Povolené / rozsah | Poznámka |
|---|---|---|---|---|
| `gaps-inner` | číslo | `8` | ≥ 0 (záporné se clampne na 0 s warningem) | mezera mezi okny |
| `gaps-outer` | číslo | `8` | ≥ 0 (clamp) | mezera k okraji obrazovky |
| `animations` | bool | `true` | — | zapnutí animací |
| `animation-duration-ms` | int | `180` | ms, tiše se clampne na 50-500 | délka animace |
| `default-layout` | string | `"dwindle"` | `dwindle` \| `scroll` \| `stack` \| název z `[custom-layouts]`; neznámý → warning + fallback | výchozí layout |
| `animations-exclude` | pole stringů | `[]` | bundle ID | appky s okamžitým placementem |
| `language` | string | `"en"` | `"en"` \| `"cs"` (nevalidováno) | jazyk bar menu/tooltipů |
| `follow-native-focus` | bool | `true` | — | při nativní aktivaci appky přepnout na její workspace |
| `auto-stack` | bool | `true` | — | workspace, jehož okna se na monitor nevejdou, dočasně do stack layoutu (kontrola při každé změně oken) |
| `auto-stack-min-width` | číslo | `300` | — | práh: `počet × min-width > šířka monitoru` |
| `auto-stack-thrash-limit` | číslo | `8` | — | počet odmítnutých framů v jednom burstu, po kterém se workspace force-stackne (s notifikací) — chytá okna s min-size, které šířková heuristika nevidí |
| `move-log` | bool | `true` | — | log ručních přesunů do `move-log.jsonl` (bundle ID + workspaces, bez titulků) |
| `ignore-apps` | string[] | `[]` | bundle ids | appky, které ancre nikdy nespravuje; reload pustí i už spravovaná okna |
| `float-apps` | string[] | `[]` | bundle ids | nová okna těchto appek začínají jako floating |
| `update-check` | bool | `true` | — | denní dotaz na GitHub Releases; novější verze = položka v menubar menu, nic se neinstaluje |

## `[hyper]`

| Klíč | Typ | Default | Povolené | Poznámka |
|---|---|---|---|---|
| `key` | string | `"caps_lock"` | `caps_lock`, `f13`–`f20`, `right_cmd`, `right_option`; jiné → warning + default | fyzická klávesa hyperu |

## `[keybindings]`

Volná mapa: binding string → command string.

```toml
[keybindings]
"hyper-g" = "workspace 5"   # přidání
"hyper-p" = ""              # prázdný string = vypnutí defaultu
```

- Merguje se klíč po klíči s vestavěnými defaulty.
- Neparsovatelný command string zaloguje warning a binding se zahodí.
- Kompletní defaultní sada: [Ovládání](/ancre/cs/controls/).

## `[workspaces]`

Mapa: workspace → monitor matcher. Hodnota je buď **jeden string**, nebo
**pole** (priority list — vyhrává první připojený monitor):

```toml
[workspaces]
"1" = "Built-in"
"9" = ["PHL", "Built-in"]   # preferuj PHL, fallback Built-in
```

Matcher je stabilní ID monitoru (`vendor:model:serial`) nebo case-insensitive
část názvu monitoru. Entry s prázdným matcherem se zahodí s warningem.

## `[workspace-labels]`

Podklíč = workspace, hodnota = tabulka:

| Klíč | Typ | Default | Poznámka |
|---|---|---|---|
| `name` | string | — | vlastní label |
| `icon` | string | — | emoji/text před labelem |
| `show-number` | bool | `true` | zobrazit číslo workspace |
| `hide-when-empty` | bool | `false` | skrýt bez oken (aktivní workspace vždy vidět) |
| `layout` | string | `general.default-layout` | `dwindle` \| `scroll` \| `stack` \| název z `[custom-layouts]` |

## `[app-workspaces]`

Mapa: bundle ID → workspace pro nová okna. Bez validace.

```toml
[app-workspaces]
"com.spotify.client" = "9"
```

## `[custom-layouts]`

Mapa: název layoutu → šablona. Názvy rozšiřují množinu platných layoutů pro
`default-layout`, `workspace-labels.layout` a command `layout`. Gramatika
šablon: [Layouty](/ancre/cs/layouts/).

```toml
[custom-layouts]
"master" = "h(0.6, *, v(0.5, *, *))"
```

## `[theme]`

| Klíč | Typ | Default | Poznámka |
|---|---|---|---|
| `accent` | string | systémový accent | `"#RRGGBB"` / `"#RRGGBBAA"` |
| `background` | string | systémový materiál | sdílené pozadí ploch |

## `[bar]`

| Klíč | Typ | Default | Povolené / rozsah | Poznámka |
|---|---|---|---|---|
| `enabled` | bool | `true` | — | zapnutí baru |
| `position` | string | `"top"` | `top` \| `bottom` \| `left` \| `right` \| `menubar` \| `notch`; neplatné → warning + fallback | viz [Workspace bar](/ancre/cs/bar/) |
| `opacity` | číslo | `1.0` | 0–1 | průhlednost pozadí pillu |
| `height` | číslo | `28` | — | výška/tloušťka pruhu |
| `align` | string | `"center"` | `center` \| `left` \| `right` (nevalidováno) | umístění pillu podél hrany |
| `notch-side` | string | `"left"` | `left` \| `right` (nevalidováno) | strana notche pro pozici `menubar` |
| `offset-x` | číslo | `0` | — | posun podél hrany |
| `offset-y` | číslo | `0` | — | odsazení od hrany obrazovky |
| `background-color` | string | systémový materiál | `"#RRGGBB[AA]"` | pozadí pillu |
| `accent-color` | string | systémový accent | `"#RRGGBB"` | zvýraznění |
| `float-color` | string | bílá | `"#RRGGBB"` | čárkovaný ring floating oken |
| `badge-color` | string | systémová červená | `"#RRGGBB"` | notifikační badge |
| `icon-size` | číslo | `17` | — | velikost ikon appek |
| `font-size` | číslo | `13` | — | číslo workspace; label o 1 pt menší, badge ~polovina |
| `font-family` | string | systémový font | — | čísla monospaced, když unset |
| `spacing` | číslo | `6` | — | mezi workspace cellami |
| `cell-spacing` | číslo | `4` | — | uvnitř celly |
| `cell-radius` | číslo | `6` | — | zaoblení celly |
| `cell-padding-x` | číslo | `8` | — | |
| `cell-padding-y` | číslo | `3` | — | |
| `pill-padding-x` | číslo | `10` | — | |
| `pill-padding-y` | číslo | `3` | — | |
| `active-opacity` | číslo | `0.55` | — | zvýraznění aktivní workspace |
| `inactive-icon-opacity` | číslo | `0.75` | — | ikony nefokusovaných oken |
| `ring-width` | číslo | `1.5` | — | tloušťka focus/float ringu |
| `max-icons` | int | `6` | — | max ikon v celle |
| `peek` | bool | `false` | — | idle na `idle-opacity`, plně při drženém hyperu |
| `idle-opacity` | číslo | `0` | 0–1 | `0` = skrytý, `0.3` = ghost |

## `[bar-overrides]`

Per-monitor overrides klíčů `[bar]`. Podklíč = matcher: literál `"notch"`
matchuje monitory s notchem; jiný klíč je monitor matcher (přesná shoda
stabilního ID, nebo case-insensitive část názvu). Priorita: konkrétní
matcher > `notch` > základní `[bar]`. Matchery se procházejí abecedně,
aplikuje se první shoda.

Overridnout jde **jen tyto** klíče: `position`, `align`, `notch-side`,
`offset-x`, `offset-y`, `height`, `opacity`, `icon-size`, `font-size`,
`peek`, `idle-opacity`. Barvy, typografii a cell metriky per-monitor
přepsat nejde.

```toml
[bar-overrides.notch]
position = "notch"

[bar-overrides."PHL"]
align = "left"
icon-size = 17
```

## `[border]`

| Klíč | Typ | Default | Poznámka |
|---|---|---|---|
| `enabled` | bool | `true` | rámeček kolem fokusovaného okna |
| `color` | string | theme accent | `"#RRGGBB"` |
| `width` | číslo | `2` | tloušťka |
| `radius` | číslo | `10` | odpovídá systémovému radiusu oken |

## `[help]`

| Klíč | Typ | Default | Poznámka |
|---|---|---|---|
| `enabled` | bool | `true` | cheatsheet overlay |
| `delay-ms` | číslo | `2000` | jak dlouho držet hyper |
| `opacity` | číslo | `0.85` | |
| `font-size` | číslo | `11` | |
| `columns` | int | `3` | |
| `corner-radius` | číslo | `12` | |

## `[scratchpad]`

| Klíč | Typ | Default | Poznámka |
|---|---|---|---|
| `app` | string | unset (feature vypnutá) | bundle ID drop-down appky; spustí ji, když neběží |
| `width` | číslo | `0.6` | frakce šířky monitoru |
| `height` | číslo | `0.5` | frakce výšky monitoru |
| `command` | string | `open -n` na appku | shell příkaz, který otevře **nové** okno; scratchpad má vlastní okno, nikdy nepřebírá to, ve kterém pracuješ, a zůstává mimo tiling (žádná workspace, dlaždice ani záznam v baru/switcheru) |

## `[preview]`

| Klíč | Typ | Default | Poznámka |
|---|---|---|---|
| `color` | string | theme accent | barva drag&drop placeholderu |
| `opacity` | číslo | `0.3` | výplň budoucího slotu taženého okna |

## Shrnutí validace

- Clamp: `gaps-inner`/`gaps-outer` na ≥ 0; `animation-duration-ms` na
  50–500 ms.
- Validované s fallbackem: `default-layout`, `hyper.key`, `bar.position`,
  matchery `[workspaces]`, command stringy `[keybindings]`.
- **Nevalidované** (špatná hodnota projde a zlobí až u spotřebitele):
  `align`, `notch-side`, `language`, barevné stringy.
- `# [[rules]]` v `default.toml` je placeholder budoucí sekce window rules —
  loader ji zatím nečte.

:::caution
Chybějící klíč se nahradí vlastním defaultem a zbytek configu zůstane
zachovaný. Klíč se špatným *typem* rozbije dekódování celého souboru a celý
uživatelský config pro daný reload spadne na bundlované defaulty — ne jen
provinilý klíč. Výjimkou jsou číselné klíče výše: přijmou int i float, jinak
použijí vlastní default.
:::
