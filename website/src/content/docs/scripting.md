---
title: Scripting & AI
description: The ancrectl CLI, unix socket, built-in MCP server, and Claude skill.
sidebar:
  order: 7
---

Everything goes through the command bus, exposed on the unix socket
`~/Library/Application Support/ancre/ancre.sock` (mode 0600 — only your user
can control it). If ancre isn't running, any `ancrectl` call prints
`cannot connect to <path> — is ancre running?` and exits 1.

## CLI — `ancrectl`

`ancrectl` is on `PATH` with the Homebrew install. From source, `swift build`
puts it at `.build/debug/ancrectl`; `swift build -c release` puts it at
`.build/release/ancrectl` — copy either to `/usr/local/bin` or call it by
path.

```sh
ancrectl state                 # JSON: monitors, workspaces, windows (id, pid, bundleID, title, floating, focused)
ancrectl workspace 3           # any command from the shortcuts
ancrectl layout scroll
ancrectl move-window 4495 8    # targeted verbs: move-window / focus-window / set-floating <id> <true|false>
ancrectl preset-save review    # save the current arrangement…
ancrectl preset review         # …and restore it later
ancrectl arrange '{"layouts":{"2":"scroll"},"apps":{"com.google.Chrome":"2"},"windows":{"4495":"3"},"active":["1"],"focus":4495}'
ancrectl subscribe             # stream JSON events (one per line) until disconnect
ancrectl reload-config
```

Responses are `ok`, `error: ...` (exit 1), or JSON. `arrange` applies a
whole setup declaratively in one call: per-workspace layouts, app placement,
individual window placement, active workspaces, and final focus.

## MCP server

The MCP server is **built into the CLI** — no Node. Register it with Claude
Code:

```sh
claude mcp add ancre --scope user -- ancrectl mcp
```

Tools:

| Tool | Purpose |
|---|---|
| `ancre_state` | JSON snapshot of monitors, workspaces, and windows |
| `ancre_command` | any command string (`"workspace 3"`, `"layout scroll"`) |
| `ancre_arrange` | apply a whole declarative setup in one call — layouts, app/window placement, active workspaces, final focus |
| `ancre_move_window` | move a window by ID to a workspace |
| `ancre_focus_window` | focus a window by ID |
| `ancre_set_floating` | float on/off for a window |

An agent can handle "set up my review workspace" — it finds windows by
title/bundle ID and issues one `ancre_arrange`.

## Claude skill

`.claude/skills/ancre/SKILL.md` in the repository — workflows and recipes for
driving ancre from Claude Code.
