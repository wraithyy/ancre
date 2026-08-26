# Dokumentační web

Astro Starlight ve `website/`, nasazuje se na GitHub Pages přes
`.github/workflows/deploy-docs.yml`.

## Lokální práce

```sh
cd website
npm install
npm run dev        # http://localhost:4321/ancre/
npm run build      # produkční build do dist/ (ověření před pushem)
```

## Struktura

| Cesta | Co |
|---|---|
| `website/astro.config.mjs` | site/base, logo, favicon, sidebar, locales |
| `website/src/content/docs/*.md(x)` | anglické stránky (root locale) |
| `website/src/content/docs/cs/*.md(x)` | české překlady — **stejné názvy souborů** jako v rootu, jinak se rozbije language switcher |
| `website/src/styles/brand.css` | barvy a fonty z brand kitu |
| `website/src/assets/` | logo lockupy (hlavička webu) |
| `website/public/` | favicon.svg/.ico, apple-touch-icon |

Brand assety a pravidla: `docs/brand/ancre-fixed-point-brand-kit/`
(brand manual = žádný marketingový hero, žádné kartičky v kartičkách;
barvy Ink/Blue/Cyan, fonty Geist Sans + JetBrains Mono).

## Přidání stránky

1. `website/src/content/docs/nova-stranka.md` (anglicky, frontmatter
   `title` + `description`).
2. Český překlad do `website/src/content/docs/cs/nova-stranka.md`.
3. Slug přidat do `sidebar` v `astro.config.mjs` (labely mají
   `translations.cs`).
4. Interní odkazy absolutně včetně base: EN `/ancre/slug/`,
   CS `/ancre/cs/slug/`.

## První nasazení

1. Vytvořit GitHub repo a pushnout (očekává se `wraithyy/ancre` — pokud je
   jméno jiné, upravit v `astro.config.mjs` klíče `site`, `base`, GitHub
   odkazy v `social`/`editLink` a interní odkazy `/ancre/...` ve stránkách).
2. Na GitHubu: Settings → Pages → Source = **GitHub Actions**.
3. Push na `main` — workflow se spustí při změně ve `website/**` a nasadí
   na `https://wraithyy.github.io/ancre/`. Ručně jde spustit přes
   workflow_dispatch.

## Obsah

Stránky čerpají z `README.md` a `Sources/Config/default.toml` — při změně
configu/klíčů aktualizovat `configuration.md` (+ `cs/configuration.md`),
při změně zkratek `controls.md`. Web je EN-first; čeština je plná kopie,
neudržovat ji napůl.
