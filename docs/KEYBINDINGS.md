# Keybindings & mouse

> Nicer rendering: https://wraithyy.github.io/ancre/controls/

Hyper = CapsLock (change the physical key via `[hyper].key`; `f13`–`f20`,
`right_cmd`, `right_option` also work). Hold hyper ~2 s → cheatsheet overlay
with every binding; using a shortcut resets the timer.

Making CapsLock behave as hyper needs a `hidutil` remap (CapsLock→F18)
applied at launch, plus Input Monitoring permission for the CGEventTap that
reads key presses — without it, hyper does nothing. If ancre crashes before
it can revert the remap, CapsLock stays stuck as F18; fix it with
`hidutil property --set '{"UserKeyMapping":[]}'` (see
[TROUBLESHOOTING.md](TROUBLESHOOTING.md)).

`right_cmd` and `right_option` are usable as hyper but collide with system
shortcuts: `right_cmd` overlaps Spotlight's default Cmd-Space-style
bindings on some setups, and `right_option` overlaps the input-source
switcher. Prefer CapsLock or an unused F-key unless you've disabled those
system shortcuts.

## Defaults

| Shortcut | Action |
|---|---|
| `hyper + h/j/k/l` | focus window left/down/up/right |
| `hyper + shift + h/j/k/l` | move window in direction (swaps places with the window there) |
| `hyper + arrows` | resize focused window — neighbors adjust |
| `hyper + 1…9` | switch workspace |
| `hyper + shift + 1…9` | send focused window to workspace |
| `hyper + space` | window switcher (fuzzy search; typing `>` switches it to the command palette, typing digits jumps to that workspace) |
| `hyper + shift + space` | command palette — the switcher opened with `>` pre-typed (layouts, presets, pause, scratchpad…) |
| `hyper + s` | scratchpad toggle (own window, outside tiling; also in the menu bar menu) |
| `hyper + o` | window hints (focus by letter) |
| `hyper + v` | toggle floating (window leaves the grid and moves freely) |
| `hyper + f` | toggle fullscreen |
| `hyper + t` / `hyper + shift + t` | layout scroll / dwindle |
| `hyper + a` | adopt frontmost window into current workspace |
| `hyper + p` | pause tiling (toggle) |
| `hyper + r` | retile — rescan windows and re-place everything |
| `hyper + ,` / `hyper + .` | focus previous / next monitor |

Example — Teams on the left, Mail on the right: focus Teams, `hyper+shift+h`
until it sits left; focus Mail (`hyper+l`), done. Want Calendar on its own
desktop: focus it, `hyper+shift+2`, and `hyper+2` / `hyper+1` switch back
and forth.

## Rebinding

Everything is rebindable in `[keybindings]`; your entries merge with the
defaults and an empty string `""` unbinds a default. Any command from the
[request grammar](SCRIPTING.md) can be bound, including `preset <name>`,
`preset-save <name>`, `layout <custom>`, `open-config`, `switcher`,
`switcher commands` (the command palette), `hints`.
(`reload-config` is IPC/menu-only — it is not a bindable command.)

## Mouse

| Gesture | Effect |
|---|---|
| native drag (title bar) | tile follows your cursor through the layout: near an edge it **inserts** next to the target (placeholder shows the slot), over the center it **swaps** |
| native resize (window edge) | neighbors re-ratio live |
| `hyper + left-drag` | same move/insert/swap, grabbing the window anywhere |
| `hyper + right-drag` | resize from anywhere in the window |

## Bar

Click a workspace → switch. Click a window icon → focus it. Drag an icon to
another workspace cell → move the window (drop slot previewed). Right-click
an icon → float/tile, fullscreen, move-to-workspace submenu. Right-click a
workspace → layout picker, move focused window here. Dot badge = the app
wants attention. Dashed ring = floating window.

## Menu bar

The ancre icon in the menu bar (the strip along the top of the screen,
right side): pause tiling (the anchor diamond turns red while paused),
retile, adopt frontmost window, window switcher, scratchpad, monitor list
(click copies the stable id for config), open config, reload config, quit.
A newer release turns the top-left bracket of the icon green and adds an
update item (`update-check`, nothing installs itself). Everything here
works without a terminal.
