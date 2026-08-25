# applland

Hyprland-inspired tiling window manager pro macOS. Swift, čisté veřejné
Accessibility API — žádné privátní CGS/SkyLight API, žádný SIP zásah.
Plán + milestones: `docs/PLAN.md` (M1 hotový, M2 task 2.1 hotová — multi-monitor
placement + migrace; další M3 bar). `AGENTS.md` = tytéž instrukce pro cizí
agenty (OpenHands), hlavně co v Linuxovém sandboxu nejde ověřit.

## Build & test

```
swift build            # celý balíček
swift test             # unit testy (WMCore, LayoutEngine, Config)
Scripts/bundle.sh      # sestaví .build/applland.app (ad-hoc podpis, stabilní identifier)
open .build/applland.app
```

Žádný .xcodeproj — čistý SPM + bundle skript. Runtime vyžaduje Accessibility
(+ Input Monitoring) permission; bez ní app čeká a polluje AXIsProcessTrusted.
Pozor: spuštění appky přemapuje CapsLock→F18 (hidutil) a začne přeskládávat
okna — netestovat bezhlavě. Revert: `hidutil property --set '{"UserKeyMapping":[]}'`.

## Architektura

Command bus: všechno (hotkey, bar, drag&drop) → `Command` enum →
`WM.dispatch(Command, state:)` → `[Effect]` → AX vrstva effecty vykoná.
Jedna cesta pro každou operaci, žádné obcházení.

| Modul | Role |
|---|---|
| `Sources/WMCore` | čistý stav + reducer (WMState, Command, Effect). ZÁKAZ AX/AppKit importů — musí zůstat unit-testable. Definuje `Layout` protokol; `Monitor.swift` = multi-monitor placement (`WorkspaceAssignment.plan`, `WM.reconcileMonitors`) |
| `Sources/LayoutEngine` | implementace layoutů (DwindleLayout; scroll = M5). Stateless value typy |
| `Sources/AXBridge` | AXUIElement/AXObserver, WindowTracker + delegate, DisplayManager (stabilní ID displayů + reconfigurace), OffscreenParking (parking workaround izolovaný ZDE — při rozbití macOS updatem se patchuje jen tento soubor) |
| `Sources/InputSystem` | hidutil remap, CGEventTap. Nezávislý na WMCore — resolvuje jen binding stringy ("hyper-shift-h") přes callback |
| `Sources/Config` | TOMLKit schema + loader, `~/.config/applland/applland.toml`, validace s warningy (nikdy crash na config typo) |
| `App/` | main.swift + WindowManagerController (glue AX↔WMCore↔Input) |

## Threading — nejdůležitější invariant

Veškerý WM stav (WMState, cache v controlleru i WindowTrackeru) žije na
**axQueue** (`AXRunLoopThread.shared`, AXBridge). AXObserver callbacky tam
hoppují, controller marshaluje přes `tracker.perform {}`. Nikdy nemutovat
stav z jiného kontextu (Timer, notifikace, tap thread). CGEventTap callback
musí zůstat triviální (jinak ho systém killne timeoutem).

## Konvence

- Swift language mode v5 (AX C API nejsou Sendable; nepřepínat na v6 bez plánu)
- `AXWindowID` (UInt32, CGWindowID) ↔ `WMCore.WindowID` je 1:1 mapování
- Souřadnice: AX = top-left origin, NSScreen = bottom-left; konverze JEN v
  `DisplayManager.cgRect(fromNSScreenRect:primaryHeight:)`
- Monitor ID: hardware-derived `vendor:model:serial` (ne CGDirectDisplayID, ten
  se mezi sessions mění). Parking cílí na union všech displayů, ne na jeden
- Workspace placement je čistá funkce (workspace names, config, connected
  monitors) → replug reprodukuje totéž; žádná imperativní migrace
- Okna odmítající frame: neválčit — snap-back má limit 3 pokusů, pak akceptovat
- `ponytail:` komentáře = vědomé zkratky s known ceiling; při úpravě okolí zvážit
- Command stringy v configu ↔ `Command.parse` držet v sync se
  `Sources/Config/default.toml`
- Testy: čistá logika (WMCore/LayoutEngine/Config) má unit testy; AX/Input
  runtime chování se ověřuje manuálně (vyžaduje permissions + display session)
