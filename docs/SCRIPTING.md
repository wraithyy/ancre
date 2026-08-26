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
