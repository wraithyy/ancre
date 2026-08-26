# ancre brand manual

## Foundation

ancre is a window manager for macOS power users. The brand should feel like a precise tool: quiet, sharp, native, without unnecessary flourish.

The core motif is the **fixed point**: two windows moving around a fixed center. The brand therefore never shows an anchor or a grid literally. It must work as a menu bar glyph, an app icon, and a mark in documentation.

## Logo

The primary logo is the horizontal lockup: mark + `ancre`.

- Primary light logo: `logo/lockups/ancre-horizontal-lockup.svg`
- Dark logo for light surfaces: `logo/lockups/ancre-horizontal-lockup-dark.svg`
- Standalone mark: `logo/mark/ancre-mark.svg`
- Small mark for 16 px: `logo/mark/ancre-mark-16.svg`

`ancre-mark.svg` uses `currentColor`, so it can safely be tinted via CSS or SwiftUI.

## Clear space

The clear space around the mark is at least the width of the center diamond. For the horizontal lockup keep at least the height of one `n` letter around the logo.

## Minimum sizes

- Menu bar: 18–22 px, use `menubar/AncreMenuTemplate.svg`
- Favicon: 16 px, use the optical variant or the prepared favicon exports
- GitHub badge: 64 px and up
- App icon: 128 px and up; below 64 px use the simpler mark, not the full app icon

## Colors

The base is dark, not blue, everywhere. Blue is action, cyan is navigation/focus, violet is depth or a secondary accent only, brass is a small counterpoint.

| Token | Hex | Use |
| --- | --- | --- |
| Ink | `#0B0D12` | main background |
| Graphite | `#151A23` | panels and menu bar preview |
| Panel | `#1C2230` | secondary surfaces |
| Rule | `#30394A` | lines, borders |
| Frost | `#EDF0F5` | primary text/logo |
| Muted | `#AEB6C4` | secondary text |
| Blue | `#4C8DFF` | action, selected workspace |
| Cyan | `#65D1FF` | focus, hover, docs link |
| Violet | `#8F6AF6` | depth, highlight |
| Brass | `#C8A96B` | rare accent, release note, warning badge |

## Typography

Native app:

- UI: the macOS system font via `-apple-system` / `SF Pro`
- Code and shortcuts: `SF Mono` or `JetBrains Mono`

Web and documentation:

- Recommended free display/UI font: **Geist Sans**
- Conservative fallback: **Inter**
- Code and CLI: **JetBrains Mono**

Use normal tracking `0`. Do not use a condensed display font for the logo. The wordmark should be calm and optically smaller than the mark itself.

## Icons

The menu bar icon must be a template: black, no background, no shadow. Set `isTemplate = true` in AppKit.

The app icon may have the macOS plate and subtle depth, but the mark must stay readable without effects. The app icon is a product icon, not a replacement for the logo in documentation.

## Web

The documentation site should be a working tool, not a landing page. The first screen should show:

- the name
- a short description
- install/quick start
- a sidebar with documentation
- a visible workspace/layout example

Do not use a big marketing hero, cards inside cards, or decorative orbs/glow objects.

## GitHub

The README header should show the brand and the project's purpose. In the repo use:

- `github/ancre-readme-header.svg`
- or `github/ancre-readme-header.png` when the GitHub preview needs a raster

## Don'ts

- do not go back to the anchor as an illustration
- do not put the logo in a blue gradient square everywhere
- do not add shadows to the menu bar icon
- do not stretch the wordmark
- do not use the mark as a pattern on every surface
