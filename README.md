<p align="center">
  <img src="docs/brand/ancre-fixed-point-brand-kit/github/ancre-readme-header.svg" alt="ancre - tiling window manager for macOS power users">
</p>

# ancre

[![CI](https://github.com/wraithyy/ancre/actions/workflows/ci.yml/badge.svg)](https://github.com/wraithyy/ancre/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/wraithyy/ancre?sort=semver)](https://github.com/wraithyy/ancre/releases)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](https://github.com/wraithyy/ancre#requirements)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](Package.swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-wraithyy-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/wraithyy)

**Docs: https://wraithyy.github.io/ancre/**

A Hyprland-inspired tiling window manager for macOS: your windows arrange
themselves side by side and one key drives everything.

> **ancre** /ɑ̃kʁ/ — French for *anchor*. Your windows stop drifting.

<!-- media: hero screenshot + video (shotlist: Hero / README)
<p align="center">
  <img src="website/src/assets/hero-desktop.png" alt="ancre tiling a full desktop: dwindle layout with four windows and the workspace bar">
</p>
https://github.com/wraithyy/ancre/assets/hero-demo.mp4
-->

*New to tiling?* Instead of stacking windows on top of each other, a tiling
window manager gives every window its own slot in a layout and keeps the
screen fully used. You switch between numbered **workspaces** (virtual
desktops) and move focus with the keyboard.

Inspired by [Hyprland](https://hypr.land) (layouts, ergonomics, the
one-modifier philosophy) and [OmniWM](https://github.com/wraithyy/OmniWM)
(proving a polished tiling WM on macOS is possible).

## Highlights

- **Layouts**: dwindle (Hyprland-style spiral), scroll columns, stack
  (monocle), plus custom layouts from one-line config templates
- **Workspaces 1–9 across monitors** with stable assignment that survives
  unplug/replug
- **Workspace bar** with window icons, drag&drop, badges and context menus —
  including *inside the macOS menu bar* or *hidden under the notch*
- **One hyper key** (CapsLock) for everything; hold it for a cheatsheet of
  every binding
- **Mouse-native**: dragging/resizing windows the normal macOS way routes
  through the tiling engine (edges insert, center swaps, neighbors adjust)
- **Window switcher, scratchpad, window hints, presets** — all one hyper
  shortcut away
- **Everything themeable**: colors, fonts, sizes, opacities, per-monitor
- **AI ready**: `ancrectl` CLI, Unix-socket IPC, built-in MCP server, Claude
  skill — an agent rearranges your whole setup in one call. `ancrectl mcp`
  plugs into any MCP client (Claude Code & Desktop, ChatGPT desktop/Codex,
  Cursor, Antigravity, opencode, pi, OpenClaw, Hermes) — per-client setup in
  [docs/SCRIPTING.md](docs/SCRIPTING.md#mcp-with-any-agent)

## Before you launch — read this once

Starting ancre does two visible things immediately:

1. **CapsLock is remapped** to the hyper key (via `hidutil`). You get it
   back the moment ancre quits; if the process ever dies uncleanly, restore
   it with:
   ```sh
   hidutil property --set '{"UserKeyMapping":[]}'
   ```
2. **Your windows start tiling.** Press `hyper+p` to pause at any time, or
   click the ancre icon in the menu bar (top-right strip of the screen) →
   *Pause tiling*.

The first launch shows an onboarding window: it checks the two needed
permissions (**Accessibility**, **Input Monitoring**), deep-links to the
right System Settings panes, and only starts tiling after you press
**Start**. Re-show it anytime with `ancre --onboarding`. Requires macOS 14+.

## Install

### Homebrew (recommended)

```sh
brew tap wraithyy/tap
brew trust wraithyy/tap          # third-party taps need a one-time trust
brew install --cask ancre        # installs ancre.app + puts ancrectl on PATH
open /Applications/ancre.app
```

The app is ad-hoc signed (no paid developer certificate); the cask clears
the quarantine flag for you, so Gatekeeper won't complain.

### From source

Open Terminal (find it with Spotlight: `⌘+space`, type "Terminal") and run:

```sh
xcode-select --install                                # once: compiler toolchain + git
git clone https://github.com/wraithyy/ancre && cd ancre   # download the source
swift build -c release                                # compile (first run fetches TOMLKit; a few minutes)
Scripts/bundle.sh                                     # package .build/ancre.app
cp .build/release/ancrectl /usr/local/bin/            # optional: CLI on PATH
open .build/ancre.app                                 # launch (onboarding appears)
```

## Quickstart

| Try | What happens |
|---|---|
| `hyper + 1…9` | switch workspace |
| `hyper + h/j/k/l` | move focus between windows |
| `hyper + shift + h/j/k/l` | move the focused window |
| `hyper + space` | fuzzy window switcher |
| hold `hyper` for 2 s | cheatsheet with every shortcut |
| drag a window by its title bar | it re-tiles where you drop it |

## Documentation

Full docs live at **https://wraithyy.github.io/ancre/** (English + čeština).
Most topics are covered in both repo markdown and on the web, but the two
aren't a 1:1 mirror — some pages exist only on one side:

| Topic | In repo | On the web |
|---|---|---|
| Keybindings, mouse, bar, menu bar | [docs/KEYBINDINGS.md](docs/KEYBINDINGS.md) | [controls](https://wraithyy.github.io/ancre/controls/) |
| Configuration (all sections, bar modes, multi-monitor) | [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | [configuration](https://wraithyy.github.io/ancre/configuration/) · [config reference](https://wraithyy.github.io/ancre/config-reference/) |
| Scripting & AI (CLI, socket, MCP for every agent, presets, arrange) | [docs/SCRIPTING.md](docs/SCRIPTING.md) | [scripting](https://wraithyy.github.io/ancre/scripting/) |
| Layouts (dwindle, scroll, stack) | — | [layouts](https://wraithyy.github.io/ancre/layouts/) |
| Multi-monitor placement | — | [multi-monitor](https://wraithyy.github.io/ancre/multi-monitor/) |
| Bar setup and customization | — | [bar](https://wraithyy.github.io/ancre/bar/) |
| Coming from Hyprland | [docs/HYPRLAND.md](docs/HYPRLAND.md) | — |
| Troubleshooting & uninstall | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | [troubleshooting](https://wraithyy.github.io/ancre/troubleshooting/) |
| Architecture | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | [architecture](https://wraithyy.github.io/ancre/architecture/) |
| Contributing | [CONTRIBUTING.md](CONTRIBUTING.md) | — |

## Known limitations

- Offscreen parking (hiding windows for inactive workspaces) relies on how
  macOS clamps AX window positions near screen edges — behavior that varies
  by macOS version; see `Sources/AXBridge/OffscreenParking.swift`
- Animations auto-disable for apps whose AX responses are too slow to
  animate smoothly
- No App Store distribution: ancre needs Accessibility access and remaps
  CapsLock via `hidutil`, both outside the App Store sandbox
- A window that refuses a requested frame gets floated after 3 snap-back
  attempts rather than fought indefinitely
- The app is ad-hoc signed, not notarized — Gatekeeper is satisfied via the
  Homebrew cask (or a manual quarantine clear from source), but there's no
  Apple notarization ticket

## How it compares

ancre sits between yabai and AeroSpace/Amethyst on the trade-off each of
those makes. Like AeroSpace and Amethyst, it uses only the public
Accessibility API — no private CGS/SkyLight window APIs, no SIP changes, no
kernel extensions like yabai needs for some features. One documented
exception: `_AXUIElementGetWindow` via `dlsym`, used to get a stable
`CGWindowID` from an `AXUIElement` (the same trick yabai and Amethyst rely
on, since there's no public API for it; it degrades gracefully if the symbol
is ever unavailable). Like yabai, it takes Hyprland's dwindle layout and
one-modifier ergonomics as the model rather than i3/BSPWM-style manual
splits. Configuration is a single declarative TOML file, and the whole
stack — CLI, Unix socket, MCP server — is built to be driven by scripts and
agents, not just a keyboard.

## Feedback

Found a bug or have a feature request? Open an issue on
[GitHub Issues](https://github.com/wraithyy/ancre/issues). See
[Releases](https://github.com/wraithyy/ancre/releases) for the changelog.

## Support

If ancre saves you time, you can
[buy me a coffee](https://buymeacoffee.com/wraithyy). Entirely optional —
issues and pull requests help just as much.

## License

[MIT](LICENSE)
