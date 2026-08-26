# Coming from Hyprland?

| Hyprland | ancre |
|---|---|
| `dwindle` layout | `dwindle` (same idea) |
| `master` layout | a `[custom-layouts]` template, e.g. `"master" = "h(0.6, *, v(0.5, *, *))"` |
| workspace rules (`workspace = 1, monitor:DP-1`) | `[workspaces]` — pin by stable id or name, with priority lists |
| `windowrulev2` by app | `[app-workspaces]` (bundle id → workspace) |
| special workspace | `[scratchpad]` — **one** configured app, not arbitrary windows |
| `hyprctl` / socket IPC | `ancrectl` / unix socket (line protocol + JSON) |
| `hyprctl dispatch` | `ancrectl <command>` |

Known gaps, stated plainly: **no `submap`** (Hyprland's mode-switching
keybind layer) — ancre's keybindings are a single flat map, not a stack of
swappable modes; **no window rules by title/regex** (only bundle id), **no
`exec-once`/autostart** section yet (use a LaunchAgent or Login Item),
**gaps are global** (no per-workspace gaps), scratchpad holds a single app.
Window animations cover ancre's own placement moves, not arbitrary system
animations.

Why some concepts don't map 1:1: Hyprland is a Wayland compositor with full
control over the display server; ancre is a userspace app built entirely on
macOS's public Accessibility API. Some Hyprland features assume
compositor-level control ancre simply doesn't have access to.

Also worth knowing: macOS offers no public API to truly hide another app's
window, so hidden workspaces are "parked" just past the edge of the display
union — that's why a stray window can appear at a screen edge for a frame
during heavy reshuffles.
