## Summary

<!-- What does this PR change and why? -->

## Checklist

- [ ] Branched from `main`, diff stays focused
- [ ] `swift build && swift test` passes locally
- [ ] Describes manual verification for anything touching AX/Input/Bar
- [ ] `README.md` / `default.toml` updated if a feature or config key was added

## Manual verification (AX / Input / Bar)

<!-- Runtime AX/Input behavior can't run in CI (needs permissions + a
display session). Describe what you exercised by hand: which windows,
layouts, monitors, or keybindings. -->

## CI

CI runs `swift build` -> `swift test` -> `Scripts/bundle.sh` on
`macos-15` (`.github/workflows/ci.yml`). A green run does not replace the
manual verification above for AX/Input/Bar changes.
