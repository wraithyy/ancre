# Contributing to ancre

Thanks for helping! ancre is a small codebase with strong invariants —
reading this first will save you a rejected review.

## Building & testing

Prerequisites: Xcode 16+ / Command Line Tools with Swift 6.0
(`swift-tools-version: 6.0`, language mode v5). The first build fetches the
TOMLKit dependency from the network. No linter/formatter is configured —
match the surrounding style by hand.

```sh
swift build            # whole package (SPM only, no .xcodeproj)
swift test             # unit tests: WMCore, LayoutEngine, Config
Scripts/bundle.sh      # builds .build/ancre.app (ad-hoc signed, stable identifier)
open .build/ancre.app
```

Runtime needs **Accessibility** and **Input Monitoring** permissions; the
onboarding window walks you through them. Re-show it anytime with
`ancre --onboarding`.

> ⚠️ Running the app remaps CapsLock→F18 (`hidutil`) and starts rearranging
> your real windows — don't test blindly on a machine you're working on.
> Revert a stuck remap: `hidutil property --set '{"UserKeyMapping":[]}'`.

## Ground rules

**Public API only.** No private CGS/SkyLight symbols, no SIP workarounds.
The single exception already in the tree is `_AXUIElementGetWindow`
(resolved via `dlsym`, degrades gracefully). If a feature needs more private
API, it doesn't go in.

**One command bus.** Every operation — hotkey, bar click, mouse drag, IPC —
becomes a `Command`, goes through `WM.dispatch(_:state:)`, and returns
`[Effect]` the AX layer executes. Never mutate windows from anywhere else.

**Threading invariant (the important one).** All WM state (WMState, caches
in the controller and WindowTracker) lives on the AX queue
(`AXRunLoopThread.shared`). AXObserver callbacks hop there; marshal with
`tracker.perform {}`. Never touch state from a Timer, notification handler,
or the event-tap thread. The CGEventTap callback must stay trivial
(dispatch-only) or macOS kills the tap on timeout.

**Module boundaries.**

| Module | Rule |
|---|---|
| `Sources/WMCore` | pure state + reducer. **No AX or AppKit imports** — must stay unit-testable |
| `Sources/LayoutEngine` | stateless value types implementing `Layout` |
| `Sources/AXBridge` | everything AXUIElement/AXObserver; the offscreen-parking workaround is isolated in `OffscreenParking.swift` on purpose |
| `Sources/InputSystem` | hidutil + CGEventTap; independent of WMCore (resolves binding strings via callback) |
| `Sources/Animator` | animated frame application (per-app latency fallback); depends on WMCore + AXBridge, keep it free of WM state |
| `Sources/Config` | TOML schema; a config typo must never crash — validate with warnings and fall back |
| `App/` | glue only |

**Coordinates.** AX uses top-left origin, NSScreen bottom-left. Convert
only in `DisplayManager` (`cgRect(fromNSScreenRect:primaryHeight:)`) —
nowhere else.

**Monitor identity.** Hardware-derived `vendor:model:serial`, never
CGDirectDisplayID (changes between sessions). Workspace placement is a pure
function of (workspace names, config, connected monitors) — no imperative
migration code.

**Swift language mode v5.** The AX C APIs aren't Sendable; don't switch to
v6 without a migration plan.

## Conventions

- Commit messages: `<type>: <description>` with types
  `feat, fix, refactor, docs, test, chore, perf, ci`.
- Comments explain *why*, not *what*; no emoji in code or commits.
- `ponytail:` comments mark deliberate shortcuts with a known ceiling —
  when touching nearby code, consider whether the ceiling is now hit.
- Command strings in config must stay in sync between `Command.parse`
  (`Sources/WMCore/WMCore.swift`) and `Sources/Config/default.toml` (which is also the user-facing
  key catalog — document new keys there).
- New UI strings go through `L10n` (both `en` and `cs` tables).

## Testing

Pure logic (WMCore, LayoutEngine, Config) gets unit tests — reducers and
layouts are value types, so this is cheap; do it. AX/Input runtime behavior
can't run in CI (needs permissions + a display session) and is verified
manually: build the bundle, run it, and exercise the affected path. Say in
the PR what you verified by hand.

## Pull requests

1. Branch from `main`, keep the diff focused.
2. `swift build && swift test` must pass.
3. Describe the manual verification for anything touching AX/Input/Bar.
4. Update `README.md` / `default.toml` if you added a feature or config key.

CI (`.github/workflows/ci.yml`) runs `swift build`, then `swift test`, then
`Scripts/bundle.sh` — a PR that builds fine but fails to bundle won't pass.

## Reporting bugs

Include: macOS version, monitor setup (count, notch, arrangement), the
relevant part of `~/.config/ancre/ancre.toml`, and log output
(`log stream --predicate 'process == "ancre"'`). If a window misbehaves,
`ancrectl state` output identifies it precisely.

## Versioning and releases

Releases are tag-driven: pushing a `vX.Y.Z` tag runs
`.github/workflows/release.yml`, which builds a universal (arm64 + x86_64)
bundle and publishes it as a GitHub Release with notes generated by
`gh release create --generate-notes`. There is no separate `CHANGELOG.md` —
GitHub Releases is the changelog.

## License and conduct

By contributing, you agree your contributions are licensed under the
project's [MIT License](LICENSE). Participation is governed by the
[Code of Conduct](CODE_OF_CONDUCT.md).
