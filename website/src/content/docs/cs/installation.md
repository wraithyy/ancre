---
title: Instalace
description: Sestavení ze zdrojů, permissions a první spuštění ancre.
sidebar:
  order: 1
---

:::caution
Spuštění přemapuje CapsLock→F18 (přes `hidutil`) a začne přeskládávat okna,
bez ohledu na to, jak byl ancre nainstalovaný. Pokud app spadne bez úklidu,
remap vrátíš ručně:

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```
:::

## Homebrew (doporučeno)

```sh
brew tap wraithyy/tap
brew trust wraithyy/tap          # tap třetí strany potřebuje jednorázový trust
brew install --cask ancre        # nainstaluje ancre.app a dá ancrectl na PATH
open /Applications/ancre.app
```

App je ad-hoc podepsaná (bez placeného developer certifikátu); cask za tebe
sundá quarantine flag, takže Gatekeeper si nebude stěžovat.

## Ze zdrojů (pro contributory)

Většina uživatelů má instalovat přes Homebrew výše. Build ze zdrojů je pro
vývoj — čistý Swift Package Manager, žádný `.xcodeproj`.

```sh
xcode-select --install    # jednorázově: compiler toolchain + git
git clone https://github.com/wraithyy/ancre && cd ancre
swift build -c release    # celý balíček
swift test                # unit testy
Scripts/bundle.sh         # sestaví .build/ancre.app (ad-hoc podpis)
open .build/ancre.app
```

## Permissions

<!-- media (shotlist: installation.md):
![System Settings: panel Accessibility s ancre v seznamu](../../../assets/installation-accessibility.png)
![System Settings: panel Input Monitoring s ancre v seznamu](../../../assets/installation-input-monitoring.png)
![První spuštění: onboarding okno čekající na permissions](../../../assets/installation-onboarding.png)
-->

Při prvním spuštění si app vyžádá **Accessibility** permission
(System Settings → Privacy & Security → Accessibility) a čeká, dokud ji
nedostane. Event tap pro hyper klávesu vyžaduje navíc **Input Monitoring**.

## První spuštění

- Onboarding okno vypíše chybějící permissions, odkazuje přímo do
  příslušného panelu System Settings a spustí window manager, až jsou
  všechny udělené a klikneš Start. Pokud jsou permissions už v pořádku,
  přeskočí se úplně.
- Config `~/.config/ancre/ancre.toml` se vytvoří z defaultů.
- Okna na viditelných workspaces se srovnají do dlaždic; skryté workspaces se
  „parkují” mimo obrazovku.
- V menubaru přibude ikona **◱** — pauza tilingu, přeskládání, seznam
  monitorů, otevření a znovunačtení configu.

Pokud po rebuildu přestane fungovat permission (nový ad-hoc podpis vypadá
pro macOS jako jiná app), viz
[Troubleshooting](/ancre/cs/troubleshooting/#permissions-přestanou-fungovat-po-rebuildu).
