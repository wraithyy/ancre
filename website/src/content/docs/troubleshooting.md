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

## Permissions stopped working after a rebuild

Every build gets an ad-hoc signature with a stable identifier
(`com.ancre.wm`), but the *signature itself* changes on each rebuild —
macOS ties Accessibility/Input Monitoring grants to that signature, so a
rebuilt binary can show as "granted" in System Settings while actually
being denied. Reset both and re-grant:

```sh
tccutil reset Accessibility com.ancre.wm
tccutil reset ListenEvent com.ancre.wm
```

Then relaunch — the onboarding window walks you through re-granting both.

## Event tap stopped responding

macOS auto-disables a `CGEventTap` that takes too long to return from its
callback (a timeout, or sometimes user input). ancre detects this
(`tapDisabledByTimeout` / `tapDisabledByUserInput`) and re-enables the tap
immediately, logging `event tap disabled ..., re-enabling`. If hyper still
doesn't respond after that, check the logs (below) for repeated
re-enable messages — that usually means something else on the system is
holding the event loop.

## Reporting a bug

Include:

- ancre version / commit (`git -C /path/to/repo rev-parse --short HEAD`
  for a source build; the cask version for Homebrew)
- macOS version
- Output of `log stream --predicate 'process == "ancre"'` around the issue
- Your `~/.config/ancre/ancre.toml` (redact anything sensitive)
- Whether it reproduces after `hyper+r` (rescan + retile)

## Logs

The app logs via NSLog:

```sh
log stream --predicate 'process == "ancre"'
```

## Config error

A config typo never crashes the app — it falls back to defaults with a
warning in the log. After fixing: **Reload config** in the menu bar menu or
`ancrectl reload-config`.
