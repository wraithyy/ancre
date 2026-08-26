---
title: Layouts
description: Dwindle, scroll, stack, and custom layouts from templates.
sidebar:
  order: 4
---

ancre ships three built-in layouts and a template language for custom ones.

## Built-in

- **dwindle** — binary splitting like Hyprland; every new window halves the
  largest slot. The default (`[general].default-layout`).
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
