# Security Policy

## Permissions ancre requests

- **Accessibility.** Required to read and move windows via the public
  `AXUIElement` API. This is the core mechanism the whole window manager is
  built on (see `CLAUDE.md`).
- **Input Monitoring.** Required for the `CGEventTap` that recognizes the
  hyper keybinding (`Sources/InputSystem/EventTapManager.swift`).

Be aware that on macOS, granting Input Monitoring gives the app OS-level
access to every keystroke system-wide -- the permission itself is not scoped
to a single key combination. ancre's own code only *acts* on that access
while the hyper key is held: `EventTapManager` gates key handling behind a
`hyperActive` flag (set on hyper key-down, cleared on key-up), and keys seen
outside that window are passed through unmodified. ancre does not log,
store, or transmit any keystroke, hyper-gated or not.

## Network

ancre makes no network requests. There is no `URLSession`, HTTP client, or
outbound network socket anywhere in `Sources/` or `App/`, and no telemetry
or analytics of any kind.

The only IPC surface is a local Unix domain socket
(`App/ControlServer.swift`), used by `ancrectl` and the MCP server to talk
to a running ancre instance. It is created with `0600` permissions in a
per-UID path; filesystem permissions are the auth boundary. Any process
already running as the same user could drive the Accessibility API directly
regardless, so the socket adds no additional privilege.

## hidutil remap

Launching ancre remaps CapsLock to F18 via `hidutil` so it can be used as
part of the hyper keybinding. This is a system-level change that persists
after ancre quits (`hidutil` remaps live until reboot or another `hidutil`
call). If you're not running ancre and CapsLock is still remapped, revert
with:

```sh
hidutil property --set '{"UserKeyMapping":[]}'
```

## Code signing

ancre is ad-hoc signed, not notarized -- there's no Apple Developer
certificate behind it. This means Gatekeeper's malware scan (which runs as
part of notarization) never sees the binary. The Homebrew cask clears the
quarantine flag for you as part of installation, which is the intended way
to get past Gatekeeper's warning.

If you build from source, do not reflexively run
`xattr -d com.apple.quarantine` on binaries you haven't verified yourself --
that flag is what triggers Gatekeeper's check in the first place. Only clear
it on a build you produced yourself from source you've read, or a release
asset whose checksum you've verified against the GitHub Release.

## Reporting a vulnerability

Please report security issues via
[GitHub Security Advisories](../../security/advisories/new) for this
repository rather than a public issue. This lets us assess and fix the
issue before it's publicly disclosed.
