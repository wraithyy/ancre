# applland — Hyprland-inspired tiling WM pro macOS

## Context

macOS nemá tiling WM s ergonomií Hyprlandu. Existující nástroje: yabai (vyžaduje SIP zásah, křehké), AeroSpace (stabilní, ale bez animací, baru a myších módů). Cíl: vlastní WM od nuly ve Swiftu nad veřejným Accessibility API — stabilita a ergonomie jako priorita, plná kontrola nad layouty, barem a UX.

**Rozhodnutí z grill fáze (schválená uživatelem):**
- Od nuly, Swift, veřejné AX API — žádné privátní API, žádný SIP zásah
- Virtuální workspaces (AeroSpace styl: skrytá okna odsunutá mimo viewport), per monitor
- Hyper key vestavěně: hidutil remap CapsLock→F18 + CGEventTap, vše konfigurovatelné
- Vlastní SwiftUI bar per monitor, vedle systémové menu bar
- Adaptivní animace: 150–200 ms easing, per-app latence (EMA), auto-vypnutí pro pomalé appky

## Requirements

- **Layouty**: dwindle (Hyprland default) + niri-style scroll columns; `LayoutEngine` protokol pro vlastní layouty, přepínání per-workspace
- **Klávesnice** (vše remapovatelné v TOML): hyper+hjkl focus, hyper+shift+hjkl přesun okna, hyper+šipky resize, hyper+1..9 workspace, hyper+shift+1..9 přesun okna do workspace, toggle floating, toggle fullscreen
- **Myš**: hyper+left-drag přesun/float, hyper+right-drag resize; "release" mód = okno vyjmuté z mřížky, volně pohyblivé
- **Workspaces**: per monitor, stabilní ID monitorů (name+serial přes IOKit, ne CGDirectDisplayID); při odpojení monitoru migrace workspaces na zbývající, při připojení zpět
- **TOML config**: keybinds, workspace→monitor, app→workspace pravidla, animace, gaps, layouty; hot-reload (FSEvents)
- **Bar**: workspaces + ikony appek, click-to-switch, drag&drop oken mezi workspaces, right-click menu
- **Výkon**: event-driven (AXObserver, NSWorkspace notifikace, CGDisplay callbacks), žádný polling, cache AX čtení

## Architektura

Čistý SPM balíček + `Scripts/bundle.sh` (ad-hoc podpis, stabilní bundle
identifier kvůli permission promptům) — Xcode projekt se ukázal jako
nepotřebný, bundle skript dělá totéž bez .pbxproj konfliktů. Menu bar app,
unsandboxed, permissions: Accessibility + Input Monitoring. Závislost:
**TOMLKit** (SPM).

```
applland/
  App/                    AppDelegate, menu bar, permission onboarding
  Sources/AXBridge/       AXUIElement/AXObserver, window cache, DisplayManager, OffscreenParking
  Sources/WMCore/         window tree, workspace model, focus state — čistá logika, unit-testable
  Sources/LayoutEngine/   Protocol.swift, Dwindle.swift, ScrollColumns.swift
  Sources/InputSystem/    CGEventTap, hidutil lifecycle, mouse módy
  Sources/Bar/            SwiftUI overlay okna per monitor
  Sources/Config/         TOMLKit schema, validace, hot-reload
  Sources/Animator/       CVDisplayLink interpolace, per-app latence EMA
  Sources/Config/default.toml
  Scripts/bundle.sh, Scripts/Info.plist
```

**Stav**: M1 hotový, M2 task 2.1 hotová. Bar (M3) a Animator (M4) jsou zatím
prázdné stuby. LaunchAgent plist ještě nevznikl.

**Threading**: jedna dedikovaná serial `axQueue` vlastní veškerou AX práci (AXObserver runloop source) i mutace WMCore stavu — žádné races mezi eventy a příkazy. UI a event tap do ní marshallují async.

**Command bus**: vše (hotkey, bar klik, drag&drop) produkuje `Command` enum → `WMCore.dispatch(Command)`. Jedna cesta pro každou operaci.

**Klíčové techniky** (detaily pro implementátory):
- Discovery: `NSWorkspace.didLaunchApplicationNotification` → `AXUIElementCreateApplication(pid)` → AXObserver na `kAXWindowCreated/UIElementDestroyed/FocusedWindowChanged/Moved/Resized/Miniaturized`; existující okna přes `kAXWindowsAttribute`
- Move/resize: set position+size, re-read skutečný frame, 1× retry při divergenci; okna co odmítají resize → auto-float
- Anti-self-resize: debounce 50–100 ms na Moved/Resized, porovnat s očekávaným tiled frame, snap back (flag pro vlastní příkazy proti feedback loop)
- Off-viewport parking: macOS clampuje pozice — workaround (offset za hranu + případně shrink/move/restore) izolovaný v `OffscreenParking.swift` + self-test při startu
- Event tap: handle `.tapDisabledByTimeout/.tapDisabledByUserInput` → okamžitý re-enable; callback jen dispatch async
- hidutil: apply při startu, re-apply po sleep/USB keyboard swap (IOHIDManager notifikace)
- Animace: CVDisplayLink, easing 150–200 ms, per-bundle-id EMA latence setFrame→AXResized; EMA > frame budget → instant-only
- Bar drag&drop: SwiftUI `Transferable` (window id + zdrojový workspace) → `Command.moveWindowToWorkspace`

## Risks

| Riziko | Mitigace |
|---|---|
| AX flakiness (Electron, Java) | per-app EMA, retry-once, TOML float-by-default list |
| Okna odmítající resize | detekce diverence → auto-float, nebojovat |
| macOS update změní clamp chování | workaround izolovaný v OffscreenParking + startup self-test + diagnostika |
| Event tap killnutý systémem | re-enable handler, non-blocking callback |
| Výkon při mnoha oknech | event-driven, cache, rebuild layoutu jen při strukturální změně |

## Tasks

### Milestone 1 — MVP (single monitor, dwindle, hotkeys, workspaces)

## Task 1.1: Založit SPM balíček + moduly + TOMLKit — HOTOVO
- **Agent**: claude
- **Files**: celá kostra dle stromu výše, App/, Package.swift, Scripts/Info.plist
- **Depends on**: none
- **Acceptance**: `swift build` projde; app se spustí jako menu bar item; permission onboarding požádá o Accessibility
- **Prompt seed**: Založ Xcode projekt applland (menu bar app, unsandboxed, LSUIElement), SPM lokální moduly AXBridge/WMCore/LayoutEngine/InputSystem/Config/Animator/Bar, TOMLKit dependency, Info.plist s usage descriptions, AXIsProcessTrustedWithOptions onboarding.

## Task 1.2: AXBridge — discovery a tracking oken
- **Agent**: claude
- **Files**: Sources/AXBridge/ (AXObserverManager.swift, WindowCache.swift, AXWindow.swift)
- **Depends on**: 1.1
- **Acceptance**: debug log ukazuje živě: launch/terminate appky, created/destroyed/focused/moved/resized okna, enumerace existujících oken při startu
- **Prompt seed**: Implementuj AX vrstvu na dedikované axQueue: NSWorkspace notifikace → AXUIElementCreateApplication → AXObserver (windowCreated, uiElementDestroyed, focusedWindowChanged, moved, resized, miniaturized), cache framů, enumerace kAXWindowsAttribute při startu.

## Task 1.3: WMCore — window tree, workspace model, Command bus
- **Agent**: claude
- **Files**: Sources/WMCore/ (LayoutTree.swift, Workspace.swift, Monitor.swift, Command.swift, WM.swift), Tests/WMCoreTests/
- **Depends on**: none (čistá logika, paralelně s 1.2)
- **Acceptance**: unit testy: dwindle strom insert/remove/swap/focus-neighbor, workspace přiřazení; `swift test` zelené
- **Prompt seed**: Čistý stavový model bez AX závislostí: rekurzivní LayoutTree (leaf/split), Workspace s layoutem, Monitor s ordered workspaces, Command enum + dispatch. Testy na tree operace a hjkl navigaci.

## Task 1.4: LayoutEngine — protokol + Dwindle
- **Agent**: claude
- **Files**: Sources/LayoutEngine/ (Protocol.swift, Dwindle.swift), testy
- **Depends on**: 1.3
- **Acceptance**: unit test: N oken → správné framy s gaps pro dané viewport rozměry
- **Prompt seed**: LayoutEngine protokol (windows+viewport+gaps → frames, insert/remove/move/resize-hooks), Dwindle implementace (Hyprland sémantika: střídavé dělení, split ratio).

## Task 1.5: InputSystem — hidutil remap + CGEventTap + default binds
- **Agent**: claude
- **Files**: Sources/InputSystem/ (EventTapManager.swift, HidutilRemap.swift, Keybinding.swift)
- **Depends on**: 1.3
- **Acceptance**: CapsLock funguje jako hyper; hyper+hjkl/shift+hjkl/1..9 emitují správné Command; tap přežije timeout disable (re-enable log)
- **Prompt seed**: hidutil UserKeyMapping CapsLock→F18 (apply při startu, revert při quit, re-apply po wake/IOHID změně), CGEventTap s re-enable handlingem, mapování kombinací na Command enum.

## Task 1.6: Integrace — tiling enforcement + focus + virtuální workspaces
- **Agent**: claude
- **Files**: Sources/AXBridge/OffscreenParking.swift, Sources/WMCore/WM.swift, App/ wiring
- **Depends on**: 1.2, 1.4, 1.5
- **Acceptance**: manuální: 4 okna se tilují, hyper+hjkl přepíná focus, hyper+shift+hjkl prohazuje, hyper+2 skryje/obnoví workspace okamžitě, self-resize okna snapne zpět
- **Prompt seed**: Propoj AX eventy → WMCore → layout → AX setFrame. Anti-self-resize debounce+snapback, focus set (AXFocused + NSRunningApplication.activate), OffscreenParking se startup self-testem.

## Task 1.7: Config — TOML schema + načtení keybinds
- **Agent**: claude
- **Files**: Sources/Config/ (Schema.swift, Loader.swift), Resources/default.toml
- **Depends on**: 1.5
- **Acceptance**: binds z ~/.config/applland/applland.toml přepíší defaulty; nevalidní config → čitelná chyba, fallback na defaulty
- **Prompt seed**: TOMLKit schema: [keybindings], [general] (gaps, animace on/off), hyper klávesa konfigurovatelná. Validace s chybovými hláškami.

## Task 1.R: Review milestone 1
- **Agent**: code-reviewer
- **Files**: vše z M1
- **Depends on**: 1.6, 1.7
- **Acceptance**: žádné CRITICAL/HIGH nálezy
- **Prompt seed**: Review threading (vše AX na axQueue?), retain cykly AXObserver, event tap bezpečnost, feedback loops v anti-self-resize.

### Milestone 2 — Multi-monitor

## Task 2.1: Stabilní monitor ID + workspace→monitor assignment + migrace — HOTOVO (runtime ověřeno 2026-08-25, built-in + P34w-20)
- **Agent**: claude
- **Files**: Sources/WMCore/Monitor.swift, Sources/AXBridge/DisplayManager.swift, Config schema rozšíření
- **Depends on**: 1.R
- **Acceptance**: manuální: odpojení externího monitoru přesune jeho workspaces na vestavěný, připojení je vrátí; TOML `[workspaces]` assignment respektován
- **Prompt seed**: IOKit/CGDisplayCreateInfoDictionary stabilní ID, CGDisplayRegisterReconfigurationCallback, migrace workspaces s zachováním layoutů, hyper+, / hyper+. focus monitoru.

**Odchylky od seedu při implementaci:**
- Stabilní ID: `CGDisplayVendorNumber/ModelNumber/SerialNumber` (jednodušší než
  parsování `CGDisplayCreateInfoDictionary`, stejná stabilita). Panely se
  sériovým číslem 0 dostávají poziční suffix `#n`.
- Reconfigurace: `NSApplication.didChangeScreenParametersNotification`
  s 300 ms coalescingem místo `CGDisplayRegisterReconfigurationCallback` —
  AppKit ji posílá až po dosednutí konfigurace, žádný C callback ani filtrování
  begin/end flagů. Fallback na CG callback je zdokumentovaný v DisplayManageru.
- Místo imperativní migrace je placement čistá funkce
  (`WorkspaceAssignment.plan`): workspace jde na svůj monitor, když je
  připojený, jinak na první připojený. Replug tím reprodukuje totéž bez
  „migrate back" stavu, který by se mohl rozejít.
- Nechtěné vedlejší nálezy opravené tady, protože je multi-monitor stav zpřístupnil:
  `workspace N` / `move-to-workspace N` teď hledají workspace na všech
  monitorech (dřív jen na fokusovaném = no-op); přesun okna do skryté workspace
  ho parkuje (dřív zůstalo viditelné); parking cílí na union displayů (parkování
  za hranu jednoho displaye vysypalo okno na sousední).

**Nálezy z runtime ověření (opravené):**
- Config: TOML `gaps-inner = 8` (Int) neprošel striktním Double dekódováním →
  fatalError na bundled defaults. Lenientní Int→Double decode v `General`.
- macOS při odpojení monitoru asynchronně „zachraňuje" offscreen okna →
  vytáhl zaparkovaná okna viditelně na zbývající display. Controller teď
  trackuje parked set a při útěku okno re-parkuje (limit 3 pokusů).
- Bonus mimo scope 2.1: focus border (`App/FocusBorder.swift`) — overlay
  s accent rámečkem kolem fokusovaného okna; bez něj nebyl fokus vidět.

### Milestone 3 — Workspace bar

## Task 3.1: SwiftUI bar per monitor (zobrazení + click-to-switch) — HOTOVO (kód, runtime ověření uživatelem probíhá)
- **Agent**: claude
- **Files**: Sources/Bar/
- **Depends on**: 2.1
- **Acceptance**: bar na každém monitoru živě ukazuje workspaces + ikony appek, klik přepne
- **Prompt seed**: NSWindow (borderless, .statusBar level, canJoinAllSpaces) per monitor, SwiftUI obsah odebírající WMCore state stream, NSRunningApplication.icon.

## Task 3.2: Bar interakce — drag&drop + right-click menu
- **Agent**: claude
- **Files**: Sources/Bar/
- **Depends on**: 3.1
- **Acceptance**: přetažení ikony okna do jiného workspace ho přesune; right-click: přesunout/float/zavřít
- **Prompt seed**: Transferable s window id, dropDestination → Command.moveWindowToWorkspace, kontextové menu emitující Commands.

### Milestone 4 — Animace

## Task 4.1: Animator — adaptivní interpolace
- **Agent**: claude
- **Files**: Sources/Animator/
- **Depends on**: 1.R
- **Acceptance**: rychlé appky animují plynule; appka s uměle pomalým AX (test) se auto-přepne na instant; TOML toggle funguje
- **Prompt seed**: CVDisplayLink loop, ease-out 150–200 ms, per-bundle-id EMA latence setFrame→AXResized, threshold → instant-only, koordinace s anti-self-resize flagem.

### Milestone 5 — niri layout + custom layouty

## Task 5.1: ScrollColumns layout + per-workspace přepínání
- **Agent**: claude
- **Files**: Sources/LayoutEngine/ScrollColumns.swift, Config rozšíření
- **Depends on**: 1.R
- **Acceptance**: workspace v niri módu: sloupce, horizontální scroll fokusem, hyper+hjkl naviguje; hot-switch layoutu bez restartu
- **Prompt seed**: Niri sémantika: ordered columns, okna ve sloupci vertikálně, viewport scroll za fokusem. LayoutEngine protokol dokumentovat jako plugin API.

### Milestone 6 — Polish

## Task 6.1: App→workspace pravidla + config hot-reload
- **Agent**: claude
- **Files**: Sources/Config/, Sources/WMCore/Rules.swift
- **Depends on**: 2.1
- **Acceptance**: appka z TOML pravidla se otevře ve svém workspace; editace TOML se projeví bez restartu
- **Prompt seed**: [[rules]] (bundle-id/title regex → workspace, float), FSEvents watch, diff-aware reload (nepřerovnávat existující okna).

## Task 6.2: Myší módy — hyper+drag move/resize + release mód
- **Agent**: claude
- **Files**: Sources/InputSystem/MouseModes.swift
- **Depends on**: 4.1
- **Acceptance**: hyper+left-drag plynule přesouvá (okno floatne), hyper+right-drag resizuje, toggle release mód vyjme okno z mřížky a vrátí zpět
- **Prompt seed**: CGEventTap mouse eventy při hyper, drag → přímé setFrame (bez animace), drop na tiled workspace → volba insert do mřížky vs zůstat floating.

## Task 6.3: Finální review + security check
- **Agent**: code-reviewer
- **Files**: celý projekt
- **Depends on**: vše
- **Acceptance**: žádné CRITICAL/HIGH
- **Prompt seed**: Celkový review: memory (AX refy), CPU idle profil, permission handling, hidutil revert při crash.

## Out of scope

- App Store / sandbox distribuce (nekompatibilní s AX + hidutil)
- Nativní macOS Spaces integrace, SIP/privátní API
- Vlastní TOML parser (TOMLKit), telemetrie, auto-update
- Scratchpady, window swallowing, blur/transparency efekty (případně později)

## Verification

1. `swift build && swift test` — WMCore/LayoutEngine/Config unit testy zelené
2. Manuální scénář (po M1): spustit app, povolit permissions, otevřít 4 okna (Terminal, Safari, Finder, TextEdit) → tilují se dwindle; hyper+hjkl focus, hyper+shift+hjkl swap, hyper+1/2 okamžité přepnutí workspace, self-resize okna snapne zpět
3. Multi-monitor (M2): odpojit/připojit externí monitor → workspaces migrují a vrátí se;
   `hyper+,` / `hyper+.` přepíná fokus mezi displayi; `hyper+6` z vestavěného skočí
   na workspace 6 na externím; v logu na startu jsou stabilní ID displayů pro
   `[workspaces]` v configu
4. Bar (M3): klik přepíná, drag ikony přesouvá okno, right-click menu funguje
5. Animace (M4): plynulé pro Terminal/Finder, auto-instant pro pomalou appku
6. Idle CPU < 1 % (Activity Monitor), žádný polling v Instruments time profile
