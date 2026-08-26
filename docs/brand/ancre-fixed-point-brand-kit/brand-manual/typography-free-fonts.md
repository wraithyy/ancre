# typography guide: free fonts

## Recommended stack

Keep a simple stack for `ancre`:

```css
--font-ui: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Geist", "Inter", sans-serif;
--font-brand: "Geist", "Inter", "Helvetica Neue", Arial, sans-serif;
--font-mono: "JetBrains Mono", "SF Mono", Menlo, Consolas, monospace;
```

## Geist Sans

Role: documentation site, headings, navigation, marketing lines with a technical tone.

Why: clean, contemporary, less default than Inter, still very readable.

Usage:

- H1: 48-72 px, weight 500
- H2: 28-36 px, weight 520 or 600
- UI labels: 13-15 px, weight 500

Source: https://vercel.com/font

## Inter

Role: fallback and a safe choice for product UI.

Why: a robust free font at small sizes. Use it as a fallback, since it is very widespread today.

Usage:

- Body: 16-18 px, line-height 1.55
- Table/UI: 13-14 px, line-height 1.4

Source: https://rsms.me/inter/

## JetBrains Mono

Role: CLI, shortcuts, keybindings, config samples, `ancrectl`.

Why: very readable in code, technical character without a retro effect.

Usage:

- Inline code: 0.94em
- Blocks: 13-14 px, line-height 1.55
- Shortcut chips: 12-13 px, weight 500

Source: https://www.jetbrains.com/lp/mono/

## Native app

In the native macOS app do not override the system font. Use the system font for UI and let the brand exist through the logo asset, not through live-typeset text.

SwiftUI example:

```swift
Text("Workspace")
  .font(.system(size: 13, weight: .medium))

Text("ancrectl layout dwindle")
  .font(.system(.caption, design: .monospaced))
```

## Rules

- Letter spacing: `0`
- Body text: 16 px minimum on the web
- UI text: 13 px minimum in dense panels
- No all caps for long labels
- Code and keyboard shortcuts always monospace
- Never typeset the logo as plain text in markdown
