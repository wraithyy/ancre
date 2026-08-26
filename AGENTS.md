# ancre — instrukce pro agenty

Hyprland-inspired tiling window manager pro macOS. Swift, veřejné Accessibility
API, žádný SIP zásah. Detailní architektura a konvence: `CLAUDE.md`.
Plán a milestones: `docs/PLAN.md`.

## Než něco spustíš — přečti si tohle

Projekt je **macOS-only**: `AppKit`, `ApplicationServices` (AX API),
CoreGraphics display API. `Package.swift` má `platforms: [.macOS(.v14)]`.

V Linuxovém sandboxu (default OpenHands runtime) **nic z toho nepřeloží** —
`swift build` ani `swift test` tam nedávají smysl a chybějící `import AppKit`
není bug k opravě. Pokud běžíš v Linux containeru:

- edituj Swift kód surgical, bez „opravování" macOS importů,
- neměň `Package.swift` platforms ani language mode (v5 je vědomé, viz CLAUDE.md),
- do reportu napiš, že build/testy jsou **UNVERIFIED** (spustí je maintainer na Macu).

Není tu žádný setup script — v Linuxu není co instalovat, na macOS stačí Xcode
toolchain (Swift 6.0, language mode v5).

## Build & test (jen macOS 14+)

```
swift build            # celý balíček
swift test             # unit testy (WMCore, LayoutEngine, Config)
Scripts/bundle.sh      # .build/ancre.app (ad-hoc podpis)
```

Žádný `.xcodeproj`. CI (`.github/workflows/`) běží na `macos-15` runneru:
`ci.yml` na push/PR do `main` (mimo změny jen v `website/`, `docs/`, `*.md`)
dělá `swift build` → `swift test` → `Scripts/bundle.sh`; `release.yml` na tagu
`vX.Y.Z` staví universal (arm64+x86_64) bundle a publikuje GitHub Release;
`deploy-docs.yml` nasazuje `website/` na GitHub Pages (běží na
`ubuntu-latest`, jen Astro build — nesouvisí se Swift kódem).

## NIKDY nespouštěj appku automatizovaně

`open .build/ancre.app` udělá dvě globální věci: přemapuje **CapsLock→F18**
přes `hidutil` a začne **přeskládávat všechna okna** na ploše. Vyžaduje
Accessibility + Input Monitoring permission a živou display session.

Revert remapu, pokud už appka běžela a zůstala v divném stavu:

```
hidutil property --set '{"UserKeyMapping":[]}'
```

Runtime chování (AX, event tap, displaye) se ověřuje **ručně** na Macu, ne
v agentním běhu.

## Co je testovatelné a co ne

| Vrstva | Verifikace |
|---|---|
| `Sources/WMCore`, `Sources/LayoutEngine`, `Sources/Config` | XCTest (`swift test`) — čistá logika, sem přidávej testy |
| `Sources/AXBridge`, `Sources/InputSystem`, `App/` | jen ruční test na Macu s permissions |

Když měníš čistou logiku, přidej test. Když měníš AX/Input vrstvu, popiš
v reportu ruční scénář, kterým to maintainer ověří (viz `docs/PLAN.md`,
sekce Verification).

## Struktura

| Cesta | Role |
|---|---|
| `Sources/WMCore` | stav + reducer (`WMState`, `Command`, `Effect`, multi-monitor placement). ZÁKAZ AX/AppKit importů |
| `Sources/LayoutEngine` | layouty (`DwindleLayout`), stateless value typy |
| `Sources/AXBridge` | AXUIElement/AXObserver, `WindowTracker`, `DisplayManager`, `OffscreenParking` |
| `Sources/InputSystem` | hidutil remap, CGEventTap |
| `Sources/Config` | TOMLKit schema, `~/.config/ancre/ancre.toml` |
| `Sources/Animator` | animace při přeskládávání oken |
| `Sources/Bar` | workspace bar (menu bar / notch) |
| `App/` | executable target `ancre`: `main.swift` + `WindowManagerController` (glue) |
| `ancrectl` | executable target, CLI klient pro socket/MCP |

## Dvě věci, kde dokumentace lže, kdybys je nečetl

1. **„Žádné privátní API"** platí s jednou vědomou výjimkou:
   `_AXUIElementGetWindow` přes `dlsym` v `Sources/AXBridge/AXWindow.swift`
   (jediná cesta ke stabilnímu `CGWindowID`, dělá to každý AX window manager).
   Nepřepisovat, nehlásit jako nález.
2. **Threading**: veškerý WM stav žije na `axQueue` (`AXRunLoopThread.shared`).
   Nikdy nemutuj stav z Timeru, notifikace nebo tap threadu. CGEventTap
   callback musí zůstat triviální, jinak ho systém killne timeoutem.
