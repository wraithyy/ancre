# Troubleshooting & uninstall

> Nicer rendering: https://wraithyy.github.io/ancre/troubleshooting/

No terminal needed for the first three — the menu bar icon and hyper keys
cover them:

- **Windows aren't tiling** → `hyper+r`, or menu bar icon → *Retile*.
  Typical after logging in with the screen locked.
- **A window "disappeared"** → it is parked or floating; the bar shows it
  (dashed ring = floating), right-click → Focus. Or `hyper+space` and type
  its name.
- **Everything should stop for a while** → `hyper+p` or menu bar icon →
  *Pause tiling* (the anchor diamond turns red while paused).
- **A window keeps popping back to the wrong size** → some windows enforce
  their own size; after 3 refused attempts ancre floats them automatically
  and retries on the next retile.
- **CapsLock stuck after a crash** → in Terminal (or send this line to
  whoever installed ancre for you):
  `hidutil property --set '{"UserKeyMapping":[]}'`
- **Nothing reacts to hyper at all** → check Input Monitoring permission;
  macOS silently kills event taps without it.
- **Digging deeper**: ancre logs to the system log; view live with
  `log stream --predicate 'process == "ancre"'`.

## Reset permissions

ancre is ad-hoc signed (`codesign --identifier com.ancre.wm`, see
`Scripts/bundle.sh`), and an ad-hoc signature's hash changes on every
rebuild. macOS ties Accessibility/Input Monitoring grants to that signature,
so after a rebuild the permission can show as "granted" in System Settings
while the running binary is silently rejected — because it no longer
matches the signature the grant was issued to.

If ancre stops reacting to hyper or stops tiling after you rebuild it, reset
both grants and re-approve:

```sh
tccutil reset Accessibility com.ancre.wm
tccutil reset ListenEvent com.ancre.wm
```

Then relaunch ancre and go through the permission prompts again.

## Reporting a bug

Check your version first: `mdls -name kMDItemVersion .build/ancre.app`
(source build) or `brew info --cask ancre` (Homebrew install).

Attach to the report:

- Recent logs: `log show --predicate 'process == "ancre"' --last 1h`
- Your `~/.config/ancre/ancre.toml`
- macOS version (`sw_vers`)
- Whether you installed via Homebrew or built from source

If ancre seems "stuck" and stops responding to hyper entirely, macOS may
have auto-disabled the CGEventTap after a timeout (it does this if the
callback doesn't return promptly). ancre's tap handler re-enables itself on
`.tapDisabledByTimeout`/`.tapDisabledByUserInput`
(`Sources/InputSystem/EventTapManager.swift`), logging the event — check
`log stream --predicate 'process == "ancre"'` for a re-enable message before
filing a bug.

## Uninstall

1. Quit ancre (menu bar icon → Quit) — the CapsLock remap reverts
   automatically. If it didn't (crash): `hidutil property --set
   '{"UserKeyMapping":[]}'`.
2. Homebrew: `brew uninstall --cask ancre` (add `--zap` to also delete
   config and data). Manual install: delete `ancre.app`, plus
   `~/.config/ancre/` and `~/Library/Application Support/ancre/` if you
   want a clean slate.
3. Remove the two permissions in System Settings → Privacy & Security if
   you like. Your windows stay where they were.
