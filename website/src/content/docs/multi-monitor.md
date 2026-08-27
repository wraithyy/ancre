---
title: Multi-monitor
description: Stable workspace-to-monitor assignment, migration, and replug.
sidebar:
  order: 5
---

Workspaces 1–9 spread across monitors with **stable assignment** that
survives display unplug and replug: unplug at the office, replug at home,
and every workspace lands back on the monitor you assigned it to.

<!-- media (shotlist: multi-monitor.md):
![Two monitors, each with its own workspace and bar](../../assets/multi-monitor-two-displays.png)
![Moving a window between monitors](../../assets/multi-monitor-move-window.gif)
![Unplugging and replugging a monitor — windows reflow and return](../../assets/multi-monitor-replug.gif)
-->


## Assigning workspace → monitor

```toml
[workspaces]
"1" = "Built-in"
"9" = "P34w-20"
```

The value is either the **stable monitor ID** (`vendor:model:serial` — logged
at startup, copy it with a click in the ◱ menu bar menu) or **part of the
display name**.

It can also be an array — a priority list where the first connected monitor
wins, so the same config works at home and at the office:

```toml
[workspaces]
"1" = ["PHL", "P34w"]   # prefer PHL, fall back to P34w
```

:::caution
Cheap panels often report serial `0`. Two identical panels with the same
matcher then collide — `ancre` disambiguates by adding a positional suffix
(`#1`, `#2`, ...) to the second one. Reordering the displays swaps which
panel gets which suffix, which swaps their workspaces.
:::

## Behavior

- Unlisted workspaces spread over the remaining displays.
- A workspace whose display disconnects moves to a connected one and
  **returns on replug** — placement is a pure function (workspace names,
  config, connected monitors), no imperative migration, so a replug always
  reproduces the same result.
- The monitor ID is hardware-derived, not `CGDirectDisplayID` (which changes
  between sessions).
- Sleep or a closed lid can report zero connected displays; when that
  happens `ancre` leaves the current arrangement untouched instead of
  reassigning workspaces, so everything is back where it was on wake.
- Focus follows the workspace by name: moving focus to a monitor focuses
  whichever workspace is currently active on it, not a fixed workspace
  number.

## Focus across monitors

`hyper+,` / `hyper+.` moves focus to the previous/next monitor. The bar has
per-monitor overrides (`[bar-overrides.*]`) — see [Bar](/ancre/bar/).
