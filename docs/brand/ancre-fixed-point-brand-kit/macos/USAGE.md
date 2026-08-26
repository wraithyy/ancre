# macOS usage

## App icon

Use `macos/ancre.appiconset` in Xcode as the AppIcon asset.

Included:

- `ancre-app-icon.svg` - vector source
- `ancre-app-icon.pdf` - vector PDF source
- `ancre.appiconset/` - Xcode-ready PNG set
- `ancre.icns` - standalone macOS icon container

## Menu bar

Use `menubar/AncreMenuTemplate.svg` or `menubar/AncreMenuTemplate.pdf` as a template image.

AppKit:

```swift
let image = NSImage(named: "AncreMenuTemplate")
image?.isTemplate = true
statusItem.button?.image = image
```

SwiftUI:

```swift
Image("AncreMenuTemplate")
  .renderingMode(.template)
```

The menu bar icon must stay flat black in the asset file. macOS handles light/dark rendering when it is marked as a template image.
