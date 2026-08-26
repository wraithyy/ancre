# Review dokumentačního webu — 9 person + kontrola úplnosti (2026-08-26)

Persony: junior dev, docs reviewer, junior mac user, Hyprland veterán,
designer, frontend dev, první MacBook, macOS poweruser, kancelářský manažer.
Desátý agent porovnal web proti kódu (Command.parse, MCPServer, default.toml,
README, PLAN).

## Kritické (shoda více person)

1. **Chybí Uninstall / vypnutí** — revert hidutil, smazání app/configu,
   revoke permissions, LaunchAgent. Nová sekce v installation nebo vlastní
   stránka. (junior mac, poweruser, manažer, completeness)
2. **CapsLock varování je slabé a pozdě** — vysvětlit CO se stane s CapsLock
   (velká písmena?), jak změnit klávesu (`[hyper].key` s příkladem), Karabiner
   konflikt (poweruser: dvě remap vrstvy se perou). Přesunout výš.
3. **Instalace předpokládá vývojáře** — chybí prerekvizity (Xcode CLT, verze
   Swift/macOS), `git clone` přímo na stránce, Gatekeeper/ad-hoc podpis
   poznámka, Homebrew (aspoň "coming soon"), autostart/LaunchAgent,
   onboarding okno (`ancre --onboarding`) web vůbec nezná.
4. **Cesta k `ancrectl`** nekonzistentní: installation mluví o bundle.sh,
   scripting o `.build/debug/ancrectl`; release/Homebrew cesta chybí.
5. **Chování vůči macOS Spaces / native fullscreen / Stage Manager** — nikde.
   Pro yabai/Aerospace/Hyprland příchozí otázka č. 1.

## Úplnost vs. kód (fakta, agent ověřil v Sources)

Web faktově nelže, ale nepokrývá:

- commandy `preset`, `preset-save`, `open-config` (Command.parse je má)
- MCP tool `ancre_arrange` (tabulka má 5/6 nástrojů)
- `ancrectl subscribe` (JSON event stream)
- priority list `[workspaces] "1" = ["PHL", "Built-in"]`
- `reload-config` = jen IPC/menu, není bindovatelný — nevysvětleno
- README sekce "Coming from Hyprland" + known gaps (window rules, exec-once,
  globální gaps, scratchpad = 1 app) na webu chybí

## Vysoká priorita

- **Kompletní command reference** — tabulka všech command stringů
  (gramatika `[keybindings]` formátu, argumenty) + JSON schéma/ukázka
  `ancrectl state`. (Hyprlanďan, poweruser)
- **Troubleshooting tenký** — permission neudělena/ztracena po OS update
  (`tccutil`), MCP se neobjeví v Claude Code, bar na notchi, "vypnutí před
  screen sharem" recept (manažer).
- **index.mdx "Where next"** nelinkuje polovinu stránek (layouts,
  multi-monitor, bar, troubleshooting).
- **Glosář / první výskyt pojmů** — tiling, workspace, floating, bundle ID
  (jak zjistit), notch, unix socket. (první MacBook, junior mac)
- **Use-case recepty** — "Teams call + poznámky", "review workspace" —
  dokumentace je čistě referenční. (manažer)
- **OG/Twitter meta** chybí (sdílené odkazy bez náhledu). Pozn.: nález
  "chybí sitemap" je FALEŠNÝ — Starlight ji generuje, ověřeno v build logu.
- Fonty: přejít na `latin` subsety @fontsource (úspora KB).

## Nízká

- architecture.md odkazuje na CLAUDE.md/PLAN.md bez GitHub linku; přidat
  "developer-only" poznámku.
- controls ↔ scripting bez vzájemného odkazu ("každá zkratka má CLI
  ekvivalent").
- custom-layouts: chybí složitější příklad než 3 okna.
- Sémantika focus/move na kraji monitoru (wrap? nic? přeskok?) — doplnit větu.

## Media plán (designer + frontend)

Jediné tvrdé porušení brand manuálu: index nemá "visible workspace/layout
example". Web nemá ani jeden obrázek.

Styl: reálný desktop na Ink pozadí, žádné mocky/glow. Uložení:
`website/src/assets/media/<page>/<page>-<popis>.{png,mp4}`. PNG 2x retina
přes `astro:assets` Image (auto WebP, žádný CLS). Video: H.264 MP4
`<video autoplay muted loop playsinline preload="none">` s `poster` —
ne GIF (velké, bez pause).

Top 5 assetů k výrobě:

1. `index-dwindle-workspace.png` — 3–4 okna v dwindle (plní brand manuál)
2. `layouts-dwindle-scroll-stack.png` — 3-panel, stejná okna, tři layouty
3. `bar-positions-menubar-notch.png` — 4-panel srovnání pozic
4. `controls-hyper-drag-move.mp4` — drag s placeholder preview
5. `controls-cheatsheet-overlay.png` — hyper held 2 s

Další: bar drag&drop, multi-monitor replug, config reload, MCP demo
(tabulka v designer reportu).
