---
title: Instalace
description: Sestavení ze zdrojů, permissions a první spuštění ancre.
sidebar:
  order: 1
---

ancre se sestavuje ze zdrojů — čistý Swift Package Manager, žádný `.xcodeproj`.

```sh
swift build            # celý balíček
swift test             # unit testy
Scripts/bundle.sh      # sestaví .build/ancre.app (ad-hoc podpis)
open .build/ancre.app
```

## Permissions

Při prvním spuštění si app vyžádá **Accessibility** permission
(System Settings → Privacy & Security → Accessibility) a čeká, dokud ji
nedostane. Event tap pro hyper klávesu vyžaduje navíc **Input Monitoring**.

:::caution
Spuštění přemapuje CapsLock→F18 (přes `hidutil`) a začne přeskládávat okna.
Pokud app spadne bez úklidu, remap vrátíš ručně:

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```
:::

## První spuštění

- Config `~/.config/ancre/ancre.toml` se vytvoří z defaultů.
- Okna na viditelných workspaces se srovnají do dlaždic; skryté workspaces se
  „parkují" mimo obrazovku.
- V menubaru přibude ikona **◱** — pauza tilingu, přeskládání, seznam
  monitorů, otevření/reload configu.
