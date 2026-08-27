# Documentation website

Astro Starlight in `website/`, deployed to GitHub Pages via
`.github/workflows/deploy-docs.yml`.

## Local work

```sh
cd website
npm install
npm run dev        # http://localhost:4321/ancre/
npm run build      # production build into dist/ (verify before pushing)
```

## Structure

| Path | What |
|---|---|
| `website/astro.config.mjs` | site/base, logo, favicon, sidebar, locales |
| `website/src/content/docs/*.md(x)` | English pages (root locale) |
| `website/src/content/docs/cs/*.md(x)` | Czech translations — **same filenames** as the root, otherwise the language switcher breaks |
| `website/src/styles/brand.css` | colors and fonts from the brand kit |
| `website/src/assets/` | logo lockups (site header) |
| `website/public/` | favicon.svg/.ico, apple-touch-icon |

Brand assets and rules: `docs/brand/ancre-fixed-point-brand-kit/`
(brand manual = no marketing hero, no cards-within-cards; Ink/Blue/Cyan
colors, Geist Sans + JetBrains Mono fonts).

## Adding a page

1. `website/src/content/docs/new-page.md` (English, frontmatter `title` +
   `description`).
2. Czech translation at `website/src/content/docs/cs/new-page.md`.
3. Add the slug to `sidebar` in `astro.config.mjs` (labels have
   `translations.cs`).
4. Internal links absolute including base: EN `/ancre/slug/`,
   CS `/ancre/cs/slug/`.

## First deployment

1. Create the GitHub repo and push (expects `wraithyy/ancre` — if the name
   differs, update `astro.config.mjs`'s `site`/`base` keys, the GitHub links
   in `social`/`editLink`, and the internal `/ancre/...` links in the pages).
2. On GitHub: Settings → Pages → Source = **GitHub Actions**.
3. Push to `main` — the workflow triggers on changes under `website/**` and
   deploys to `https://wraithyy.github.io/ancre/`. Can also be run manually
   via workflow_dispatch.

## Content

Pages draw from `README.md` and `Sources/Config/default.toml` — when the
config/keys change, update `configuration.md` (+ `cs/configuration.md`), when
shortcuts change, update `controls.md`. The site is EN-first; the Czech
version is a full copy — don't leave it half-maintained.
