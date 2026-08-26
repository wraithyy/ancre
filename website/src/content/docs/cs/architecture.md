---
title: Architektura
description: Command bus, moduly a klíčové invarianty.
sidebar:
  order: 8
---

Tahle stránka popisuje architekturu ancre na vysoké úrovni: jediný command
bus, přes který prochází každý vstup, hranice modulů ve Swift package a
invarianty, které drží multi-threaded AX stav bezpečný.

## Command bus

Jedna cesta pro každou operaci — nic ji neobchází:

```text
hotkey / bar / mouse / IPC  →  Command  →  WM.dispatch(Command, state:)  →  [Effect]  →  AX layer
```

## Moduly

| Modul | Role |
|---|---|
| `WMCore` | čistý stav + reducer (WMState, Command, Effect). Žádné AX/AppKit importy — unit-testable. Definuje `Layout` protokol a multi-monitor placement |
| `LayoutEngine` | implementace layoutů (dwindle, scroll, šablony). Stateless value typy |
| `AXBridge` | AXUIElement/AXObserver, window tracking, offscreen parking, DisplayManager (stabilní ID monitorů) |
| `InputSystem` | hidutil remap + CGEventTap; nezávislý na WMCore, resolvuje jen binding stringy |
| `Animator` | animace okenních framů, řízená effecty z WMCore |
| `Bar` | SwiftUI workspace bar |
| `Config` | TOML schema + loader, validace s warningy (config typo nikdy neshodí app) |
| `ancrectl` | CLI + vestavěný MCP server, komunikuje s běžící app přes unix socket — viz [Skriptování a AI](/ancre/cs/scripting/) |
| `App` | glue: AX ↔ WMCore ↔ Input |

## Klíčové invarianty

- **Threading**: veškerý WM stav žije na axQueue (`AXRunLoopThread`).
  AXObserver callbacky tam hoppují; nikdy se nemutuje z jiného kontextu.
- **Parking**: macOS okna nejde přes veřejné API skrýt, takže skryté
  workspaces se „parkují” za hranu unionu všech monitorů.
- **Souřadnice**: AX = top-left origin, NSScreen = bottom-left; konverze
  jen na jednom místě (DisplayManager).
- **Monitor ID**: hardware-derived `vendor:model:serial`, ne
  `CGDirectDisplayID` (mění se mezi sessions).
- **Workspace placement je čistá funkce** (názvy, config, připojené
  monitory) — replug reprodukuje totéž.
- **Okna odmítající frame**: snap-back má limit 3 pokusů, pak se akceptuje.

Detaily threadingu: `CONTRIBUTING.md` v repozitáři. Milestones:
`docs/PLAN.md`.
