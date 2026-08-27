---
title: Workspace bar
description: Bar positions including the menu bar and the notch, appearance, per-monitor overrides.
sidebar:
  order: 6
---

The bar shows workspaces with window icons and notification badges, and
supports drag&drop. Everything is driven by the `[bar]` section.

![The ancre workspace bar sitting in the menu bar, dark theme](../../assets/ancre-menubar-preview-dark.png)

<!-- media (shotlist: bar.md):
![The bar tucked under the notch on a MacBook display](../../assets/bar-notch.png)
![Clicking a workspace in the bar switches to it](../../assets/bar-workspace-click.gif)
![Bar indicator states: active vs. inactive workspace](../../assets/bar-states.png)
-->


## Position

```toml
[bar]
enabled = true
position = "top"   # top | bottom | left | right | menubar | notch
```

- `top` / `bottom` / `left` / `right` — reserve a strip at the screen edge
  (left/right = vertical bar, `height` is its thickness).
- `menubar` — the pill lives **inside** the system menu bar band, so no
  tiling space is lost. On a notched display it sits beside the notch
  (`notch-side = "left" | "right"`).
- `notch` — the bar is hidden entirely; hovering the notch slides the pill
  out under it.

## Placement and peek

```toml
align = "center"   # center | left | right
offset-x = 0       # shifts the pill along the edge
offset-y = 0       # pushes the strip away from the screen edge
# peek = false     # bar idles at idle-opacity and shows fully while hyper is held
# idle-opacity = 0 # 0 = hidden, 0.3 = ghost
```

## Appearance

```toml
opacity = 1.0        # pill background 0..1 (the native material is already translucent)
height = 28
# background-color = "#1e1e2eCC"   # [theme] override just for the bar
# accent-color = "#89b4fa"
# float-color = "#FFFFFF"          # dashed ring marking floating windows
# badge-color = "#FF3B30"
# font-size = 13     # workspace number; label 1pt smaller, badge ~half
# font-family = ""   # unset = system font (numbers monospaced)
# icon-size, spacing, cell-spacing, cell-radius, cell-padding-x/y,
# pill-padding-x/y, active-opacity, inactive-icon-opacity, ring-width, max-icons
```

## Per-monitor overrides

`[bar-overrides.<matcher>]` overrides `[bar]` keys for a specific monitor.
The matcher is a stable ID or a name substring; the key `notch` matches
notched displays. Priority: specific matcher > `notch` > base `[bar]`.

```toml
[bar-overrides.notch]
position = "notch"

[bar-overrides."PHL"]
align = "left"
icon-size = 17
```
