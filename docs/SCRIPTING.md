# Scripting & AI (CLI · MCP · skill)

> Nicer rendering: https://wraithyy.github.io/ancre/scripting/

Every feature goes through one command bus, exposed on a unix socket at
`~/Library/Application Support/ancre/ancre.sock` (mode 0600 — only your
user can drive it).

## CLI

`ancrectl` is on PATH with the Homebrew install; from source it lands in
`.build/release/ancrectl` (or `.build/debug/` after a plain `swift build`) —
copy it to `/usr/local/bin` or call it by path.

```sh
ancrectl state                 # JSON: monitors, workspaces, windows (id, title, bundle, floating, focused)
ancrectl workspace 3           # any command from the keybinding grammar
ancrectl layout scroll
ancrectl move-window 4495 8    # targeted verbs: move-window / focus-window / set-floating <id>
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

## MCP server (built in — no Node, no repo checkout)

```sh
claude mcp add ancre --scope user -- ancrectl mcp
# from a source build, use the full path instead:
# claude mcp add ancre --scope user -- /path/to/repo/.build/release/ancrectl mcp
```

Tools: `ancre_state`, `ancre_command`, `ancre_arrange`,
`ancre_move_window`, `ancre_focus_window`, `ancre_set_floating`. An agent
can fulfill "set up my review workspace" by reading state, finding windows
by title/bundle id, and issuing one `ancre_arrange`.
