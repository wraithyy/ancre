<p align="center">
  <img src="docs/brand/ancre-fixed-point-brand-kit/github/ancre-readme-header.svg" alt="ancre - tiling window manager for macOS power users">
</p>

# ancre

**Docs: https://wraithyy.github.io/ancre/**

A Hyprland-inspired tiling window manager for macOS. Your windows arrange
themselves side by side — no overlapping, no hunting — and one key drives
everything. Built on the pure public Accessibility API: no private
CGS/SkyLight calls, no SIP changes, no kernel extensions.

> **ancre** /ɑ̃kʁ/ — French for *anchor*. Your windows stop drifting.

Inspired by [Hyprland](https://hypr.land) (layouts, ergonomics, the
one-modifier philosophy) and [OmniWM](https://github.com/wraithyy/OmniWM)
(proving a polished tiling WM on macOS is possible).

*New to tiling?* Instead of stacking windows on top of each other, a tiling
window manager gives every window its own slot in a layout and keeps the
screen fully used. You switch between numbered **workspaces** (virtual
desktops) and move focus with the keyboard.

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
- **AI ready**: `ancrectl` CLI, unix-socket IPC, built-in MCP server, Claude
  skill — an agent rearranges your whole setup in one call

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

### Before you launch — read this once

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

The first launch shows an onboarding window first: it checks the two needed
permissions (**Accessibility**, **Input Monitoring**), deep-links to the
right System Settings panes, and only starts tiling after you press
**Start**. Re-show it anytime with `ancre --onboarding`. Requires macOS 14+.

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
The same content in repo markdown:

| Topic | In repo | On the web |
|---|---|---|
| Keybindings, mouse, bar, menu bar | [docs/KEYBINDINGS.md](docs/KEYBINDINGS.md) | [controls](https://wraithyy.github.io/ancre/controls/) |
| Configuration (all sections, bar modes, multi-monitor) | [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | [configuration](https://wraithyy.github.io/ancre/configuration/) · [config reference](https://wraithyy.github.io/ancre/config-reference/) |
| Scripting & AI (CLI, socket, MCP, presets, arrange) | [docs/SCRIPTING.md](docs/SCRIPTING.md) | [scripting](https://wraithyy.github.io/ancre/scripting/) |
| Coming from Hyprland | [docs/HYPRLAND.md](docs/HYPRLAND.md) | — |
| Troubleshooting & uninstall | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | [troubleshooting](https://wraithyy.github.io/ancre/troubleshooting/) |
| Architecture | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | [architecture](https://wraithyy.github.io/ancre/architecture/) |
| Contributing | [CONTRIBUTING.md](CONTRIBUTING.md) | — |

## License

[MIT](LICENSE)
