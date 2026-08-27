---
title: Layouty
description: Dwindle, scroll, stack a vlastní layouty ze šablon.
sidebar:
  order: 4
---

Layout rozhoduje, kam které okno patří — tiled okna nikdy nepozicuješ ručně.
ancre má tři vestavěné layouty a šablonový jazyk pro vlastní.

## Vestavěné

<!-- media (shotlist: layouts.md):
![Dwindle layout se 2 okny](../../../assets/layouts-dwindle-2.png)
![Dwindle layout se 3 okny](../../../assets/layouts-dwindle-3.png)
![Dwindle layout se 4 okny](../../../assets/layouts-dwindle-4.png)
![Postupné otevírání oken — dwindle dělení živě](../../../assets/layouts-dwindle-splitting.gif)
-->

- **dwindle** — každé nové okno rozpůlí to předchozí a spirálou míří do
  rohu (typický layout Hyprlandu); každé nové okno rozdělí
  slot, do kterého bylo vloženo. Osa splitu se řídí aktuálním poměrem stran
  toho slotu — širší se dělí vedle sebe, vyšší nad sebou — a nový split vždy
  začíná na poměru 0.5; posune ho jen ruční resize. Default
  (`[general].default-layout`).
- **scroll** — sloupce vedle sebe („columns”), inspirováno scroll layoutem.
- **stack** — jedno okno přes celou plochu, ostatní za ním (jinde se mu
  říká *monocle*).

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

## Float a fullscreen

`hyper+v` (`toggle-floating`) vyjme fokusované okno ze stromu tilingu, takže
si drží vlastní pozici a velikost; `hyper+f` (`toggle-fullscreen`) ho
roztáhne přes celou obrazovku. Obojí jsou obyčejné commandy, takže fungují
i z `ancrectl` a z pravého kliku v baru.

Okno může přejít do float i samo: pokud odmítá frame, který mu `ancre`
přiřadí (třeba kvůli pevné minimální velikosti), `ancre` to zkusí až
3×, pak to vzdá a okno přejde do float místo věčného boje — zbytek tilingu
se kolem něj přeuspořádá, jako by nikdy tiled nebylo.

Gaps a rámeček fokusu se konfigurují v `[general]` a `[border]` — viz
[Konfigurace](/ancre/cs/configuration/) a
[config reference](/ancre/cs/config-reference/).
