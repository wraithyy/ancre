---
title: Troubleshooting
description: The most common problems and their fixes.
sidebar:
  order: 9
---

## Windows don't rearrange

`hyper+r` (rescan + retile). Typically after startup while the screen was
locked.

## A window "disappeared"

It's parked or floating. The bar shows it (dashed ring = float) — right-click
the icon → Focus.

## CapsLock acts weird after a crash

The app remaps CapsLock→F18 via hidutil; after a crash without cleanup,
revert the remap:

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```

## Logs

The app logs via NSLog:

```sh
log stream --predicate 'process == "ancre"'
```

## Config error

A config typo never crashes the app — it falls back to defaults with a
warning in the log. After fixing: **Reload config** in the menu bar menu or
`ancrectl reload-config`.
