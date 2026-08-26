---
title: Installation
description: Building from source, permissions, and first launch of ancre.
sidebar:
  order: 1
---

:::caution
Launching remaps CapsLock→F18 (via `hidutil`) and starts rearranging windows,
regardless of how you installed ancre. If the app crashes without cleaning
up, revert the remap manually:

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```
:::

## Homebrew (recommended)

```sh
brew tap wraithyy/tap
brew trust wraithyy/tap          # third-party taps need a one-time trust
brew install --cask ancre        # installs ancre.app + puts ancrectl on PATH
open /Applications/ancre.app
```

The app is ad-hoc signed (no paid developer certificate); the cask clears
the quarantine flag for you, so Gatekeeper won't complain.

## From source

Plain Swift Package Manager, no `.xcodeproj`.

```sh
swift build -c release    # whole package
swift test                # unit tests
Scripts/bundle.sh         # builds .build/ancre.app (ad-hoc signed)
open .build/ancre.app
```

## Permissions

On first launch the app requests the **Accessibility** permission
(System Settings → Privacy & Security → Accessibility) and waits until it is
granted. The event tap for the hyper key additionally requires
**Input Monitoring**.

## First launch

- An onboarding window lists the permissions still missing, deep-links to
  the right System Settings pane, and starts the window manager only once
  everything is granted and you click Start. It's skipped entirely if
  permissions are already in place.
- The config `~/.config/ancre/ancre.toml` is created from defaults.
- Windows on visible workspaces get tiled; hidden workspaces are "parked"
  off-screen.
- A **◱** icon appears in the menu bar — pause tiling, retile, monitor list,
  open/reload config.

If a permission stops working after a rebuild (a new ad-hoc signature reads
as a different app to macOS), see
[Troubleshooting](/ancre/troubleshooting/#permissions-stopped-working-after-a-rebuild).
