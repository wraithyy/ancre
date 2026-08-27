---
title: Scripting & AI
description: The ancrectl CLI, unix socket, built-in MCP server, and Claude skill.
sidebar:
  order: 7
---

Anything you can do with a shortcut, a script or an AI agent can do too:
"set up my review workspace" becomes one command. Every operation goes
through the same command bus, exposed on the unix socket
`~/Library/Application Support/ancre/ancre.sock` (mode 0600 — only your user
can control it). If ancre isn't running, any `ancrectl` call prints
`cannot connect to <path> — is ancre running?` and exits 1.

<!-- media (shotlist: scripting.md):
![ancrectl in a terminal: state output, then a move command with the window visibly moving](../../assets/scripting-ancrectl.gif)
![An MCP command from the CLI immediately rearranging windows](../../assets/scripting-mcp-demo.gif)
-->


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

MCP ([Model Context Protocol](https://modelcontextprotocol.io)) lets AI
assistants like Claude call tools directly — here, control your windows. The
server is **built into the CLI** — no Node. Register it with Claude Code:

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

## MCP with any agent

`ancrectl mcp` is a stdio MCP server — one binary, no Node, no checkout. Any
MCP client that can spawn a local process can drive ancre. Two rules apply
everywhere:

- **ancre must be running.** The bridge only forwards to the socket; without
  ancre every tool call returns `error: cannot connect …`.
- **GUI clients don't inherit your shell PATH.** In desktop apps (Claude
  Desktop, Cursor, Antigravity, ChatGPT) use the absolute path —
  `/opt/homebrew/bin/ancrectl` for the Homebrew install, or
  `/path/to/repo/.build/release/ancrectl` from source.

| Client | Where the server goes |
|---|---|
| Claude Code | `claude mcp add ancre --scope user -- ancrectl mcp` |
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` (Settings → Developer → Edit Config) |
| ChatGPT desktop · Codex CLI · Codex IDE | `codex mcp add ancre -- ancrectl mcp` → shared `~/.codex/config.toml` |
| Cursor | `~/.cursor/mcp.json` (project: `.cursor/mcp.json`) |
| Antigravity (2.0 · IDE · CLI) | `~/.gemini/config/mcp_config.json` (workspace: `.agents/mcp_config.json`) |
| opencode | `~/.config/opencode/opencode.json` (project: `opencode.json`) |
| pi | `~/.pi/agent/mcp.json` (project: `.pi/mcp.json`) |
| OpenClaw | `openclaw mcp add ancre --command ancrectl --arg mcp` → `~/.openclaw/openclaw.json` |
| Hermes | `~/.hermes/config.yaml` under `mcp_servers:` |

### The `mcpServers` dialect

Claude Desktop, Cursor, Antigravity and pi all take the same shape (Cursor
wants `"type": "stdio"`, Antigravity uses `serverUrl` instead of `url` for
remote servers — irrelevant here):

```json
{
  "mcpServers": {
    "ancre": {
      "command": "/opt/homebrew/bin/ancrectl",
      "args": ["mcp"]
    }
  }
}
```

### Codex CLI / ChatGPT desktop

The ChatGPT desktop app, Codex CLI and the Codex IDE extension share one
config, so you register ancre once:

```sh
codex mcp add ancre -- ancrectl mcp
codex mcp list
```

```toml
# ~/.codex/config.toml — equivalent, hand-written
[mcp_servers.ancre]
command = "/opt/homebrew/bin/ancrectl"
args = ["mcp"]
```

ChatGPT in the browser only speaks to *remote* (HTTP) MCP servers — a local
window manager isn't reachable from there. Use the desktop app.

### opencode

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "ancre": {
      "type": "local",
      "command": ["ancrectl", "mcp"],
      "enabled": true
    }
  }
}
```

### OpenClaw

```sh
openclaw mcp add ancre --command ancrectl --arg mcp
openclaw mcp status        # transport, tools, health
```

The entry lands in `~/.openclaw/openclaw.json` under `mcp.servers`; `openclaw
mcp doctor` diagnoses a server that won't start.

### Hermes

```yaml
# ~/.hermes/config.yaml
mcp_servers:
  ancre:
    command: "ancrectl"
    args: ["mcp"]
```

`/reload-mcp` in a running session picks up config changes.

### Running several agents at once

Nothing needs coordinating between clients: each one spawns its own
`ancrectl mcp` child process, and **all state lives in ancre**, not in the
bridge. Every tool call is one socket request into the same command bus, so
requests are serialised in arrival order on ancre's `axQueue` — two agents
can't corrupt the state, but they *can* undo each other's layout.

What that means in practice:

- **Read before you write.** `ancre_state` right before `ancre_arrange`;
  window IDs come and go as windows open and close.
- **One `ancre_arrange` beats ten commands.** It applies layouts, placement,
  active workspaces and final focus in a single request, so another agent
  can't interleave halfway through.
- **Hand off through presets.** `preset-save review` (via `ancre_command`)
  checkpoints the current arrangement; any other agent restores it with
  `preset review`. That's the cheap shared vocabulary between two agents that
  otherwise share no context.
- **Watchers don't need MCP.** `ancrectl subscribe` streams one JSON event per
  line — better than polling `ancre_state` from a background agent.
- **Narrow the surface for agents you trust less.** Clients with tool filters
  (OpenClaw's `toolFilter`, Hermes' `tools.include`) can expose read-only
  `ancre_state` and nothing else.

Security: the socket is mode 0600, so anything running as your user gets full
control of your windows — the MCP bridge adds no extra authentication. Treat
"can talk to ancre" as "can rearrange my desktop", and don't proxy the socket
to a machine you don't own.

## Claude skill

`.claude/skills/ancre/SKILL.md` in the repository — workflows and recipes for
driving ancre from Claude Code.
