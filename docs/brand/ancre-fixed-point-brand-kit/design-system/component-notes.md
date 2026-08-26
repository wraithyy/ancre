# ancre design system notes

## UI tone

The interface should feel like a macOS power tool. Dense, precise, scannable. No landing-page theatrics.

## Layout

- Sidebars: 240–280 px
- Main content: max 920 px for text documentation
- Tool panels: 320–420 px
- Grid previews: stable aspect-ratio so the layout doesn't shift on hover
- Border radius: 4–8 px for UI, 14 px only for large previews or the app icon

## Components

Buttons:

- Primary: frost text, blue border/fill only for the main action
- Secondary: transparent, rule border
- Icon buttons: 32×32 px, a symbol instead of text

Inputs:

- Height 32–36 px
- Background `Graphite`
- Focus ring `Blue` at 42% alpha

Cards:

- Use only for repeated items, modals, and actual tools
- Never nest a card inside a card

Code blocks:

- Background `#10151E`
- Left edge or top rule in `#30394A`
- Highlight key commands in `Cyan`

## Motion

Motion should be short and geometric:

- hover: 120–160 ms
- panel expand/collapse: 180–220 ms
- easing: `cubic-bezier(.2, .8, .2, 1)`

No floating decorations, no ambient glow animations.
