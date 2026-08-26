# ancre fixed point brand kit

This kit uses the fixed-point logo: two window edges around a fixed center.

## What's inside

- `logo/` - vector logo, mark, lockups
- `macos/` - SVG app icon, Xcode `.appiconset`, `.icns`
- `menubar/` - template icon for the macOS menu bar
- `github/` - README header and social preview
- `web/` - favicons and a static documentation site
- `design-system/` - CSS/JSON tokens and component notes
- `brand-manual/` - brand manual and typography guide

## Recommended usage

- Menu bar: `menubar/AncreMenuTemplate.svg`, set `isTemplate = true` in AppKit
- App icon: `macos/ancre.appiconset`
- Web favicon: `web/favicon/favicon.svg`
- README header: `github/ancre-readme-header.svg`
- Design tokens: `design-system/tokens.css`

## Source logo

The core mark lives in `logo/mark/ancre-mark.svg` and uses `currentColor`.

## Naming

In prose, the project name is always lowercase `ancre`. PascalCase forms such as `AncreMenuTemplate.svg` are asset and file names only.
