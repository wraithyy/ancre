---
title: Multi-monitor
description: Stable workspace-to-monitor assignment, migration, and replug.
sidebar:
  order: 5
---

Workspaces 1–9 spread across monitors with **stable assignment** that
survives display unplug and replug.

## Assigning workspace → monitor

```toml
[workspaces]
"1" = "Built-in"
"9" = "P34w-20"
```

The value is either the **stable monitor ID** (`vendor:model:serial` — logged
at startup, copy it with a click in the ◱ menu bar menu) or **part of the
display name**.

## Behaviour

- Unlisted workspaces spread over the remaining displays.
- A workspace whose display disconnects moves to a connected one and
  **returns on replug** — placement is a pure function (workspace names,
  config, connected monitors), no imperative migration, so a replug always
  reproduces the same result.
- The monitor ID is hardware-derived, not `CGDirectDisplayID` (which changes
  between sessions).

## Focus across monitors

`hyper+,` / `hyper+.` moves focus to the previous/next monitor. The bar has
per-monitor overrides (`[bar-overrides.*]`) — see [Bar](/ancre/bar/).
