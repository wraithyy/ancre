# ancre — Hyprland-inspired tiling WM for macOS

## Context

macOS has no tiling WM with Hyprland's ergonomics. Existing tools: yabai
(requires SIP tampering, fragile), AeroSpace (stable, but no animations, bar,
or mouse modes). Goal: a custom WM from scratch in Swift on top of the public
Accessibility API — stability and ergonomics as priorities, full control over
layouts, the bar, and UX.

**Decisions from the grill phase (approved by the user):**
- From scratch, Swift, public AX API — no private API, no SIP tampering
- Virtual workspaces (AeroSpace style: hidden windows pushed off-viewport),
  per monitor
- Hyper key built in: hidutil remap CapsLock→F18 + CGEventTap, all
  configurable
- Custom SwiftUI bar per monitor, alongside the system menu bar
- Adaptive animations: 150–200 ms easing, per-app latency (EMA), auto-off for
  slow apps

## Requirements

- **Layouts**: dwindle (Hyprland default) + niri-style scroll columns;
  `LayoutEngine` protocol for custom layouts, switchable per workspace
- **Keyboard** (all remappable in TOML): hyper+hjkl focus,
  hyper+shift+hjkl move window, hyper+arrows resize, hyper+1..9 workspace,
  hyper+shift+1..9 move window to workspace, toggle floating, toggle
  fullscreen
- **Mouse**: hyper+left-drag move/float, hyper+right-drag resize; "release"
  mode = window pulled out of the grid, freely movable
- **Workspaces**: per monitor, stable monitor IDs (name+serial via IOKit, not
  CGDirectDisplayID); on monitor disconnect, migrate workspaces to the
  remaining ones, migrate back on reconnect
- **TOML config**: keybinds, workspace→monitor, app→workspace rules,
  animations, gaps, layouts; hot-reload (FSEvents)
- **Bar**: workspaces + app icons, click-to-switch, drag&drop windows between
  workspaces, right-click menu
- **Performance**: event-driven (AXObserver, NSWorkspace notifications,
  CGDisplay callbacks), no polling, cache AX reads

## Architecture

Plain SPM package + `Scripts/bundle.sh` (ad-hoc signature, stable bundle
identifier for permission prompts) — an Xcode project turned out to be
unnecessary, the bundle script does the same thing without .pbxproj
conflicts. Menu bar app, unsandboxed, permissions: Accessibility + Input
Monitoring. Dependency: **TOMLKit** (SPM).

```
ancre/
  App/                    AppDelegate, menu bar, permission onboarding
  Sources/AXBridge/       AXUIElement/AXObserver, window cache, DisplayManager, OffscreenParking
  Sources/WMCore/         window tree, workspace model, focus state — pure logic, unit-testable
  Sources/LayoutEngine/   Protocol.swift, Dwindle.swift, ScrollColumns.swift
  Sources/InputSystem/    CGEventTap, hidutil lifecycle, mouse modes
  Sources/Bar/            SwiftUI overlay windows per monitor
  Sources/Config/         TOMLKit schema, validation, hot-reload
  Sources/Animator/       CVDisplayLink interpolation, per-app latency EMA
  Sources/Config/default.toml
  Scripts/bundle.sh, Scripts/Info.plist
```

**Status**: M1–M8 done (tiling, multi-monitor, bar, animations, layouts,
theming, mouse modes, IPC/MCP/AI). Start-at-login goes through
`SMAppService.mainApp` (menubar toggle) -- no LaunchAgent plist needed.
Backlog: command palette in the switcher, config hooks, hidutil re-apply
after wake, true infinite scroll, layout edit mode, rule-learning phase 2.

**Threading**: a single dedicated serial `axQueue` owns all AX work
(AXObserver runloop source) as well as WMCore state mutations — no races
between events and commands. UI and the event tap marshal into it async.

**Command bus**: everything (hotkey, bar click, drag&drop) produces a
`Command` enum → `WMCore.dispatch(Command)`. One path for every operation.

**Key techniques** (details for implementers):
- Discovery: `NSWorkspace.didLaunchApplicationNotification` →
  `AXUIElementCreateApplication(pid)` → AXObserver on
  `kAXWindowCreated/UIElementDestroyed/FocusedWindowChanged/Moved/Resized/Miniaturized`;
  existing windows via `kAXWindowsAttribute`
- Move/resize: set position+size, re-read the actual frame, 1 retry on
  divergence; windows that refuse resize → auto-float
- Anti-self-resize: 50–100 ms debounce on Moved/Resized, compare against the
  expected tiled frame, snap back (flag against own commands to avoid a
  feedback loop)
- Off-viewport parking: macOS clamps positions — workaround (offset past the
  edge + shrink/move/restore as needed) isolated in `OffscreenParking.swift`
  + a self-test at startup
- Event tap: handle `.tapDisabledByTimeout/.tapDisabledByUserInput` →
  immediate re-enable; callback just dispatches async
- hidutil: apply at startup, re-apply after sleep/USB keyboard swap
  (IOHIDManager notifications)
- Animations: CVDisplayLink, 150–200 ms easing, per-bundle-id EMA latency
  setFrame→AXResized; EMA > frame budget → instant-only
- Bar drag&drop: SwiftUI `Transferable` (window id + source workspace) →
  `Command.moveWindowToWorkspace`

## Risks

| Risk | Mitigation |
|---|---|
| AX flakiness (Electron, Java) | per-app EMA, retry-once, TOML float-by-default list |
| Windows refusing resize | detect divergence → auto-float, don't fight it |
| macOS update changes clamp behavior | workaround isolated in OffscreenParking + startup self-test + diagnostics |
| Event tap killed by the system | re-enable handler, non-blocking callback |
| Performance with many windows | event-driven, cache, rebuild the layout only on structural change |

## Tasks

The "DONE" status on M1–M8 means varying degrees of verification depending on
the module: unit tests cover only WMCore/LayoutEngine/Config (`swift test`,
63 tests); AXBridge, InputSystem, Bar, Animator, and App require
Accessibility/Input Monitoring permissions and a display session, so they're
verified manually (see notes on individual tasks — "runtime verified" vs
"code done, runtime verification pending").

### Milestone 1 — MVP (single monitor, dwindle, hotkeys, workspaces)

#### Task 1.1: Set up SPM package + modules + TOMLKit — DONE
- **Agent**: claude
- **Files**: full skeleton per the tree above, App/, Package.swift, Scripts/Info.plist
- **Depends on**: none
- **Acceptance**: `swift build` passes; the app launches as a menu bar item; permission onboarding requests Accessibility
- **Prompt seed**: Set up the ancre Xcode project (menu bar app, unsandboxed, LSUIElement), local SPM modules AXBridge/WMCore/LayoutEngine/InputSystem/Config/Animator/Bar, TOMLKit dependency, Info.plist with usage descriptions, AXIsProcessTrustedWithOptions onboarding.

#### Task 1.2: AXBridge — window discovery and tracking
- **Agent**: claude
- **Files**: Sources/AXBridge/ (AXObserverManager.swift, WindowCache.swift, AXWindow.swift)
- **Depends on**: 1.1
- **Acceptance**: a debug log shows live: app launch/terminate, created/destroyed/focused/moved/resized windows, enumeration of existing windows at startup
- **Prompt seed**: Implement the AX layer on a dedicated axQueue: NSWorkspace notifications → AXUIElementCreateApplication → AXObserver (windowCreated, uiElementDestroyed, focusedWindowChanged, moved, resized, miniaturized), frame cache, enumerate kAXWindowsAttribute at startup.

#### Task 1.3: WMCore — window tree, workspace model, Command bus
- **Agent**: claude
- **Files**: Sources/WMCore/ (LayoutTree.swift, Workspace.swift, Monitor.swift, Command.swift, WM.swift), Tests/WMCoreTests/
- **Depends on**: none (pure logic, parallel with 1.2)
- **Acceptance**: unit tests: dwindle tree insert/remove/swap/focus-neighbor, workspace assignment; `swift test` green
- **Prompt seed**: Pure state model with no AX dependencies: recursive LayoutTree (leaf/split), Workspace with a layout, Monitor with ordered workspaces, Command enum + dispatch. Tests on tree operations and hjkl navigation.

#### Task 1.4: LayoutEngine — protocol + Dwindle
- **Agent**: claude
- **Files**: Sources/LayoutEngine/ (Protocol.swift, Dwindle.swift), tests
- **Depends on**: 1.3
- **Acceptance**: unit test: N windows → correct frames with gaps for given viewport dimensions
- **Prompt seed**: LayoutEngine protocol (windows+viewport+gaps → frames, insert/remove/move/resize hooks), Dwindle implementation (Hyprland semantics: alternating split, split ratio).

#### Task 1.5: InputSystem — hidutil remap + CGEventTap + default binds
- **Agent**: claude
- **Files**: Sources/InputSystem/ (EventTapManager.swift, HidutilRemap.swift, Keybinding.swift)
- **Depends on**: 1.3
- **Acceptance**: CapsLock works as hyper; hyper+hjkl/shift+hjkl/1..9 emit the correct Command; the tap survives a timeout disable (re-enable logged)
- **Prompt seed**: hidutil UserKeyMapping CapsLock→F18 (apply at startup, revert on quit, re-apply after wake/IOHID change), CGEventTap with re-enable handling, mapping combinations to the Command enum.

#### Task 1.6: Integration — tiling enforcement + focus + virtual workspaces
- **Agent**: claude
- **Files**: Sources/AXBridge/OffscreenParking.swift, Sources/WMCore/WM.swift, App/ wiring
- **Depends on**: 1.2, 1.4, 1.5
- **Acceptance**: manual: 4 windows tile, hyper+hjkl switches focus, hyper+shift+hjkl swaps, hyper+2 hides/restores a workspace instantly, a self-resized window snaps back
- **Prompt seed**: Wire AX events → WMCore → layout → AX setFrame. Anti-self-resize debounce+snapback, setting focus (AXFocused + NSRunningApplication.activate), OffscreenParking with a startup self-test.

#### Task 1.7: Config — TOML schema + loading keybinds
- **Agent**: claude
- **Files**: Sources/Config/ (Schema.swift, Loader.swift), Resources/default.toml
- **Depends on**: 1.5
- **Acceptance**: binds from ~/.config/ancre/ancre.toml override the defaults; an invalid config → a readable error, falls back to defaults
- **Prompt seed**: TOMLKit schema: [keybindings], [general] (gaps, animations on/off), configurable hyper key. Validation with error messages.

#### Task 1.R: Review milestone 1
- **Agent**: code-reviewer
- **Files**: everything from M1
- **Depends on**: 1.6, 1.7
- **Acceptance**: no CRITICAL/HIGH findings
- **Prompt seed**: Review threading (is everything AX on axQueue?), AXObserver retain cycles, event tap safety, feedback loops in anti-self-resize.

### Milestone 2 — Multi-monitor

#### Task 2.1: Stable monitor ID + workspace→monitor assignment + migration — DONE (runtime verified 2026-08-25, built-in + P34w-20)
- **Agent**: claude
- **Files**: Sources/WMCore/Monitor.swift, Sources/AXBridge/DisplayManager.swift, Config schema extension
- **Depends on**: 1.R
- **Acceptance**: manual: disconnecting an external monitor moves its workspaces to the built-in one, reconnecting brings them back; TOML `[workspaces]` assignment is respected
- **Prompt seed**: IOKit/CGDisplayCreateInfoDictionary stable ID, CGDisplayRegisterReconfigurationCallback, workspace migration preserving layouts, hyper+, / hyper+. to focus a monitor.

**Deviations from the seed during implementation:**
- Stable ID: `CGDisplayVendorNumber/ModelNumber/SerialNumber` (simpler than
  parsing `CGDisplayCreateInfoDictionary`, equally stable). Panels with
  serial number 0 get a positional `#n` suffix.
- Reconfiguration: `NSApplication.didChangeScreenParametersNotification`
  with 300 ms coalescing instead of `CGDisplayRegisterReconfigurationCallback`
  — AppKit only sends it once the configuration has settled, no C callback
  or begin/end flag filtering needed. The CG callback fallback is documented
  in DisplayManager.
- Instead of imperative migration, placement is a pure function
  (`WorkspaceAssignment.plan`): a workspace goes to its own monitor when
  connected, otherwise to the first connected one. Replug thereby reproduces
  the same result without a "migrate back" state that could drift.
- Unintended side findings fixed here, since the multi-monitor work exposed
  them: `workspace N` / `move-to-workspace N` now search for the workspace
  across all monitors (previously only on the focused one = no-op); moving a
  window to a hidden workspace now parks it (previously stayed visible);
  parking targets the union of displays (parking past the edge of one
  display used to spill the window onto a neighboring one).

**Findings from runtime verification (fixed):**
- Config: TOML `gaps-inner = 8` (Int) failed strict Double decoding →
  fatalError on the bundled defaults. Lenient Int→Double decode added in
  `General`.
- macOS asynchronously "rescues" offscreen windows when a monitor
  disconnects → pulled parked windows back visible onto the remaining
  display. The controller now tracks the parked set and re-parks any window
  that escapes (3-attempt limit).
- Bonus, outside the 2.1 scope: focus border (`App/FocusBorder.swift`) — an
  overlay with an accent outline around the focused window; without it focus
  wasn't visible.

### Milestone 3 — Workspace bar

#### Task 3.1: SwiftUI bar per monitor (display + click-to-switch) — DONE (code, runtime verification by the user pending)
- **Agent**: claude
- **Files**: Sources/Bar/
- **Depends on**: 2.1
- **Acceptance**: the bar on every monitor shows workspaces + app icons live, clicking switches
- **Prompt seed**: NSWindow (borderless, .statusBar level, canJoinAllSpaces) per monitor, SwiftUI content subscribing to the WMCore state stream, NSRunningApplication.icon.

#### Task 3.2: Bar interactions — drag&drop + right-click menu — DONE (code, runtime verification by the user pending)
- **Agent**: claude
- **Files**: Sources/Bar/
- **Depends on**: 3.1
- **Acceptance**: dragging a window icon to another workspace moves it; right-click: move/float/close
- **Prompt seed**: Transferable with window id, dropDestination → Command.moveWindowToWorkspace, context menu emitting Commands.

### Milestone 4 — Animations

#### Task 4.1: Animator — adaptive interpolation — DONE (code; DispatchSourceTimer at 60 Hz instead of CVDisplayLink — the timer only runs during animations, 0% idle)
- **Agent**: claude
- **Files**: Sources/Animator/
- **Depends on**: 1.R
- **Acceptance**: fast apps animate smoothly; an app with artificially slow AX (test) auto-switches to instant; the TOML toggle works
- **Prompt seed**: CVDisplayLink loop, ease-out 150–200 ms, per-bundle-id EMA latency setFrame→AXResized, threshold → instant-only, coordination with the anti-self-resize flag.

### Milestone 5 — niri layout + custom layouts

#### Task 5.1: ScrollColumns layout + per-workspace switching — DONE (code; + TemplateLayout for custom layouts from config; edit mode for custom layouts = future task)

**Future extension — true niri scroll (infinite strip):** the columns
layout today always scales widths so every window fits on the monitor. A
viewport variant (e.g. 20 windows, 4 visible, fixed column widths) is
feasible: park columns outside the viewport (the infrastructure already
exists — splitVisible parks off-monitor frames, focus unparks them), the
anchor mechanic existed in the first ScrollColumnsLayout iteration (git
history, commit 072ed40^). Back then it looked like "windows vanishing" —
smooth sliding was missing. With the Animator (M4), scroll would look
natural: on an anchor change, animate the shift of all visible columns and
only park once it settles. Watch out for: the edge next to a neighboring
monitor (columns must not overflow — handled by a "whole thing out" clamp),
nearestNeighbor across parked columns (leave them their natural coordinates
past the edge), and the bar (should show even parked windows).
- **Agent**: claude
- **Files**: Sources/LayoutEngine/ScrollColumns.swift, Config extension
- **Depends on**: 1.R
- **Acceptance**: workspace in niri mode: columns, horizontal scroll follows focus, hyper+hjkl navigates; hot-switching the layout with no restart
- **Prompt seed**: Niri semantics: ordered columns, windows within a column stacked vertically, viewport scrolls with focus. Document the LayoutEngine protocol as a plugin API.

### Milestone 6 — Polish

#### Task 6.1: App→workspace rules + config reload — DONE (runtime verified; [app-workspaces] rules + explicit "Reload config" in the menubar menu instead of an FSEvents watch — deliberate decision, see deviations)
- **Agent**: claude
- **Files**: Sources/Config/, Sources/WMCore/Rules.swift
- **Depends on**: 2.1
- **Acceptance**: an app from a TOML rule opens in its workspace; editing the TOML takes effect without a restart
- **Prompt seed**: [[rules]] (bundle-id/title regex → workspace, float), FSEvents watch, diff-aware reload (don't rearrange existing windows).

**Deviations from the seed:**
- Rules: `[app-workspaces]` (bundle → workspace) instead of `[[rules]]`;
  title regex and float rules deferred (YAGNI, add when actually needed).
- Reload: an explicit menu item instead of an FSEvents watch (user
  decision — predictability over magic). Reload applies: keybinds (with a
  lock against the tap thread), gaps, workspace assignments, bar, border,
  help overlay, animator, language, hyper key (restarts input). Leaves
  layouts of existing workspaces alone.

#### Task 6.2: Mouse modes — hyper+drag move/resize + release mode — DONE (code; drop = stays floating, insert-into-grid on drop deferred — return via hyper+v / bar menu; release mode = toggle-floating)
- **Agent**: claude
- **Files**: Sources/InputSystem/MouseModes.swift
- **Depends on**: 4.1
- **Acceptance**: hyper+left-drag moves smoothly (window floats), hyper+right-drag resizes, toggling release mode pulls a window out of the grid and back
- **Prompt seed**: CGEventTap mouse events while hyper is held, drag → direct setFrame (no animation), drop onto a tiled workspace → choice of inserting into the grid vs staying floating.

#### Task 6.3: Multilang UI — DONE
- **Files**: Sources/Bar/L10n.swift, Config schema
- **Acceptance**: `[general] language = "cs"` switches the bar's
  menu/tooltips to Czech; default English; unknown language = fallback to
  EN. Adding another language = add a dictionary to L10n.tables.

#### Task 6.4: Final review + security check — DONE
- code-reviewer: 0 CRITICAL, 2 HIGH (fixed: autoFloated leak on
  windowRemoved — CGWindowID reuse; restarting the event tap on hyper-key
  hot-reload must go through the main thread — run-loop binding), 1 MEDIUM
  (fixed: SO_RCVTIMEO + reading outside the accept queue in ControlServer)
- security-reviewer: 0 CRITICAL/HIGH, 2 MEDIUM (fixed: socket moved from
  /tmp to ~/Library/Application Support/ancre — squatting/spoofing on a
  multi-user machine; read timeouts on both server and CLI), 1 LOW accepted
  (SIGKILL leaves the CapsLock remap in place — documented recovery via the
  hidutil command). Clean: newline injection via MCP (maxSplits: 1 +
  connection-per-request), 0600 permissions, 4KB request cap, no keystroke
  logging, fatalError only on the bundled defaults.
- **Agent**: code-reviewer
- **Files**: whole project
- **Depends on**: everything
- **Acceptance**: no CRITICAL/HIGH
- **Prompt seed**: Overall review: memory (AX refs), CPU idle profile, permission handling, hidutil revert on crash.

### Milestone 7 — AI ready (IPC, MCP, skill)

#### Task 7.1: IPC socket + ancrectl CLI — DONE (runtime verified: state/dispatch/move-window/reload-config, error paths, socket 0600)
- **Files**: App/ControlServer.swift, Sources/ancrectl/
- **Acceptance**: `ancrectl workspace 3` switches workspace; `ancrectl state`
  returns a JSON state dump (monitors, workspaces, windows with titles,
  layouts, floats). Socket ~/Library/Application Support/ancre/ancre.sock,
  0600 permissions, line-based protocol.
- **Note**: commands go through the existing Command.parse — the CLI is just
  transport. Modeled on yabai/aerospace.

#### Task 7.2: MCP server — DONE (mcp/index.js, plain JS with no build step; registered via `claude mcp add ancre --scope user`; stdio smoke test passed)
- **Files**: mcp/ (TypeScript package)
- **Acceptance**: MCP tools ancre_state / ancre_dispatch /
  ancre_move_window over the socket; an agent can rearrange windows.

#### Task 7.3: Skill for Claude Code — DONE (.claude/skills/ancre/SKILL.md — transports, grammar tables, window-targeted verbs, recipes)
- **Files**: .claude/skills/ancre/
- **Acceptance**: the skill documents CLI/MCP + recipes (preparing a
  workspace, cleaning up notification apps).

### Milestone 8 — Workflow (2026-08-26)

#### Task 8.1: Multi-monitor matchers in [workspaces] — DONE
- `"1" = ["PHL", "P34w"]` — the first connected monitor wins (home/work).

#### Task 8.2: Window switcher (hyper+space) — DONE
- Spotlight-style panel: filter by app/title, workspace badge, Enter=focus.
- Non-activating KeyablePanel (borderless windows otherwise don't get
  keyboard input).

#### Task 8.3: Scratchpad (hyper+s) — DONE
- [scratchpad] app/width/height/command; toggle drop top-center / park.
  The scratchpad owns its own window — it never takes over an existing
  window of that app (previously it grabbed the first window matching the
  bundle ID, stealing whatever the user was working in). First toggle with
  no window spawns: `command` (shell), otherwise
  `NSWorkspace.openApplication` with `createsNewApplicationInstance` when
  the app is already running; `scratchpadPending` (15 s timeout) adopts the
  newly created window.
- The window lives OUTSIDE the model: it doesn't register in `state` or
  `axWindows`, its only reference is `scratchpadAX` (+
  `scratchpadVisible`). This drops workspace location, bar/switcher/hints,
  enforceTiling, parking on workspace switch, and normal float behavior.
  The frame is written directly to the AX element (animator), hide =
  `OffscreenParking.parkFrame` + returning focus to the focused window of
  the active workspace. `register` skips it even on rescan (retile),
  `adopt-window` rejects it, `windowDestroyed`/`appTerminated` clean up the
  reference.
  ponytail: after an ancre restart, the old scratchpad window becomes a
  normal window (no persistence) — the next hyper+s opens a fresh one.
- Menubar menu: a "Scratchpad: <app> (running/not running)" item with the
  same toggle, tooltip explains the feature, an unconfigured scratchpad =
  inert item (validateMenuItem).

#### Task 8.4: Window hints (hyper+o) — DONE
- Letter badges over visible windows, pressing one focuses it, Esc closes.

#### Task 8.5: Presets + arrange — DONE
- `preset-save <name>` / `preset <name>` (commands → bindable, IPC, MCP);
  storage at ~/Library/Application Support/ancre/presets.json.
- IPC verb `arrange <json>` + MCP tool ancre_arrange: declarative
  {layouts, apps, active} in a single call.

#### Task 8.6: Event stream — DONE
- `ancrectl subscribe` streams JSON events (state-changed on
  focus/workspace/pause change, window-opened). Basis for sketchybar/agents.

- Command palette in the switcher: `>` prefix = commands (layouts,
  pause/resume, retile, adopt, scratchpad, open-config, presets), a number =
  jump to a workspace. `hyper-shift-space` = "switcher commands" opens
  straight into the `>` prefix.

## Backlog (further iterations):
- Config hooks (on-window-open → command/shell) — for now covered externally
  via the event stream.
- hidutil re-apply after wake/keyboard swap (IOHIDManager notifications).
- In-place autoupdate via Sparkle: appcast on the docs GitHub Pages, EdDSA
  signing of release.yml artifacts. Blocked on a Developer ID signature —
  swapping the ad-hoc signed bundle changes the cdhash, and TCC may drop the
  Accessibility/Input Monitoring grant (autoupdate would silently break the
  WM). Until then a daily update-check suffices (UpdateChecker.swift, menu
  item → release page).
- True niri scroll (see the note under 5.1), layout edit mode.
#### Task 8.7: Auto-stack on migration — DONE
- [general] auto-stack (default on) + auto-stack-min-width (300): a
  workspace whose windows no longer fit on the monitor switches to stack
  after a reconcile; once it fits again, it reverts to the original layout.
  A manual layout change cancels the auto-restore.
- Ceiling: the check only runs on display reconfiguration, not on window add.

#### Task 8.8: Move log (rule learning, phase 1) — DONE
- [general] move-log (default on, can be disabled): manual window moves
  (keybind, bar, drag, adopt — NOT automatic IPC/arrange/presets) get
  appended to
  ~/Library/Application Support/ancre/move-log.jsonl
  ({ts, bundleID, from, to, source}; no titles). Phase 2 (suggest-rules /
  agent) remains in the backlog.

## Out of scope

- App Store / sandboxed distribution (incompatible with AX + hidutil)
- Native macOS Spaces integration, SIP/private API
- A custom TOML parser (TOMLKit), telemetry, auto-update
- Scratchpads, window swallowing, blur/transparency effects (maybe later)

## Verification

1. `swift build && swift test` — WMCore/LayoutEngine/Config unit tests green
2. Manual scenario (after M1): launch the app, grant permissions, open 4
   windows (Terminal, Safari, Finder, TextEdit) → they tile in dwindle;
   hyper+hjkl focus, hyper+shift+hjkl swap, hyper+1/2 instant workspace
   switch, a self-resized window snaps back
3. Multi-monitor (M2): disconnect/reconnect an external monitor → workspaces
   migrate and come back; `hyper+,` / `hyper+.` switches focus between
   displays; `hyper+6` from the built-in jumps to workspace 6 on the
   external one; at startup the log shows stable display IDs for
   `[workspaces]` in the config
4. Bar (M3): clicking switches, dragging an icon moves a window, right-click
   menu works
5. Animations (M4): smooth for Terminal/Finder, auto-instant for a slow app
6. Idle CPU < 1% (Activity Monitor), no polling in an Instruments time
   profile
