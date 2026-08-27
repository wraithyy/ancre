# Shotlist — screenshoty a videa pro dokumentaci

Cíl: pokrýt web (website/src/content/docs) + README hero. Formáty:
statický screenshot = PNG (Retina, 2x), pohyblivé = krátké GIF/MP4 (5–15 s,
bez zvuku). Před natáčením: čistá plocha, jednotná wallpaper, stejná sada
appek (terminál, browser, editor), skrýt osobní data (maily, jména oken).

## Hero / README

- [ ] **Hero screenshot** — plný desktop, dwindle layout se 3–4 okny + bar.
      Nejfotogeničtější záběr, jde do README i index.mdx.
- [ ] **Hero video (MP4, ~20 s)** — otevření 3 oken (auto-tile), focus
      přepínání, přesun okna, přepnutí workspace. „Co to je" za 20 sekund.

## installation.md

- [ ] Screenshot: dialog macOS Accessibility permission (System Settings →
      Privacy & Security → Accessibility s ancre v seznamu).
- [ ] Screenshot: Input Monitoring permission tamtéž.
- [ ] Screenshot: první spuštění — stav, kdy app čeká na permission.

## controls.md

- [ ] GIF: focus movement (hyper+h/j/k/l) mezi 3 okny — zvýraznění fokusu.
- [ ] GIF: swap/move okna v rámci layoutu.
- [ ] GIF: přepnutí workspace 1→2→1.
- [ ] GIF: přesun okna na jiný workspace.
- [ ] GIF: toggle floating + zpět do tile.
- [ ] GIF: fullscreen toggle.
- [ ] GIF: resize oken (interactive resize / ratio změna).
- [ ] GIF: drag & drop okna myší do jiné pozice v layoutu.

## layouts.md

- [ ] Screenshot: dwindle se 2, 3, 4 okny (série 3 obrázků — jak se dělí).
- [ ] GIF: postupné otevírání oken — vidět dwindle splitting živě.
- [ ] Screenshot/GIF: master-stack, pokud existuje; jinak vynechat.

## bar.md

- [ ] Screenshot: bar v menu bar režimu (detail, crop horní lišty).
- [ ] Screenshot: bar pod notchem (na MacBook displeji).
- [ ] GIF: klik na workspace v baru → přepnutí.
- [ ] Screenshot: bar s aktivním/neaktivním workspace — stavy indikátorů.

## multi-monitor.md

- [ ] Screenshot: dva monitory, každý vlastní workspace + bar.
- [ ] GIF: přesun okna mezi monitory.
- [ ] GIF: odpojení/připojení monitoru — okna se přeskládají a vrátí
      (nejsilnější demo — workspace placement je čistá funkce).

## configuration.md + config-reference.md

- [ ] Screenshot: `ancre.toml` v editoru se syntax highlightem (ukázková
      sekce bindings + layout).
- [ ] GIF: live reload — úprava configu (např. gap) → uložení → okna se
      okamžitě přeskládají.
- [ ] Screenshot: warning výstup při typu v configu (validace nikdy
      necrashne — ukázat log/notifikaci).

## scripting.md

- [ ] Screenshot/GIF: `ancrectl` v terminálu — `ancre_state` výstup,
      příkaz na přesun okna a viditelný efekt vedle v okně.
- [ ] GIF: MCP/socket demo — příkaz z CLI okamžitě hýbe okny.

## troubleshooting.md

- [ ] Screenshot: hidutil revert příkaz + stav (CapsLock→F18 remap).
- [ ] Screenshot: okno odmítající frame / snap-back situace, pokud jde
      reprodukovat (jinak vynechat).

## architecture.md

- žádné foto — diagramy generovat (mermaid), ne točit.

## Technické poznámky k natáčení

- Nahrávat: QuickTime / `screencapture -v`, ořez na 16:10, GIF přes
  `ffmpeg` (palettegen) nebo Gifski — cíl < 5 MB na GIF.
- Screenshoty: `screencapture -x` (bez zvuku), stín vypnout
  (`defaults write com.apple.screencapture disable-shadow -bool true`).
- Kurzor: viditelný jen v GIFech kde kliká, jinak schovat.
- Zvýraznění kláves: overlay typu KeyCastr do GIFů s hotkeys.
- Světlý vs. tmavý režim: točit v tmavém (kontrast s barem), držet
  konzistentně všude.
- Uložení: `website/src/assets/` (Astro optimalizuje), pojmenování
  `<stránka>-<akce>.{png,gif,mp4}`.
- Placeholdery s finálními názvy souborů už jsou zakomentované přímo ve
  stránkách (EN i cs/) — `grep -rn "media (shotlist" website/src/content/docs`
  a v README/index.mdx hero blok. Po natočení stačí soubor uložit pod tím
  názvem a placeholder odkomentovat.
