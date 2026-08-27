---
title: Skriptování a AI
description: ancrectl CLI, unix socket, vestavěný MCP server a Claude skill.
sidebar:
  order: 7
---

Cokoli zvládne zkratka, zvládne i skript nebo AI agent: „připrav mi review
workspace" je jeden příkaz. Každá operace jde přes stejný command bus,
vystavený na unix socketu
`~/Library/Application Support/ancre/ancre.sock` (práva 0600 — ovládá jen
tvůj uživatel). Pokud ancre neběží, každé volání `ancrectl` vypíše
`cannot connect to <path> — is ancre running?` a skončí s exit 1.

<!-- media (shotlist: scripting.md):
![ancrectl v terminálu: výstup state a přesun okna s viditelným efektem](../../../assets/scripting-ancrectl.gif)
![MCP příkaz z CLI okamžitě přeskládává okna](../../../assets/scripting-mcp-demo.gif)
-->


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

MCP ([Model Context Protocol](https://modelcontextprotocol.io)) umožňuje AI
asistentům jako Claude volat nástroje přímo — tady ovládat tvoje okna.
Server je **vestavěný v CLI** — žádný Node. Registrace do Claude Code:

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

## MCP s libovolným agentem

`ancrectl mcp` je stdio MCP server — jedna binárka, žádný Node, žádný
checkout repa. Ovládat ancre umí každý MCP klient, který dokáže spustit
lokální proces. Dvě pravidla platí všude:

- **ancre musí běžet.** Bridge jen přeposílá na socket; bez ancre vrátí každý
  tool call `error: cannot connect …`.
- **GUI klienti nedědí PATH z shellu.** V desktopových appkách (Claude
  Desktop, Cursor, Antigravity, ChatGPT) použij absolutní cestu —
  `/opt/homebrew/bin/ancrectl` u Homebrew instalace, nebo
  `/cesta/k/repu/.build/release/ancrectl` ze zdrojáků.

| Klient | Kam server patří |
|---|---|
| Claude Code | `claude mcp add ancre --scope user -- ancrectl mcp` |
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` (Settings → Developer → Edit Config) |
| ChatGPT desktop · Codex CLI · Codex IDE | `codex mcp add ancre -- ancrectl mcp` → společný `~/.codex/config.toml` |
| Cursor | `~/.cursor/mcp.json` (projektově: `.cursor/mcp.json`) |
| Antigravity (2.0 · IDE · CLI) | `~/.gemini/config/mcp_config.json` (workspace: `.agents/mcp_config.json`) |
| opencode | `~/.config/opencode/opencode.json` (projektově: `opencode.json`) |
| pi | `~/.pi/agent/mcp.json` (projektově: `.pi/mcp.json`) |
| OpenClaw | `openclaw mcp add ancre --command ancrectl --arg mcp` → `~/.openclaw/openclaw.json` |
| Hermes | `~/.hermes/config.yaml`, sekce `mcp_servers:` |

### Dialekt `mcpServers`

Claude Desktop, Cursor, Antigravity a pi berou stejný tvar (Cursor chce
`"type": "stdio"`, Antigravity používá u remote serverů `serverUrl` místo
`url` — pro nás nepodstatné):

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

ChatGPT desktop appka, Codex CLI a Codex IDE rozšíření sdílí jednu konfiguraci,
takže ancre registruješ jen jednou:

```sh
codex mcp add ancre -- ancrectl mcp
codex mcp list
```

```toml
# ~/.codex/config.toml — totéž ručně
[mcp_servers.ancre]
command = "/opt/homebrew/bin/ancrectl"
args = ["mcp"]
```

ChatGPT v prohlížeči mluví jen se *vzdálenými* (HTTP) MCP servery — lokální
window manager odtud není dosažitelný. Použij desktop appku.

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
openclaw mcp status        # transport, tools, zdraví
```

Záznam skončí v `~/.openclaw/openclaw.json` pod `mcp.servers`; server, který
nechce nastartovat, diagnostikuje `openclaw mcp doctor`.

### Hermes

```yaml
# ~/.hermes/config.yaml
mcp_servers:
  ancre:
    command: "ancrectl"
    args: ["mcp"]
```

`/reload-mcp` v běžící session načte změny konfigurace.

### Víc agentů zároveň

Mezi klienty není co koordinovat: každý si spustí vlastní child proces
`ancrectl mcp` a **všechen stav žije v ancre**, ne v bridgi. Každý tool call je
jeden socket request do téhož command busu, takže se requesty serializují v
pořadí příchodu na `axQueue` — dva agenti stav nerozbijí, ale **můžou si
navzájem přeskládat layout**.

Co to znamená v praxi:

- **Čti před zápisem.** `ancre_state` těsně před `ancre_arrange`; ID oken
  vznikají a mizí s tím, jak se okna otevírají a zavírají.
- **Jeden `ancre_arrange` je lepší než deset commandů.** Aplikuje layouty,
  rozmístění, aktivní workspaces i finální fokus v jednom requestu, takže se
  druhý agent nevloží do půlky.
- **Předávej přes presety.** `preset-save review` (přes `ancre_command`)
  uloží aktuální rozložení jako checkpoint; jiný agent ho obnoví přes
  `preset review`. Levný společný slovník mezi agenty, kteří jinak nemají
  žádný sdílený kontext.
- **Watcher nepotřebuje MCP.** `ancrectl subscribe` streamuje jeden JSON
  event na řádek — lepší než pollovat `ancre_state` z agenta na pozadí.
- **Agentům, kterým věříš méně, zužuj plochu.** Klienti s filtrem toolů
  (`toolFilter` v OpenClaw, `tools.include` v Hermesu) můžou vystavit jen
  read-only `ancre_state` a nic dalšího.

Bezpečnost: socket má mód 0600, takže cokoli běžícího pod tvým uživatelem má
plnou kontrolu nad tvými okny — MCP bridge nepřidává žádnou další
autentizaci. Ber „umí mluvit s ancre“ jako „umí mi přeskládat desktop“ a
neproxuj socket na stroj, který ti nepatří.

## Claude skill

`.claude/skills/ancre/SKILL.md` v repozitáři — workflow a recepty pro práci
s ancre z Claude Code.
