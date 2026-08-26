---
title: Multi-monitor
description: Stabilní přiřazení workspaces k monitorům, migrace a replug.
sidebar:
  order: 5
---

Workspaces 1–9 se rozprostírají napříč monitory se **stabilním přiřazením**,
které přežije odpojení a znovupřipojení displeje.

## Přiřazení workspace → monitor

```toml
[workspaces]
"1" = "Built-in"
"9" = "P34w-20"
```

Hodnota je buď **stabilní monitor ID** (`vendor:model:serial` — loguje se při
startu, zkopíruješ kliknutím v menubar menu ◱), nebo **část názvu displeje**.

## Chování

- Nevyjmenované workspaces se rozprostřou po zbylých displejích.
- Workspace, jejíž displej se odpojí, se přesune na připojený a **po replugu
  se vrátí** — placement je čistá funkce (názvy workspaces, config, připojené
  monitory), žádná imperativní migrace, takže replug vždy reprodukuje totéž.
- Monitor ID je odvozené z hardwaru, ne z `CGDirectDisplayID` (ten se mezi
  sessions mění).

## Fokus mezi monitory

`hyper+,` / `hyper+.` přepíná fokus na předchozí/další monitor. Bar má
per-monitor overrides (`[bar-overrides.*]`) — viz [Bar](/ancre/cs/bar/).
