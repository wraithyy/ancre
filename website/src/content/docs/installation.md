---
title: Installation
description: Building from source, permissions, and first launch of ancre.
sidebar:
  order: 1
---

ancre builds from source — plain Swift Package Manager, no `.xcodeproj`.

```sh
swift build            # whole package
swift test             # unit tests
Scripts/bundle.sh      # builds .build/ancre.app (ad-hoc signed)
open .build/ancre.app
```

## Permissions

On first launch the app requests the **Accessibility** permission
(System Settings → Privacy & Security → Accessibility) and waits until it is
granted. The event tap for the hyper key additionally requires
**Input Monitoring**.

:::caution
Launching remaps CapsLock→F18 (via `hidutil`) and starts rearranging windows.
If the app crashes without cleaning up, revert the remap manually:

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```
:::

## First launch

- The config `~/.config/ancre/ancre.toml` is created from defaults.
- Windows on visible workspaces get tiled; hidden workspaces are "parked"
  off-screen.
- A **◱** icon appears in the menu bar — pause tiling, retile, monitor list,
  open/reload config.
