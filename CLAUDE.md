# ancre

Hyprland-inspired tiling window manager for macOS. Swift, pure public
Accessibility API — no private CGS/SkyLight API, no SIP tampering.
Plan + milestones: `docs/PLAN.md` (M1–M8 done; backlog remains — command
palette, config hooks). `AGENTS.md` = same instructions for
external agents (OpenHands), mainly what can't be verified in a Linux sandbox.

## Build & test

```
swift build            # whole package
swift test              # unit tests (WMCore, LayoutEngine, Config)
Scripts/bundle.sh      # builds .build/ancre.app (ad-hoc signed, stable identifier)
open .build/ancre.app
```

No `.xcodeproj` — plain SPM + bundle script. Runtime requires Accessibility
(+ Input Monitoring) permission; without it the app waits and spams
AXIsProcessTrusted. Watch out: launching the app remaps CapsLock→F18 (hidutil)
and starts rearranging windows — don't test headlessly. Revert:
`hidutil property --set '{"UserKeyMapping":[]}'`.

## Architecture

Command bus: everything (hotkey, bar, drag&drop) → `Command` enum →
`WM.dispatch(Command, state:)` → `[Effect]` → the AX layer executes the effects.
One path for every operation, no bypassing.

| Module | Role |
|---|---|
| `Sources/WMCore` | pure state + reducer (WMState, Command, Effect). NO AX/AppKit imports allowed — must stay unit-testable. Defines the `Layout` protocol; `Monitor.swift` = multi-monitor placement (`WorkspaceAssignment.plan`, `WM.reconcileMonitors`) |
| `Sources/LayoutEngine` | layout implementations (DwindleLayout; scroll = M5). Stateless value types |
| `Sources/AXBridge` | AXUIElement/AXObserver, WindowTracker + delegate, DisplayManager (stable display IDs + reconfiguration), OffscreenParking (parking workaround isolated HERE — if a macOS update breaks it, only this file needs patching) |
| `Sources/InputSystem` | hidutil remap, CGEventTap. Independent of WMCore — resolves only binding strings ("hyper-shift-h") via callback |
| `Sources/Config` | TOMLKit schema + loader, `~/.config/ancre/ancre.toml`, validation with warnings (never crash on a config typo) |
| `Sources/Animator` | window rearrangement animations, depends on WMCore + AXBridge |
| `Sources/Bar` | workspace bar (menu bar / under the notch), depends on WMCore |
| `App/` | executable target `ancre`: main.swift + WindowManagerController (AX↔WMCore↔Input glue) |
| `ancrectl` | executable target, CLI client (socket/MCP) |

## Threading — the most important invariant

All WM state (WMState, caches in both the controller and WindowTracker) lives
on **axQueue** (`AXRunLoopThread.shared`, AXBridge). AXObserver callbacks hop
there, the controller marshals through `tracker.perform {}`. Never mutate
state from another context (Timer, notification, tap thread). The CGEventTap
callback must stay trivial (otherwise the system kills it on timeout).

## Conventions

- Swift language mode v5 (AX C APIs aren't Sendable; don't switch to v6 without a plan)
- `AXWindowID` (UInt32, CGWindowID) ↔ `WMCore.WindowID` is a 1:1 mapping
- Coordinates: AX = top-left origin, NSScreen = bottom-left; convert ONLY in
  `DisplayManager.cgRect(fromNSScreenRect:primaryHeight:)`
- Monitor ID: hardware-derived `vendor:model:serial` (not CGDirectDisplayID,
  which changes between sessions). Parking targets the union of all displays,
  not a single one
- Workspace placement is a pure function (workspace names, config, connected
  monitors) → replug reproduces the same result; no imperative migration
- Windows refusing a frame: don't fight it — snap-back has a 3-attempt limit,
  then accept it
- `ponytail:` comments = deliberate shortcuts with a known ceiling; consider
  when touching nearby code
- Keep command strings in config ↔ `Command.parse` in sync with
  `Sources/Config/default.toml`
- Tests: pure logic (WMCore/LayoutEngine/Config) has unit tests; AX/Input
  runtime behavior is verified manually (requires permissions + a display
  session)
