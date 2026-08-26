---
title: Architektura
description: Command bus, moduly a klíčové invarianty.
sidebar:
  order: 8
---

## Command bus

Jedna cesta pro každou operaci — nic ji neobchází:

```
hotkey / bar / myš / IPC  →  Command  →  WM.dispatch(Command, state:)  →  [Effect]  →  AX vrstva
```

## Moduly

| Modul | Role |
|---|---|
| `WMCore` | čistý stav + reducer (WMState, Command, Effect). Žádné AX/AppKit importy — unit-testable. Definuje `Layout` protokol a multi-monitor placement |
| `LayoutEngine` | implementace layoutů (dwindle, scroll, šablony). Stateless value typy |
| `AXBridge` | AXUIElement/AXObserver, window tracking, offscreen parking, DisplayManager (stabilní ID displejů) |
| `InputSystem` | hidutil remap + CGEventTap; nezávislý na WMCore, resolvuje jen binding stringy |
| `Bar` | SwiftUI workspace bar |
| `Config` | TOML schema + loader, validace s warningy (config typo nikdy neshodí app) |
| `App` | glue: AX ↔ WMCore ↔ Input |

## Klíčové invarianty

- **Threading**: veškerý WM stav žije na axQueue (`AXRunLoopThread`).
  AXObserver callbacky tam hoppují; nikdy se nemutuje z jiného kontextu.
- **Parking**: macOS okna nejde přes veřejné API skrýt, takže skryté
  workspaces se „parkují" za hranu unionu všech displayů.
- **Souřadnice**: AX = top-left origin, NSScreen = bottom-left; konverze
  jen na jednom místě (DisplayManager).
- **Monitor ID**: hardware-derived `vendor:model:serial`, ne
  `CGDirectDisplayID` (mění se mezi sessions).
- **Workspace placement je čistá funkce** (názvy, config, připojené
  monitory) — replug reprodukuje totéž.
- **Okna odmítající frame**: snap-back má limit 3 pokusů, pak se akceptuje.

Detaily a milestones: `CLAUDE.md` a `docs/PLAN.md` v repozitáři.
