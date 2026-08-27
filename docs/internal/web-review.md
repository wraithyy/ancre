# Documentation website review — 9 personas + completeness check (2026-08-26)

Personas: junior dev, docs reviewer, junior Mac user, Hyprland veteran,
designer, frontend dev, first MacBook, macOS power user, office manager.
A tenth agent compared the website against the code (Command.parse, MCPServer,
default.toml, README, PLAN).

## Critical (agreement across multiple personas)

1. **Missing Uninstall / teardown** — hidutil revert, deleting the
   app/config, revoking permissions, LaunchAgent. New section in
   installation or its own page. (junior mac, power user, manager,
   completeness)
2. **CapsLock warning is weak and comes too late** — explain WHAT happens to
   CapsLock (uppercase letters?), how to change the key (`[hyper].key` with
   an example), Karabiner conflict (power user: two remap layers fighting).
   Move it earlier.
3. **Installation assumes a developer** — missing prerequisites (Xcode CLT,
   Swift/macOS versions), `git clone` right on the page, a Gatekeeper/ad-hoc
   signature note, Homebrew (at least "coming soon"), autostart/LaunchAgent,
   the onboarding window (`ancre --onboarding`) isn't mentioned on the site
   at all.
4. **Path to `ancrectl`** is inconsistent: installation talks about
   bundle.sh, scripting about `.build/debug/ancrectl`; the release/Homebrew
   path is missing.
5. **Behavior with macOS Spaces / native fullscreen / Stage Manager** —
   nowhere. First question for anyone coming from yabai/Aerospace/Hyprland.

## Completeness vs. code (facts, agent verified against Sources)

The website doesn't lie, but doesn't cover:

- the `preset`, `preset-save`, `open-config` commands (Command.parse has them)
- the `ancre_arrange` MCP tool (the table shows 5/6 tools)
- `ancrectl subscribe` (JSON event stream)
- the priority list `[workspaces] "1" = ["PHL", "Built-in"]`
- `reload-config` = IPC/menu only, not bindable — unexplained
- the README's "Coming from Hyprland" section + known gaps (window rules,
  exec-once, global gaps, scratchpad = 1 app) are missing from the website

## High priority

- **Complete command reference** — a table of every command string
  (grammar of the `[keybindings]` format, arguments) + a JSON
  schema/example for `ancrectl state`. (Hyprland user, power user)
- **Troubleshooting is thin** — permission not granted / lost after an OS
  update (`tccutil`), MCP not showing up in Claude Code, bar on the notch,
  a "turn off before screen sharing" recipe (manager).
- **index.mdx "Where next"** doesn't link half the pages (layouts,
  multi-monitor, bar, troubleshooting).
- **Glossary / first-use of terms** — tiling, workspace, floating, bundle ID
  (how to find it), notch, unix socket. (first MacBook, junior mac)
- **Use-case recipes** — "Teams call + notes", "review workspace" — the
  documentation is purely reference. (manager)
- **OG/Twitter meta** missing (shared links have no preview). Note: the
  "missing sitemap" finding is FALSE — Starlight generates it, verified in
  the build log.
- Fonts: switch to `latin` subsets on @fontsource (saves KB).

## Low

- architecture.md references CLAUDE.md/PLAN.md without a GitHub link; add a
  "developer-only" note.
- controls ↔ scripting have no cross-link ("every shortcut has a CLI
  equivalent").
- custom-layouts: missing a more complex example than 3 windows.
- Focus/move semantics at a monitor edge (wrap? nothing? skip?) — add a
  sentence.

## Media plan (designer + frontend)

The only hard brand-manual violation: the index page has no "visible
workspace/layout example". The website has zero images.

Style: a real desktop on an Ink background, no mockups/glow. Storage:
`website/src/assets/media/<page>/<page>-<description>.{png,mp4}`. PNG 2x
retina via `astro:assets` Image (auto WebP, no CLS). Video: H.264 MP4
`<video autoplay muted loop playsinline preload="none">` with a `poster` —
not GIF (large, no pause).

Top 5 assets to produce:

1. `index-dwindle-workspace.png` — 3–4 windows in dwindle (satisfies the
   brand manual)
2. `layouts-dwindle-scroll-stack.png` — 3-panel, same windows, three layouts
3. `bar-positions-menubar-notch.png` — 4-panel position comparison
4. `controls-hyper-drag-move.mp4` — drag with a placeholder preview
5. `controls-cheatsheet-overlay.png` — hyper held for 2 s

Others: bar drag&drop, multi-monitor replug, config reload, MCP demo
(table in the designer report).
