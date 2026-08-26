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

Known gaps, stated plainly: **no window rules by title/regex** (only bundle
id), **no `exec-once`/autostart** section yet (use a LaunchAgent or Login
Item), **gaps are global** (no per-workspace gaps), scratchpad holds a
single app. Window animations cover ancre's own placement moves, not
arbitrary system animations.

Also worth knowing: macOS offers no public API to truly hide another app's
window, so hidden workspaces are "parked" just past the edge of the display
union — that's why a stray window can appear at a screen edge for a frame
during heavy reshuffles.
