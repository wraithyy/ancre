---
title: Controls
description: Keyboard shortcuts, mouse modes, and the workspace bar.
sidebar:
  order: 2
---

Hyper = CapsLock (change the key via `[hyper].key` in the config). Holding
hyper for more than 2 s shows a **cheatsheet of all shortcuts** as a
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
| `hyper+space` | window switcher |
| `hyper+s` | scratchpad |
| `hyper+o` | hints (jump to window) |
| `hyper+a` | adopt frontmost window into the current workspace |
| `hyper+p` | pause tiling (toggle) |
| `hyper+r` | rescan + retile everything |
| `hyper+,` / `hyper+.` | focus previous/next monitor |

Every shortcut can be remapped in the `[keybindings]` section — see
[Configuration](/ancre/configuration/).

## Mouse

- **`hyper+left drag`** — move a window. The tile pops out of the grid;
  dropping over another tile inserts it next to it (a placeholder shows the
  future position).
- **`hyper+right drag`** — resize. Tiled windows live-rearrange their
  neighbors.

## Workspace bar

- click a cell = switch workspace
- click an icon = focus the window
- drag an icon = move the window to another workspace
- right click = context menu (float, fullscreen, move, layout)
- dashed ring around an icon = floating window; badge = notification

## Menu bar ◱

Pause tiling, retile, monitor list (click copies the stable ID for the
config), open and reload the config.
