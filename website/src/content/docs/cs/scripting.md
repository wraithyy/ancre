---
title: Skriptování a AI
description: ancrectl CLI, unix socket, vestavěný MCP server a Claude skill.
sidebar:
  order: 7
---

Vše jde přes command bus, vystavený na unix socketu
`~/Library/Application Support/ancre/ancre.sock` (práva 0600 — ovládá jen
tvůj uživatel). Pokud ancre neběží, každé volání `ancrectl` vypíše
`cannot connect to <path> — is ancre running?` a skončí s exit 1.

## CLI — `ancrectl`

Při instalaci přes Homebrew je `ancrectl` na `PATH`. Ze zdrojů `swift build`
umístí binárku do `.build/debug/ancrectl`; `swift build -c release` do
`.build/release/ancrectl` — zkopíruj kteroukoli do `/usr/local/bin`, nebo
volej přímo podle cesty.

```sh
ancrectl state                 # JSON: monitory, workspaces, okna (id, pid, bundleID, title, floating, focused)
ancrectl workspace 3           # libovolný command ze zkratek
ancrectl layout scroll
ancrectl move-window 4495 8    # cílené verby: move-window / focus-window / set-floating <id> <true|false>
ancrectl preset-save review    # ulož aktuální uspořádání…
ancrectl preset review         # …a později ho obnov
ancrectl arrange '{"layouts":{"2":"scroll"},"apps":{"com.google.Chrome":"2"},"windows":{"4495":"3"},"active":["1"],"focus":4495}'
ancrectl subscribe             # stream JSON eventů (jeden na řádek) až do odpojení
ancrectl reload-config
```

Odpověď je `ok`, `error: ...` (exit 1), nebo JSON. `arrange` aplikuje celé
uspořádání deklarativně v jednom volání: per-workspace layouty, umístění
appek, umístění jednotlivých oken, aktivní workspaces a finální fokus.

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
| `ancre_arrange` | aplikace celého deklarativního uspořádání v jednom volání — layouty, umístění appek/oken, aktivní workspaces, finální fokus |
| `ancre_move_window` | přesun okna podle ID na workspace |
| `ancre_focus_window` | fokus okna podle ID |
| `ancre_set_floating` | float on/off pro okno |

Agent tak zvládne „připrav mi workspace na review” — najde okna podle
titulků/bundle ID a jedním `ancre_arrange` je uspořádá.

## Claude skill

`.claude/skills/ancre/SKILL.md` v repozitáři — workflow a recepty pro práci
s ancre z Claude Code.
