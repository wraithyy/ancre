# Scripting & AI (CLI · MCP · skill)

> Nicer rendering: https://wraithyy.github.io/ancre/scripting/

Every feature goes through one command bus, exposed on a Unix socket at
`~/Library/Application Support/ancre/ancre.sock` (mode 0600 — only your
user can drive it). If ancre isn't running, any `ancrectl` call prints
`ancrectl: cannot connect to <path> — is ancre running?` to stderr and
exits 1.

## CLI

`ancrectl` is on PATH with the Homebrew install. From source, a plain
`swift build` puts it at `.build/debug/ancrectl`; `swift build -c release`
puts it at `.build/release/ancrectl` — copy either to `/usr/local/bin` or
call it by path.

```sh
ancrectl state                 # JSON: monitors, workspaces, windows (id, pid, bundleID, title, floating, focused)
ancrectl workspace 3           # any command from the keybinding grammar
ancrectl layout scroll
ancrectl move-window 4495 8    # targeted verbs: move-window / focus-window / set-floating <id> <true|false>
ancrectl preset-save review    # save the current arrangement…
ancrectl preset review         # …and restore it later
ancrectl arrange '{"layouts":{"2":"scroll"},"apps":{"com.google.Chrome":"2"},"windows":{"4495":"3"},"active":["1"],"focus":4495}'
ancrectl subscribe             # stream JSON events (one per line) until disconnect
ancrectl reload-config
```

Responses: `ok`, `error: …` (exit 1; exit 2 = usage error), or JSON.
`arrange` applies a whole setup declaratively in one call: per-workspace
layouts, app placement, individual window placement, active workspaces, and
final focus.

The full request grammar (every command and verb, plus recipes) lives in
the Claude skill: [`.claude/skills/ancre/SKILL.md`](../.claude/skills/ancre/SKILL.md).

## MCP server

Built in — no Node install or repo checkout needed, `ancrectl mcp` runs a
stdio MCP server directly.

```sh
claude mcp add ancre --scope user -- ancrectl mcp
# from a source build, use the full path instead:
# claude mcp add ancre --scope user -- /path/to/repo/.build/release/ancrectl mcp
```

Tools: `ancre_state`, `ancre_command`, `ancre_arrange`,
`ancre_move_window`, `ancre_focus_window`, `ancre_set_floating`. An agent
can fulfill "set up my review workspace" by reading state, finding windows
by title/bundle id, and issuing one `ancre_arrange`.

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
