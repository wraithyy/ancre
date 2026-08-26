---
title: Layouty
description: Dwindle, scroll, stack a vlastní layouty ze šablon.
sidebar:
  order: 4
---

ancre má tři vestavěné layouty a šablonový jazyk pro vlastní.

## Vestavěné

- **dwindle** — binární dělení jako v Hyprlandu; každé nové okno půlí
  největší slot. Default (`[general].default-layout`).
- **scroll** — sloupce vedle sebe („columns"), inspirováno scroll layoutem.
- **stack** — monocle: jedno okno přes celou plochu, ostatní za ním.

Přepínání: `hyper+t` (scroll), `hyper+shift+t` (dwindle), nebo obecně
`ancrectl layout <name>`. Per-workspace layout nastavíš
v `[workspace-labels]`.

## Vlastní layouty

Sekce `[custom-layouts]` — šablona popisuje strom splitů:

```toml
[custom-layouts]
"master" = "h(0.6, *, v(0.5, *, *))"
```

- `h(ratio, a, b)` — horizontální split (vedle sebe) s poměrem prvního slotu
- `v(ratio, a, b)` — vertikální split (nad sebou)
- `*` — slot pro okno

Okna plní sloty v pořadí; přebytečná okna se stackují do posledního slotu.
Název layoutu pak funguje všude, kde vestavěné: `layout master` jako command,
hodnota `layout` ve `[workspace-labels]`, keybinding.

## Auto-stack

Workspace zmigrovaná na monitor, kam se její okna nevejdou
(`počet × auto-stack-min-width > šířka monitoru`), se dočasně přepne do
stack layoutu a vrátí se zpět, jakmile je místo. Default zapnuto
(`[general].auto-stack`).
