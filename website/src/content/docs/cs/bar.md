---
title: Workspace bar
description: Pozice bar včetně menubaru a notche, vzhled, per-monitor overrides.
sidebar:
  order: 6
---

Bar zobrazuje workspaces s ikonkami oken, badge notifikací a podporuje
drag&drop. Vše řídí sekce `[bar]`.

## Pozice

```toml
[bar]
enabled = true
position = "top"   # top | bottom | left | right | menubar | notch
```

- `top` / `bottom` / `left` / `right` — rezervují pruh na hraně obrazovky
  (left/right = vertikální bar, `height` je jeho tloušťka).
- `menubar` — pill žije **uvnitř** systémového menu baru, žádná plocha pro
  tiling se neztrácí. Na displeji s notchem sedí vedle notche
  (`notch-side = "left" | "right"`).
- `notch` — bar je skrytý úplně; najetí myší na notch vysune pill pod ním.

## Umístění a peek

```toml
align = "center"   # center | left | right
offset-x = 0       # posun pillu podél hrany
offset-y = 0       # odsazení pruhu od hrany obrazovky
# peek = false     # bar idluje na idle-opacity a plně se ukáže při drženém hyperu
# idle-opacity = 0 # 0 = skrytý, 0.3 = ghost
```

## Vzhled

```toml
opacity = 1.0        # pozadí pillu 0..1 (nativní materiál je už průsvitný)
height = 28
# background-color = "#1e1e2eCC"   # override [theme] jen pro bar
# accent-color = "#89b4fa"
# float-color = "#FFFFFF"          # čárkovaný ring floating oken
# badge-color = "#FF3B30"
# font-size = 13     # číslo workspace; label o 1pt menší, badge ~polovina
# font-family = ""   # unset = systémový font (čísla monospaced)
# icon-size, spacing, cell-spacing, cell-radius, cell-padding-x/y,
# pill-padding-x/y, active-opacity, inactive-icon-opacity, ring-width, max-icons
```

## Per-monitor overrides

`[bar-overrides.<matcher>]` přepisuje klíče `[bar]` pro konkrétní monitor.
Matcher je stabilní ID nebo část názvu; klíč `notch` matchuje displeje
s notchem. Priorita: konkrétní matcher > `notch` > základní `[bar]`.

```toml
[bar-overrides.notch]
position = "notch"

[bar-overrides."PHL"]
align = "left"
icon-size = 17
```
