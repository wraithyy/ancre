# ancre

Hyprland-inspired tiling window manager pro macOS. Čisté veřejné Accessibility
API — žádné privátní CGS/SkyLight, žádný zásah do SIP.

- **Layouty**: dwindle (Hyprland), columns („scroll"), vlastní layouty ze
  šablon v configu
- **Workspaces 1–9** napříč monitory se stabilním přiřazením (přežije replug)
- **Workspace bar**: ikonky oken, drag&drop, badge notifikací, context menu
- **Hyper klávesa** (CapsLock) pro všechny zkratky + myší módy (hyper+drag)
- **Animace** s automatickým fallbackem pro pomalé appky
- **AI ready**: unix socket + `ancrectl` CLI + MCP server + Claude skill

## Instalace a spuštění

```sh
swift build            # celý balíček
swift test             # unit testy
Scripts/bundle.sh      # sestaví .build/ancre.app
open .build/ancre.app
```

Při prvním spuštění si app vyžádá **Accessibility** permission (System
Settings → Privacy & Security → Accessibility) a čeká, dokud ji nedostane.
Event tap vyžaduje i **Input Monitoring**.

> ⚠️ Spuštění přemapuje CapsLock→F18 (hidutil) a začne přeskládávat okna.
> Revert remapu (kdyby app spadla bez úklidu):
> `hidutil property --set '{"UserKeyMapping":[]}'`

## Ovládání

Hyper = CapsLock (změna: `[hyper].key`). Podržení hyperu > 2 s zobrazí
**cheatsheet všech zkratek**.

| Zkratka | Akce |
|---|---|
| `hyper+h/j/k/l` | fokus směrem |
| `hyper+shift+h/j/k/l` | prohodit okno směrem |
| `hyper+šipky` | resize (sousedi uhýbají) |
| `hyper+1..9` | přepnout workspace |
| `hyper+shift+1..9` | přesunout fokusované okno na workspace |
| `hyper+v` | float / zpět do dlaždic |
| `hyper+f` | fullscreen toggle |
| `hyper+t` / `hyper+shift+t` | layout scroll / dwindle |
| `hyper+a` | adoptovat frontmost okno do aktuální workspace |
| `hyper+p` | pauza tilingu (toggle) |
| `hyper+r` | rescan + přeskládat vše |
| `hyper+,` / `hyper+.` | fokus předchozí/další monitor |

**Myš**: `hyper+levé táhnutí` = přesun okna (dlaždice se vytáhne z mřížky;
puštění nad dlaždicí ji vloží vedle — ukazuje placeholder), `hyper+pravé
táhnutí` = resize (u dlaždic živě přerovnává sousedy). Bar: klik = přepnutí
workspace, klik na ikonku = fokus okna, drag ikonky = přesun okna, pravý
klik = menu (float, fullscreen, přesun, layout).

**Menubar ◱**: pauza tilingu, přeskládání, seznam monitorů (klik kopíruje
stabilní ID pro config), otevření/reload configu.

## Konfigurace

`~/.config/ancre/ancre.toml` — vytvoří se z defaultů při prvním
spuštění. Kompletní katalog klíčů s defaulty: `Sources/Config/default.toml`.
Změny aplikuje **Reload config** v menubar menu (nebo `ancrectl
reload-config`) bez restartu. Chyba v configu nikdy neshodí app — fallback
na defaulty s warningem v logu.

Přehled sekcí:

| Sekce | Co řídí |
|---|---|
| `[general]` | gaps, animace (`animations`, `animation-duration-ms`, `animations-exclude`), `default-layout`, `language` ("en"/"cs") |
| `[hyper]` | fyzická klávesa hyperu |
| `[keybindings]` | zkratky → commandy; **merguje se s defaulty** (default vypneš prázdným stringem) |
| `[workspaces]` | workspace → monitor (stabilní ID `vendor:model:serial` nebo část názvu) |
| `[workspace-labels]` | per-workspace: `name`, `icon` (emoji), `show-number`, `hide-when-empty`, `layout` |
| `[app-workspaces]` | bundle ID → workspace pro nová okna |
| `[custom-layouts]` | vlastní layouty: `"master" = "h(0.6, *, v(0.5, *, *))"` — `h`/`v` split s ratiem, `*` slot; přebytek oken se stackuje do posledního slotu |
| `[theme]` | sdílené barvy (`accent`, `background`, hex `#RRGGBB[AA]`) |
| `[bar]` | enabled, pozice (`position`, `align`, `offset-x/y`), rozměry (`height`, `icon-size`, paddingy, radiusy, `spacing`), barvy (`background-color`, `accent-color`, `float-color`, `badge-color`), typografie (`font-size`, `font-family`), `opacity`, `active-opacity`, `ring-width`, `max-icons` |
| `[border]` | rámeček fokusu: `enabled`, `color`, `width`, `radius` |
| `[help]` | cheatsheet: `enabled`, `delay-ms`, `opacity`, `font-size`, `columns`, `corner-radius` |

## Skriptování a AI (CLI · MCP · skill)

Vše jde přes command bus, vystavený na unix socketu
`~/Library/Application Support/ancre/ancre.sock` (práva 0600 — ovládá jen tvůj uživatel).

**CLI** (`.build/debug/ancrectl`):

```sh
ancrectl state            # JSON: monitory, workspaces, okna (id, titul, bundle, float, fokus)
ancrectl workspace 3      # libovolný command ze zkratek
ancrectl layout scroll
ancrectl move-window 4495 8   # cílené verby: move-window / focus-window / set-floating <id> ...
ancrectl reload-config
```

Odpověď `ok`, `error: ...` (exit 1), nebo JSON.

**MCP server** (`mcp/index.js`, registrace
`claude mcp add ancre --scope user -- node .../mcp/index.js`): tools
`ancre_state`, `ancre_command`, `ancre_move_window`,
`ancre_focus_window`, `ancre_set_floating`. Agent tak umí „připrav mi
workspace na review" — najde okna podle titulů/bundle ID a přeuspořádá je.

**Claude skill**: `.claude/skills/ancre/SKILL.md` — workflow a recepty.

## Architektura

Command bus: vše (hotkey, bar, myš, IPC) → `Command` → `WM.dispatch` →
`[Effect]` → AX vrstva. Moduly: `WMCore` (čistý stav+reducer, unit-testable),
`LayoutEngine` (dwindle/columns/šablony), `AXBridge` (AXObserver, tracking,
parking, monitory), `InputSystem` (hidutil + CGEventTap), `Bar` (SwiftUI),
`Animator`, `Config`, `App` (glue). Detaily: `CLAUDE.md` a `docs/PLAN.md`.

Klíčový invariant: veškerý stav žije na axQueue; skryté workspaces se
„parkují" za hranu unionu displayů (macOS okna nejde skrýt přes veřejné API).

## Troubleshooting

- **Okna se nepřeskládají** → `hyper+r` (rescan + retile); typicky po startu
  při zamčené obrazovce.
- **Okno „zmizelo"** → je zaparkované/floatnuté; bar ho ukáže (čárkovaný ring
  = float), pravý klik → Fokusovat.
- **CapsLock se chová divně po pádu** → `hidutil property --set
  '{"UserKeyMapping":[]}'`.
- Log: app loguje přes NSLog — `log stream --predicate 'process == "ancre"'`.
