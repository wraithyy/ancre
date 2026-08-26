# Architecture

> Nicer rendering: https://wraithyy.github.io/ancre/architecture/

Command bus: everything (hotkeys, bar, mouse, IPC) → `Command` →
`WM.dispatch(_ command: Command, state: inout WMState) -> [Effect]` → the AX
layer executes the effects. One path per operation, no side doors.

| Module | Role |
|---|---|
| `WMCore` | pure state + reducer; no AX/AppKit imports, fully unit-tested |
| `LayoutEngine` | dwindle / scroll / stack / template layouts — stateless value types |
| `AXBridge` | AXObserver plumbing, window tracking, display management, offscreen parking |
| `InputSystem` | hidutil remap + CGEventTap, decoupled from WMCore |
| `Animator` | animated frame application with per-app latency fallback |
| `Bar` | SwiftUI bar + overlays, localization |
| `Config` | TOML schema, validation with warnings (never crashes on a typo) |
| `ancrectl` | CLI executable — line-protocol client for the control socket, also the built-in MCP server |
| `App` | glue: controller, IPC server, menu bar, onboarding |

## No private frameworks — one documented exception

ancre uses only public Accessibility API — no private CGS/SkyLight calls, no
SIP tricks. The single exception: `Sources/AXBridge/AXWindow.swift` resolves
the private `_AXUIElementGetWindow` symbol via `dlsym` to get a stable
CGWindowID for an AXUIElement, since there is no public API for that
mapping. This is the same well-known exception every AX-based window manager
(yabai, Amethyst) relies on. Consequence: if the symbol is ever unavailable
(future macOS removing it), `resolveWindowID` returns `nil` and the window is
skipped rather than assigned a fabricated ID — a hash fallback would risk
mixing hash IDs with real CGWindowIDs and corrupting state.

## Coordinate systems

AX APIs (and `CGDisplayBounds`) use a top-left-origin, global coordinate
space. `NSScreen` reports frames in AppKit's bottom-left-origin space. The
two are mixed only where unavoidable (visible frame minus menu bar/Dock is
NSScreen-only), and the conversion happens in exactly one place:
`DisplayManager.cgRect(fromNSScreenRect:primaryHeight:)`. Nothing else in the
codebase is allowed to do this flip inline.

## Invariants

- **Threading**: all WM state (WMState, controller and WindowTracker caches)
  lives on a single dedicated serial queue, `axQueue`
  (`AXRunLoopThread.shared`). AXObserver callbacks hop onto it; the
  controller marshals other callers through `tracker.perform {}`. Never
  mutate state from another context (Timer, notification, tap thread). The
  CGEventTap callback must stay trivial — handler work dispatches async, or
  macOS kills the tap on timeout.
- **Offscreen parking**: hidden workspaces are "parked" just past the edge
  of the union of all displays — macOS offers no public API to truly hide
  another app's window. The workaround is isolated in
  `AXBridge/OffscreenParking.swift` (with a startup self-test) so a macOS
  update that changes clamp behavior only requires patching this one file.
- **Coordinates**: see above — conversion only in
  `DisplayManager.cgRect(fromNSScreenRect:primaryHeight:)`.
- **Monitor IDs**: stable, hardware-derived `vendor:model:serial` — not
  `CGDirectDisplayID`, which changes between sessions. Parking targets the
  union of all displays, not a single one.
- **Workspace placement**: a pure function of workspace names, config, and
  connected monitors (`WorkspaceAssignment.plan`) — replugging a monitor
  reproduces the same placement deterministically; there is no imperative
  migration state to drift.
- **Snap-back**: windows that refuse a requested frame are not fought
  indefinitely — after 3 refused attempts ancre accepts the window's own
  size and floats it, retrying tiling on the next retile.

Deeper contributor rules (threading, coordinates, module boundaries):
[CONTRIBUTING.md](../CONTRIBUTING.md). Milestone history and backlog:
[PLAN.md](PLAN.md).

```sh
swift build && swift test    # 63 unit tests over WMCore/LayoutEngine/Config
```
