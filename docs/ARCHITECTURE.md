# Architecture

> Nicer rendering: https://wraithyy.github.io/ancre/architecture/

Command bus: everything (hotkeys, bar, mouse, IPC) → `Command` →
`WM.dispatch(state:)` → `[Effect]` → the AX layer executes. One path per
operation, no side doors.

| Module | Role |
|---|---|
| `WMCore` | pure state + reducer; no AX/AppKit imports, fully unit-tested |
| `LayoutEngine` | dwindle / columns / stack / template layouts — stateless value types |
| `AXBridge` | AXObserver plumbing, window tracking, display management, offscreen parking |
| `InputSystem` | hidutil remap + CGEventTap, decoupled from WMCore |
| `Animator` | animated frame application with per-app latency fallback |
| `Bar` | SwiftUI bar + overlays, localization |
| `Config` | TOML schema, validation with warnings (never crashes on a typo) |
| `App` | glue: controller, IPC server, menu bar, onboarding |

Key invariant: all WM state lives on a single dispatch queue (`axQueue`).
Hidden workspaces are "parked" just past the edge of the display union —
macOS offers no public API to truly hide another app's window.

Deeper contributor rules (threading, coordinates, module boundaries):
[CONTRIBUTING.md](../CONTRIBUTING.md). Milestone history and backlog:
[PLAN.md](PLAN.md).

```sh
swift build && swift test    # 63 unit tests over WMCore/LayoutEngine/Config
```
