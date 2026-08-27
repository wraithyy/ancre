# ancre — instructions for agents

Hyprland-inspired tiling window manager for macOS. Swift, public Accessibility
API, no SIP tampering. Detailed architecture and conventions: `CLAUDE.md`.
Plan and milestones: `docs/PLAN.md`.

## Before running anything — read this

The project is **macOS-only**: `AppKit`, `ApplicationServices` (AX API),
CoreGraphics display API. `Package.swift` has `platforms: [.macOS(.v14)]`.

In a Linux sandbox (default OpenHands runtime) **none of this compiles** —
`swift build` and `swift test` don't make sense there, and a missing
`import AppKit` is not a bug to fix. If you're running in a Linux container:

- edit Swift code surgically, without "fixing" macOS imports,
- don't change `Package.swift` platforms or the language mode (v5 is
  deliberate, see CLAUDE.md),
- state in your report that build/tests are **UNVERIFIED** (the maintainer
  runs them on a Mac).

There's no setup script — on Linux there's nothing to install, on macOS an
Xcode toolchain suffices (Swift 6.0, language mode v5).

## Build & test (macOS 14+ only)

```
swift build            # whole package
swift test              # unit tests (WMCore, LayoutEngine, Config)
Scripts/bundle.sh      # .build/ancre.app (ad-hoc signed)
```

No `.xcodeproj`. CI (`.github/workflows/`) runs on a `macos-15` runner:
`ci.yml` on push/PR to `main` (excluding changes limited to `website/`,
`docs/`, `*.md`) runs `swift build` → `swift test` → `Scripts/bundle.sh`;
`release.yml` on a `vX.Y.Z` tag builds a universal (arm64+x86_64) bundle and
publishes a GitHub Release; `deploy-docs.yml` deploys `website/` to GitHub
Pages (runs on `ubuntu-latest`, just an Astro build — unrelated to the Swift
code).

## NEVER launch the app automated

`open .build/ancre.app` does two global things: remaps **CapsLock→F18** via
`hidutil` and starts **rearranging every window** on the desktop. It requires
Accessibility + Input Monitoring permission and a live display session.

Revert the remap if the app already ran and left things in an odd state:

```
hidutil property --set '{"UserKeyMapping":[]}'
```

Runtime behavior (AX, event tap, displays) is verified **manually** on a Mac,
not in an agent run.

## What's testable and what isn't

| Layer | Verification |
|---|---|
| `Sources/WMCore`, `Sources/LayoutEngine`, `Sources/Config` | XCTest (`swift test`) — pure logic, add tests here |
| `Sources/AXBridge`, `Sources/InputSystem`, `App/` | manual testing on a Mac with permissions only |

When changing pure logic, add a test. When changing the AX/Input layer,
describe in your report the manual scenario the maintainer should use to
verify it (see `docs/PLAN.md`, Verification section).

## Structure

| Path | Role |
|---|---|
| `Sources/WMCore` | state + reducer (`WMState`, `Command`, `Effect`, multi-monitor placement). NO AX/AppKit imports allowed |
| `Sources/LayoutEngine` | layouts (`DwindleLayout`), stateless value types |
| `Sources/AXBridge` | AXUIElement/AXObserver, `WindowTracker`, `DisplayManager`, `OffscreenParking` |
| `Sources/InputSystem` | hidutil remap, CGEventTap |
| `Sources/Config` | TOMLKit schema, `~/.config/ancre/ancre.toml` |
| `Sources/Animator` | window rearrangement animations |
| `Sources/Bar` | workspace bar (menu bar / notch) |
| `App/` | executable target `ancre`: `main.swift` + `WindowManagerController` (glue) |
| `ancrectl` | executable target, CLI client for socket/MCP |

## Two things the docs would lie about if you didn't read this

1. **"No private API"** holds with one deliberate exception:
   `_AXUIElementGetWindow` via `dlsym` in `Sources/AXBridge/AXWindow.swift`
   (the only way to get a stable `CGWindowID`, every AX window manager does
   this). Don't rewrite it, don't report it as a finding.
2. **Threading**: all WM state lives on `axQueue` (`AXRunLoopThread.shared`).
   Never mutate state from a Timer, notification, or tap thread. The
   CGEventTap callback must stay trivial, otherwise the system kills it on
   timeout.
