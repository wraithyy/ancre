---
title: Skriptování a AI
description: ancrectl CLI, unix socket, vestavěný MCP server a Claude skill.
sidebar:
  order: 7
---

Vše jde přes command bus, vystavený na unix socketu
`~/Library/Application Support/ancre/ancre.sock` (práva 0600 — ovládá jen
tvůj uživatel).

## CLI — `ancrectl`

Binárka `.build/debug/ancrectl` (po `swift build`):

```sh
ancrectl state            # JSON: monitory, workspaces, okna (id, titul, bundle, float, fokus)
ancrectl workspace 3      # libovolný command ze zkratek
ancrectl layout scroll
ancrectl move-window 4495 8   # cílené verby: move-window / focus-window / set-floating <id> ...
ancrectl reload-config
```

Odpověď je `ok`, `error: ...` (exit 1), nebo JSON.

## MCP server

MCP server je **vestavěný v CLI** — žádný Node. Registrace do Claude Code:

```sh
claude mcp add ancre --scope user -- ancrectl mcp
```

Tools:

| Tool | Účel |
|---|---|
| `ancre_state` | JSON snapshot monitorů, workspaces a oken |
| `ancre_command` | libovolný command string (`"workspace 3"`, `"layout scroll"`) |
| `ancre_move_window` | přesun okna podle ID na workspace |
| `ancre_focus_window` | fokus okna podle ID |
| `ancre_set_floating` | float on/off pro okno |

Agent tak zvládne „připrav mi workspace na review" — najde okna podle
titulků/bundle ID a přeuspořádá je.

## Claude skill

`.claude/skills/ancre/SKILL.md` v repozitáři — workflow a recepty pro práci
s ancre z Claude Code.
