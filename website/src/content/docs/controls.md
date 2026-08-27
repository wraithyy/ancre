---
title: Controls
description: Keyboard shortcuts, mouse modes, and the workspace bar.
sidebar:
  order: 2
---

Every ancre shortcut starts with a single modifier — the **hyper key**, by
default CapsLock (change it via `[hyper].key` in the config). One key you
never use for anything else, so no shortcut ever collides with an app.
Holding hyper for more than 2 s shows a **cheatsheet of all shortcuts** as a
translucent overlay.

Using CapsLock as hyper means ancre remaps it to F18 via `hidutil` on launch,
and the global event tap that catches it requires the **Input Monitoring**
permission — see [Installation](/ancre/installation/#permissions) and
[Troubleshooting](/ancre/troubleshooting/) if it stops working after a
rebuild.

:::caution
`right_cmd` and `right_option` are also valid `[hyper].key` values, but they
collide with system shortcuts: `right_cmd` with Spotlight, `right_option`
with input-language switching. CapsLock avoids both.
:::

## Keyboard shortcuts

<!-- media (shotlist: controls.md):
![Moving focus between three windows with hyper+h/j/k/l](../../assets/controls-focus.gif)
![Swapping a window within the layout](../../assets/controls-swap.gif)
![Switching workspaces 1 → 2 → 1](../../assets/controls-workspace-switch.gif)
![Moving a window to another workspace](../../assets/controls-move-to-workspace.gif)
![Toggling a window between floating and tiled](../../assets/controls-floating.gif)
![Fullscreen toggle](../../assets/controls-fullscreen.gif)
![Resizing — neighbors give way](../../assets/controls-resize.gif)
-->

| Shortcut | Action |
|---|---|
| `hyper+h/j/k/l` | focus in direction |
| `hyper+shift+h/j/k/l` | swap window in direction |
| `hyper+arrows` | resize (neighbors give way) |
| `hyper+1..9` | switch workspace |
| `hyper+shift+1..9` | move focused window to workspace |
| `hyper+v` | float / back to tiles |
| `hyper+f` | fullscreen toggle |
| `hyper+t` / `hyper+shift+t` | layout scroll / dwindle |
| `hyper+space` | window switcher (fuzzy search across all windows) |
| `hyper+s` | scratchpad (a floating terminal/app summoned on demand) |
| `hyper+o` | hints — every window gets a letter, press it to jump there |
| `hyper+a` | adopt frontmost window into the current workspace |
| `hyper+p` | pause tiling (toggle) |
| `hyper+r` | rescan + retile everything |
| `hyper+,` / `hyper+.` | focus previous/next monitor |
| `hyper+shift+esc` | quit ancre (panic switch — windows stay where they are) |

Every shortcut can be remapped in the `[keybindings]` section — see
[Configuration](/ancre/configuration/).

## Mouse

<!-- media (shotlist: controls.md):
![Dragging a window by mouse into another position in the layout](../../assets/controls-dragdrop.gif)
-->

Mouse is native — no hyper needed:

- **native drag** (title bar) — the tile follows your cursor through the
  layout: near an edge it **inserts** next to the target (a placeholder
  shows the slot), over the center it **swaps**.
- **native resize** (window edge) — neighbors re-ratio live.

With hyper held, the same works from anywhere in the window:

- **`hyper+left drag`** — same move/insert/swap, grabbing the window
  anywhere.
- **`hyper+right drag`** — resize from anywhere in the window.

## Workspace bar

- click a cell = switch workspace
- click an icon = focus the window
- drag an icon = move the window to another workspace
- right click = context menu (float, fullscreen, move, layout)
- dashed ring around an icon = floating window; badge = notification

## Menu bar ◱

Pause tiling, retile, monitor list (click copies the stable ID for the
config), open and reload the config.
