---
title: Architecture
description: Command bus, modules, and key invariants.
sidebar:
  order: 8
---

## Command bus

One path for every operation — nothing bypasses it:

```
hotkey / bar / mouse / IPC  →  Command  →  WM.dispatch(Command, state:)  →  [Effect]  →  AX layer
```

## Modules

| Module | Role |
|---|---|
| `WMCore` | pure state + reducer (WMState, Command, Effect). No AX/AppKit imports — unit-testable. Defines the `Layout` protocol and multi-monitor placement |
| `LayoutEngine` | layout implementations (dwindle, scroll, templates). Stateless value types |
| `AXBridge` | AXUIElement/AXObserver, window tracking, offscreen parking, DisplayManager (stable display IDs) |
| `InputSystem` | hidutil remap + CGEventTap; independent of WMCore, resolves only binding strings |
| `Bar` | SwiftUI workspace bar |
| `Config` | TOML schema + loader, validation with warnings (a config typo never crashes the app) |
| `App` | glue: AX ↔ WMCore ↔ Input |

## Key invariants

- **Threading**: all WM state lives on the axQueue (`AXRunLoopThread`).
  AXObserver callbacks hop there; state is never mutated from another
  context.
- **Parking**: macOS windows can't be hidden via public APIs, so hidden
  workspaces are "parked" past the edge of the union of all displays.
- **Coordinates**: AX = top-left origin, NSScreen = bottom-left; conversion
  happens in exactly one place (DisplayManager).
- **Monitor IDs**: hardware-derived `vendor:model:serial`, not
  `CGDirectDisplayID` (which changes between sessions).
- **Workspace placement is a pure function** (names, config, connected
  monitors) — a replug reproduces the same result.
- **Windows refusing a frame**: snap-back is limited to 3 attempts, then
  accepted.

Details and milestones: `CLAUDE.md` and `docs/PLAN.md` in the repository.
