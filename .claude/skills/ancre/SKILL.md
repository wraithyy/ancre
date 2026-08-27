---
name: ancre
description: Control the ancre tiling window manager — inspect and rearrange macOS windows, workspaces, and layouts via ancrectl CLI or the ancre MCP server. Use when the user asks to arrange windows, prepare a workspace ("připrav mi workspace na review"), move apps between workspaces, switch layouts, or query what's on screen.
---

# Controlling ancre

ancre is a Hyprland-inspired tiling WM. Everything goes through its
command bus, exposed on a unix socket (`~/Library/Application Support/ancre/ancre.sock`).

## Two transports, same protocol

1. **CLI**: `ancrectl <request>` (built at `.build/debug/ancrectl` in
   the repo, or on PATH if installed)
2. **MCP tools** (server `ancre`, built into the CLI: `ancrectl mcp`): `ancre_state`,
   `ancre_command`, `ancre_arrange`, `ancre_move_window`, `ancre_focus_window`,
   `ancre_set_floating`, `ancre_move_log`

Prefer MCP tools when available; the CLI is the fallback.

## Workflow

1. **Always read state first**: `ancre_state` / `ancrectl state` →
   JSON with monitors (stable ids), workspaces (name, layout, active) and
   windows (id, pid, bundleID, title, floating, focused). Window ids are the
   handles for targeted operations — find windows by `title`/`bundleID`.
2. Act via commands or targeted verbs.
3. Re-read state to verify.

## Requests

Keybinding-grammar commands (via `ancre_command` or CLI):

| request | effect |
|---|---|
| `workspace <name>` | switch to workspace (1-9) |
| `move-to-workspace <name>` | move the FOCUSED window |
| `focus left\|down\|up\|right` | directional focus |
| `move left\|down\|up\|right` | swap window in direction |
| `resize width\|height <±delta>` | resize focused window (points) |
| `layout dwindle\|scroll\|<custom>` | switch active workspace layout |
| `toggle-floating` / `toggle-fullscreen` | on focused window |
| `focus-monitor next\|previous` | monitor focus |
| `adopt-window` | pull frontmost window into current workspace |
| `pause-tiling` | toggle: stop/resume all tiling |
| `retile` | rescan windows + re-place everything (fixes any mess) |
| `switcher` | open the Spotlight-style window switcher |
| `scratchpad` | toggle the scratchpad window |
| `hints` | show window hints (focus by letter) |
| `open-config` | open the config file in the default editor |

Window-targeted verbs (id from state):

| request | effect |
|---|---|
| `move-window <id> <workspace>` | move any window to a workspace |
| `focus-window <id>` | focus (switches to its workspace) |
| `set-floating <id> true\|false` | float / return to tiling |
| `preset-save <name>` / `preset <name>` | save/apply a named arrangement |
| `arrange <json>` | declarative one-shot — apply a whole setup in ONE call instead of many: `{"layouts":{"2":"scroll"},"apps":{"com.google.Chrome":"2"},"windows":{"4495":"3"},"active":["1"],"focus":4495}` (`windows` = id→workspace, finer than `apps`; `focus` = final focused window; or MCP tool `ancre_arrange`) |
| `subscribe` | stream JSON events (state-changed, window-opened) until disconnect |

Responses: `ok`, `error: ...` (CLI exits 1; exit 2 = missing arguments), or
JSON for `state`. `reload-config` is an IPC-only verb (works here and in the
menubar menu, but is NOT bindable in `[keybindings]`). `subscribe` streams
events live, one JSON object per line.

## Recipes

- **Prepare a review workspace**: state → find IDE window (bundleID
  `com.microsoft.VSCode`/`dev.zed.Zed`) and browser → `move-window` both to
  one workspace → `focus-window` the IDE.
- **Clean up distractions**: state → windows with bundleID Teams/Discord/
  Mail → `move-window` each to their home workspace (see `[app-workspaces]`
  in `~/.config/ancre/ancre.toml`).
- **Suggest [app-workspaces] rules from usage** ("vylepši mi config podle
  toho, jak okna přesouvám"): `ancre_move_log` (or `cat "~/Library/Application
  Support/ancre/move-log.jsonl"` when MCP unavailable) → per-app destination
  histograms. An app with `moves >= 3` and `topShare >= 0.8` is a candidate
  rule `"<bundleID>" = "<topWorkspace>"` under `[app-workspaces]` in
  `~/.config/ancre/ancre.toml`. Read the config first and skip apps that
  already have a rule (a logged move away from the rule's workspace means the
  rule may be WRONG — flag it instead). Propose the diff to the user, edit on
  approval, then `reload-config`.
- **Something looks broken**: `retile`.
- ancre not responding on the socket → check it's running
  (`pgrep ancre`), start with `open .build/ancre.app` from the repo.

## Notes

- Workspace names are strings ("1"–"9"); custom labels/icons live in config
  and do not change the names.
- `state` shows `tilingPaused` — if true, placement is suspended until
  `pause-tiling` toggles it back.
- Config is TOML at `~/.config/ancre/ancre.toml`; after editing it,
  send `reload-config` to apply it live (bindings, gaps, bar, colors, rules —
  existing workspace layouts stay put).
