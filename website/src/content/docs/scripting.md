---
title: Scripting & AI
description: The ancrectl CLI, unix socket, built-in MCP server, and Claude skill.
sidebar:
  order: 7
---

Everything goes through the command bus, exposed on the unix socket
`~/Library/Application Support/ancre/ancre.sock` (mode 0600 — only your user
can control it).

## CLI — `ancrectl`

The binary at `.build/debug/ancrectl` (after `swift build`):

```sh
ancrectl state            # JSON: monitors, workspaces, windows (id, title, bundle, float, focus)
ancrectl workspace 3      # any command from the shortcuts
ancrectl layout scroll
ancrectl move-window 4495 8   # targeted verbs: move-window / focus-window / set-floating <id> ...
ancrectl reload-config
```

Responses are `ok`, `error: ...` (exit 1), or JSON.

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
| `ancre_move_window` | move a window by ID to a workspace |
| `ancre_focus_window` | focus a window by ID |
| `ancre_set_floating` | float on/off for a window |

An agent can handle "set up my review workspace" — it finds windows by
title/bundle ID and rearranges them.

## Claude skill

`.claude/skills/ancre/SKILL.md` in the repository — workflows and recipes for
driving ancre from Claude Code.
