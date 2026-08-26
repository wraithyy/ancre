---
title: Ovládání
description: Klávesové zkratky, myší módy a workspace bar.
sidebar:
  order: 2
---

Hyper = CapsLock (změna klávesy: `[hyper].key` v configu). Podržení hyperu
déle než 2 s zobrazí **cheatsheet všech zkratek** jako průsvitný overlay.

## Klávesové zkratky

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
| `hyper+space` | přepínač oken (switcher) |
| `hyper+s` | scratchpad |
| `hyper+o` | hints (skok na okno) |
| `hyper+a` | adoptovat frontmost okno do aktuální workspace |
| `hyper+p` | pauza tilingu (toggle) |
| `hyper+r` | rescan + přeskládat vše |
| `hyper+,` / `hyper+.` | fokus předchozí/další monitor |

Všechny zkratky lze přemapovat v sekci `[keybindings]` — viz
[Konfigurace](/ancre/cs/configuration/).

## Myš

- **`hyper+levé táhnutí`** — přesun okna. Dlaždice se vytáhne z mřížky;
  puštění nad jinou dlaždicí ji vloží vedle (ukazuje placeholder budoucí
  pozice).
- **`hyper+pravé táhnutí`** — resize. U dlaždic živě přerovnává sousedy.

## Workspace bar

- klik na cell = přepnutí workspace
- klik na ikonku = fokus okna
- drag ikonky = přesun okna na jinou workspace
- pravý klik = context menu (float, fullscreen, přesun, layout)
- čárkovaný ring kolem ikonky = floating okno; badge = notifikace

## Menubar ◱

Pauza tilingu, přeskládání, seznam monitorů (klik zkopíruje stabilní ID pro
config), otevření a reload configu.
