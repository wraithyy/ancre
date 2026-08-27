---
title: Ovládání
description: Klávesové zkratky, myší módy a workspace bar.
sidebar:
  order: 2
---

Každá zkratka v ancre začíná jediným modifikátorem — **hyper klávesou**,
defaultně CapsLock (změna: `[hyper].key` v configu). Jedna klávesa, kterou
jinak nepoužíváš, takže žádná zkratka nekoliduje s aplikacemi. Podržení
hyperu déle než 2 s zobrazí **cheatsheet všech zkratek** jako průsvitný
overlay.

Použití CapsLock jako hyperu znamená, že ho ancre při spuštění přemapuje na
F18 přes `hidutil`, a globální event tap, který ho zachytává, vyžaduje
permission **Input Monitoring** — viz
[Instalace](/ancre/cs/installation/#permissions) a
[Troubleshooting](/ancre/cs/troubleshooting/), pokud přestane fungovat po
rebuildu.

:::caution
`right_cmd` a `right_option` jsou taky platné hodnoty `[hyper].key`, ale
kolidují se systémovými zkratkami: `right_cmd` se Spotlightem, `right_option`
s přepínáním jazyka vstupu. CapsLock se oběma vyhne.
:::

## Klávesové zkratky

<!-- media (shotlist: controls.md):
![Přesun fokusu mezi třemi okny přes hyper+h/j/k/l](../../../assets/controls-focus.gif)
![Prohození okna v rámci layoutu](../../../assets/controls-swap.gif)
![Přepnutí workspace 1 → 2 → 1](../../../assets/controls-workspace-switch.gif)
![Přesun okna na jiný workspace](../../../assets/controls-move-to-workspace.gif)
![Toggle okna mezi float a dlaždicí](../../../assets/controls-floating.gif)
![Fullscreen toggle](../../../assets/controls-fullscreen.gif)
![Resize — sousedi uhýbají](../../../assets/controls-resize.gif)
-->

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
| `hyper+space` | přepínač oken (fuzzy hledání přes všechna okna) |
| `hyper+s` | scratchpad (plovoucí terminál/appka přivolaná na požádání) |
| `hyper+o` | hints — každé okno dostane písmeno, stiskem na něj skočíš |
| `hyper+a` | adoptovat frontmost okno do aktuální workspace |
| `hyper+p` | pauza tilingu (toggle) |
| `hyper+r` | rescan + přeskládat vše |
| `hyper+,` / `hyper+.` | fokus předchozí/další monitor |

Všechny zkratky lze přemapovat v sekci `[keybindings]` — viz
[Konfigurace](/ancre/cs/configuration/).

## Myš

<!-- media (shotlist: controls.md):
![Přetažení okna myší na jinou pozici v layoutu](../../../assets/controls-dragdrop.gif)
-->

- **`hyper+levé táhnutí`** — přesun okna. Dlaždice se vytáhne z mřížky;
  puštění nad jinou dlaždicí ji vloží vedle (ukazuje placeholder budoucí
  pozice).
- **`hyper+pravé táhnutí`** — resize. U dlaždic živě přerovnává sousedy.

## Workspace bar

- klik na cell = přepnutí workspace
- klik na ikonku = fokus okna
- drag ikonky = přesun okna na jinou workspace
- pravý klik = context menu (float, fullscreen, přesun, layout)
- čárkovaný ring kolem ikonky = float okno; badge = notifikace

## Menubar ◱

Pauza tilingu, přeskládání, seznam monitorů (klik zkopíruje stabilní ID pro
config), otevření a znovunačtení configu.
