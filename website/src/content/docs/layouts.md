---
title: Layouts
description: Dwindle, scroll, stack, and custom layouts from templates.
sidebar:
  order: 4
---

ancre ships three built-in layouts and a template language for custom ones.

## Built-in

- **dwindle** — binary splitting like Hyprland; every new window splits the
  leaf it's inserted after. The split axis follows that leaf's current
  aspect ratio — wider splits side by side, taller splits stacked — and a
  new split always starts at a 0.5 ratio; only a manual resize moves it.
  The default (`[general].default-layout`).
- **scroll** — columns side by side, inspired by scrolling layouts.
- **stack** — monocle: one window fills the screen, the rest sit behind it.

Switching: `hyper+t` (scroll), `hyper+shift+t` (dwindle), or generally
`ancrectl layout <name>`. Per-workspace layout is set in
`[workspace-labels]`.

## Custom layouts

The `[custom-layouts]` section — a template describes a split tree:

```toml
[custom-layouts]
"master" = "h(0.6, *, v(0.5, *, *))"
```

- `h(ratio, a, b)` — horizontal split (side by side) with the first slot's ratio
- `v(ratio, a, b)` — vertical split (stacked)
- `*` — a window slot

Windows fill slots in order; extras stack into the last slot. The layout name
then works everywhere built-ins do: `layout master` as a command, the
`layout` value in `[workspace-labels]`, a keybinding.

## Auto-stack

A workspace migrated to a monitor its windows don't fit on
(`count × auto-stack-min-width > monitor width`) temporarily switches to the
stack layout and back once space returns. On by default
(`[general].auto-stack`).

## Floating and fullscreen

`hyper+v` (`toggle-floating`) takes the focused window out of the tiling tree
so it keeps its own position and size; `hyper+f` (`toggle-fullscreen`) grows
it to fill the screen. Both are ordinary commands, so they also work from
`ancrectl` and the bar's right-click menu.

A window can also float itself: if it refuses the frame `ancre` assigns it
(a fixed minimum size, for example), `ancre` retries up to 3 times and then
gives up and floats the window instead of fighting it forever — the rest of
the tiling reflows around it as if it had never been tiled.

Gaps and the focus border are configured in `[general]` and `[border]` —
see [Configuration](/ancre/configuration/) and the
[config reference](/ancre/config-reference/).
