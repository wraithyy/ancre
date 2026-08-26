---
title: Troubleshooting
description: Nejčastější problémy a jejich řešení.
sidebar:
  order: 9
---

## Okna se nepřeskládají

`hyper+r` (rescan + retile). Typicky po startu při zamčené obrazovce.

## Okno „zmizelo”

Je zaparkované nebo float. Bar ho ukáže (čárkovaný ring = float) —
pravý klik na ikonku → Fokusovat.

## CapsLock se chová divně po pádu

App přemapovává CapsLock→F18 přes hidutil; po pádu bez úklidu vrať remap:

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```

## Permissions přestanou fungovat po rebuildu

Každý build dostane ad-hoc podpis se stabilním identifikátorem
(`com.ancre.wm`), ale *samotný podpis* se s každým rebuildem mění — macOS
váže udělení Accessibility/Input Monitoring na tento podpis, takže
přebuildovaná binárka se v System Settings může tvářit jako „udělené”, i
když ve skutečnosti odepřené. Resetuj oboje a znovu uděl:

```sh
tccutil reset Accessibility com.ancre.wm
tccutil reset ListenEvent com.ancre.wm
```

Pak spusť znovu — onboarding okno tě provede opětovným udělením obou
permissions.

## Event tap přestane reagovat

macOS automaticky vypne `CGEventTap`, který se příliš dlouho vrací ze svého
callbacku (timeout, nebo někdy uživatelský vstup). ancre to detekuje
(`tapDisabledByTimeout` / `tapDisabledByUserInput`) a tap okamžitě znovu
zapne, do logu napíše `event tap disabled ..., re-enabling`. Pokud hyper
pořád nereaguje, zkontroluj logy (níže) — opakující se zprávy o re-enable
obvykle znamenají, že event loop drží něco jiného v systému.

## Nahlášení bugu

Přilož:

- verzi/commit ancre (`git -C /path/to/repo rev-parse --short HEAD` pro
  build ze zdrojů; verzi casku pro Homebrew)
- verzi macOS
- výstup `log stream --predicate 'process == "ancre"'` kolem problému
- svůj `~/.config/ancre/ancre.toml` (začerni citlivé údaje)
- jestli se problém reprodukuje po `hyper+r` (rescan + retile)

## Logy

App loguje přes NSLog:

```sh
log stream --predicate 'process == "ancre"'
```

## Chyba v configu

Config typo nikdy neshodí app — spadne se na defaulty a warning je v logu.
Po opravě: **Znovu načíst config** v menubar menu nebo
`ancrectl reload-config`.
