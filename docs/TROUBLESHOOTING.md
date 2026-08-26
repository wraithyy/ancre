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
