# Shotlist — screenshots and videos for the documentation

Goal: cover the website (website/src/content/docs) + README hero. Formats:
static screenshot = PNG (Retina, 2x), motion = short GIF/MP4 (5–15 s, no
sound). Before recording: clean desktop, uniform wallpaper, same set of apps
(terminal, browser, editor), hide personal data (emails, window titles).

## Hero / README

- [ ] **Hero screenshot** — full desktop, dwindle layout with 3–4 windows +
      bar. Most photogenic shot, goes in README and index.mdx.
- [ ] **Hero video (MP4, ~20 s)** — opening 3 windows (auto-tile), focus
      switching, moving a window, switching workspace. "What this is" in
      20 seconds.

## installation.md

- [ ] Screenshot: macOS Accessibility permission dialog (System Settings →
      Privacy & Security → Accessibility with ancre in the list).
- [ ] Screenshot: Input Monitoring permission, same place.
- [ ] Screenshot: first launch — state where the app waits for permission.

## controls.md

- [ ] GIF: focus movement (hyper+h/j/k/l) across 3 windows — focus
      highlighted.
- [ ] GIF: swap/move a window within the layout.
- [ ] GIF: switching workspace 1→2→1.
- [ ] GIF: moving a window to another workspace.
- [ ] GIF: toggle floating and back to tiled.
- [ ] GIF: fullscreen toggle.
- [ ] GIF: resizing windows (interactive resize / ratio change).
- [ ] GIF: drag & drop a window with the mouse to another position in the layout.

## layouts.md

- [ ] Screenshot: dwindle with 2, 3, 4 windows (series of 3 images — how it
      splits).
- [ ] GIF: opening windows one after another — dwindle splitting live.
- [ ] Screenshot/GIF: master-stack, if it exists; otherwise skip.

## bar.md

- [ ] Screenshot: bar in menu bar mode (close-up, cropped top strip).
- [ ] Screenshot: bar under the notch (on a MacBook display).
- [ ] GIF: clicking a workspace in the bar → switches.
- [ ] Screenshot: bar with active/inactive workspace — indicator states.

## multi-monitor.md

- [ ] Screenshot: two monitors, each with its own workspace + bar.
- [ ] GIF: moving a window between monitors.
- [ ] GIF: disconnecting/reconnecting a monitor — windows rearrange and come
      back (strongest demo — workspace placement is a pure function).

## configuration.md + config-reference.md

- [ ] Screenshot: `ancre.toml` in an editor with syntax highlighting
      (sample bindings + layout section).
- [ ] GIF: live reload — editing the config (e.g. a gap) → save → windows
      rearrange immediately.
- [ ] Screenshot: warning output for a config typo (validation never
      crashes — show the log/notification).

## scripting.md

- [ ] Screenshot/GIF: `ancrectl` in a terminal — `ancre_state` output, a
      command that moves a window and the visible effect next to it in
      the window.
- [ ] GIF: MCP/socket demo — a command from the CLI moves windows
      immediately.

## troubleshooting.md

- [ ] Screenshot: hidutil revert command + state (CapsLock→F18 remap).
- [ ] Screenshot: a window refusing a frame / snap-back situation, if it
      can be reproduced (otherwise skip).

## architecture.md

- no photos — generate diagrams (mermaid), don't record footage.

## Technical notes for recording

- Recording: QuickTime / `screencapture -v`, crop to 16:10, GIF via
  `ffmpeg` (palettegen) or Gifski — target < 5 MB per GIF.
- Screenshots: `screencapture -x` (no sound), disable the shadow
  (`defaults write com.apple.screencapture disable-shadow -bool true`).
- Cursor: visible only in GIFs where it clicks, otherwise hide it.
- Key highlighting: a KeyCastr-style overlay for GIFs involving hotkeys.
- Light vs. dark mode: record in dark (contrast with the bar), keep it
  consistent everywhere.
- Storage: `website/src/assets/` (Astro optimizes), naming
  `<page>-<action>.{png,gif,mp4}`.
- Placeholders with the final filenames are already commented out directly
  in the pages (EN and cs/) — `grep -rn "media (shotlist" website/src/content/docs`
  and the README/index.mdx hero block. Once recorded, just save the file
  under that name and uncomment the placeholder.
