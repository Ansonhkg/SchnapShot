# Local verification — 2026-09-04

## Full rename and capture-permission repair

- Repository folder, Swift target/product, executable, bundle, bundle identifier, and visible labels renamed to SchnapShot.
- Replaced per-build ad-hoc signatures with the installed Apple Development identity. Verified the designated requirement references the app identifier and signing certificate rather than one executable hash.
- Screen-capture permission requests now respect an immediate successful grant instead of always returning an error.
- 23 tests executed: 22 passed and one opt-in live handshake skipped. Added fresh-install and idempotent legacy-storage migration tests.
- App process launches at the new bundle path. Native UI automation still resolves the old cached bundle identity, so capture on the newly signed build remains unverified pending the user's Screen Recording approval and relaunch.
- Legacy names remain only as upgrade inputs and a storage alias preserving Codex's credential home path. No TCC database or global privacy settings were modified.

## Passed

- Swift release build and local ad-hoc app signing.
- 15 tests, including an opt-in handshake against installed Codex CLI 0.147.0.
- Width/height validation, exact PNG dimensions for all four presets, corrupt-image rejection, generated-path containment, incremental Unicode JSON decoding.
- Local process-fixture tests: ordered generation events, server errors, timeouts and recovery, process-exit failure, cancellation and restart.
- Native welcome screen and editable size popover inspected via macOS accessibility and screenshots.
- Actual browser Codex sign-in completed; app shows a connected account. No API key used.
- Actual image generation from a mockup already created in this conversation.
- Result written as a readable PNG; `sips` confirmed exactly 1200 × 630 pixels.
- Automatic clipboard copy verified by pasting into a new TextEdit document: an attached image was present, not a filename or plain text.
- Native screen-selection picker opens; Escape restores the editor with “Capture cancelled.”
- A physical selection produced a 2446 × 1834 `screenshot.png`; the live app then produced a second `thumbnail-1200x630-*.png`. This verifies actual capture → generation → saved output, in addition to the earlier image-import and clipboard-paste test.

## Still needs a physical interaction check

- Global shortcut dispatch from other apps is registered successfully but was not independently confirmed by the automation tool. A physical selection and generation did complete while the user was interacting with the app.
- Retina/multiple-display selection is delegated to macOS `screencapture`, but not individually exercised on every display configuration.

No distribution signing/notarization, installer, auto-update, or cross-Mac test has been performed. This is a local app build.

## Preset cards and configurable shortcut update

- 21 tests executed: 20 passed, one opt-in live handshake skipped. Includes selection persistence without changing preset contents, invalid selection, shortcut serialization/validation, and corrupt preference recovery.
- Release app rebuilt and reopened; native screenshot confirms a three-column grid with Thumbnail, Icon, and a New preset card.
- Clicking Thumbnail updated the active preset, prompt, ratio, and status immediately; no Save or generation was needed. Icon restored afterward.
- New preset opens a separate editor. Missing name disables Save; Cancel returns to the unchanged card library.
- Settings gear opens capture shortcut controls. Recorded and successfully registered ⌃⌥8, verified it survived restart, then restored and saved ⌥⌘4.
- No image generation was triggered during these settings tests. Physical dispatch of the newly recorded global shortcut from another app remains a manual check.
