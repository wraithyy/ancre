---
title: Multi-monitor
description: Stabilní přiřazení workspaces k monitorům, migrace a replug.
sidebar:
  order: 5
---

Workspaces 1–9 se rozprostírají napříč monitory se **stabilním přiřazením**,
které přežije odpojení a znovupřipojení monitoru: odpojíš v kanceláři,
připojíš doma, a každá workspace skončí zpátky na monitoru, kam patří.

<!-- media (shotlist: multi-monitor.md):
![Dva monitory, každý s vlastní workspace a barem](../../../assets/multi-monitor-two-displays.png)
![Přesun okna mezi monitory](../../../assets/multi-monitor-move-window.gif)
![Odpojení a připojení monitoru — okna se přeskládají a vrátí](../../../assets/multi-monitor-replug.gif)
-->


## Přiřazení workspace → monitor

```toml
[workspaces]
"1" = "Built-in"
"9" = "P34w-20"
```

Hodnota je buď **stabilní monitor ID** (`vendor:model:serial` — loguje se při
startu, zkopíruješ kliknutím v menubar menu ◱), nebo **část názvu monitoru**.

Může to být i pole — priority list, kde vyhrává první připojený monitor,
takže stejný config funguje doma i v kanceláři:

```toml
[workspaces]
"1" = ["PHL", "P34w"]   # preferuj PHL, fallback P34w
```

:::caution
Levné panely často hlásí serial `0`. Dva identické panely se stejným
matcherem se pak srazí — `ancre` je rozliší přidáním pozičního suffixu
(`#1`, `#2`, ...) k druhému z nich. Přeuspořádání monitorů prohodí, který
panel dostane který suffix, což prohodí i jejich workspaces.
:::

## Chování

- Nevyjmenované workspaces se rozprostřou po zbylých monitorech.
- Workspace, jejíž monitor se odpojí, se přesune na připojený a **po replugu
  se vrátí** — placement je čistá funkce (názvy workspaces, config, připojené
  monitory), žádná imperativní migrace, takže replug vždy reprodukuje totéž.
- Monitor ID je odvozené z hardwaru, ne z `CGDirectDisplayID` (ten se mezi
  sessions mění).
- Spánek nebo zavřené víko může hlásit nula připojených monitorů; v tu chvíli
  `ancre` nechá aktuální uspořádání beze změny místo přeřazování workspaces,
  takže po probuzení je vše tam, kde bylo.
- Fokus následuje workspace podle jména: přesun fokusu na monitor fokusuje
  ten workspace, který je na něm právě aktivní, ne pevné číslo workspace.

## Fokus mezi monitory

`hyper+,` / `hyper+.` přepíná fokus na předchozí/další monitor. Bar má
per-monitor overrides (`[bar-overrides.*]`) — viz [Bar](/ancre/cs/bar/).
