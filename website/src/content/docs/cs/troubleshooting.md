---
title: Troubleshooting
description: Nejčastější problémy a jejich řešení.
sidebar:
  order: 9
---

## Okna se nepřeskládají

`hyper+r` (rescan + retile). Typicky po startu při zamčené obrazovce.

## Okno „zmizelo"

Je zaparkované nebo floatnuté. Bar ho ukáže (čárkovaný ring = float) —
pravý klik na ikonku → Fokusovat.

## CapsLock se chová divně po pádu

App přemapovává CapsLock→F18 přes hidutil; po pádu bez úklidu vrať remap:

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```

## Logy

App loguje přes NSLog:

```sh
log stream --predicate 'process == "ancre"'
```

## Chyba v configu

Config typo nikdy neshodí app — spadne se na defaulty a warning je v logu.
Po opravě: **Reload config** v menubar menu nebo `ancrectl reload-config`.
