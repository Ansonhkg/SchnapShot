# SchnapShot

A native macOS screenshot-to-image app. Select a screen area, let Codex generate a thumbnail, icon, or image using a saved prompt, then paste it. Built with SwiftUI, AppKit, and the installed Codex app-server; no API key or web server required.

[Website and 10-second demo](https://schnapshot.com) · [MIT license](LICENSE)

## What it does

- **⌥⌘4** selects an area using macOS capture by default. Customize it in **SchnapShot → Settings…**, **File → Capture shortcut…**, or the editor gear button. Apple’s ⌘⇧4 and ⌘⇧5 remain unchanged by default.
- Immediately opens the screenshot in a minimal dark editor and starts generation.
- Copies the generated PNG to the clipboard automatically; Copy and Save remain available.
- The top-right preset badge opens saved names, editable prompts, pixel dimensions, and aspect ratios. Save a preset or generate from the original screenshot separately.
- Closing the editor leaves the menu-bar app running. Quit explicitly to stop it.

## Setup

Requires macOS 14+, Swift 6 command-line tools, and an installed Codex CLI or Codex desktop app. The local integration was checked with Codex CLI 0.147.0.

```sh
git clone https://github.com/Ansonhkg/SchnapShot.git
cd SchnapShot
make run
```

Without an Apple Development certificate, use `make run SIGNING_IDENTITY=-` for a local ad-hoc build. macOS may require granting Screen Recording again after an ad-hoc rebuild. A packaged, notarized download is not available yet.

1. Click **Connect Codex** and finish the browser sign-in. Device-code login is also available.
2. Click **New capture**, then allow SchnapShot under **System Settings → Privacy & Security → Screen & System Audio Recording**. Quit and reopen when macOS asks. If a stale entry is enabled but capture still fails, remove that entry and add this current app bundle again.
3. Press **⌥⌘4**, drag a rectangle, and release. Escape cancels selection.
4. Wait for the result, then paste with **⌘V**. **⌘C** copies again and **⌘S** saves.

You can use **File → Open image…** to generate from an existing image without screen-capture permission.

The local app bundle is `dist/SchnapShot.app`. Builds use an installed Apple Development signing identity so the app has a stable identity across rebuilds. Override with `SIGNING_IDENTITY` if needed. This is not notarized or packaged for distribution. Keep it at a stable path for macOS permissions. `make run` does not replace an already running process; quit the app before rebuilding and reopening it.

The executable, source target, bundle identifier (`com.anson.SchnapShot`), and application-support folder now use SchnapShot. Upgrade code imports the old app's presets and shortcut once, moves its stored captures, and keeps a legacy home-path alias only to preserve Codex Keychain login. Historical logo concepts retain their original wordmarks. Renaming the bundle identity requires granting Screen Recording to the new app once.

## How it works

The app launches a private `codex app-server` process over standard input/output. Authentication and token refresh are managed by Codex, using a separate app-specific Codex home and the Mac Keychain. It does not import, modify, or log Ailised’s credentials or your global Codex credentials.

Each capture creates an ephemeral, read-only generation session with shell, browser, computer-use, plugins, apps, hooks, and subagents disabled. Screenshots are untrusted visual input, not instructions. Unknown tool or permission requests are rejected.

The generation instruction is:

```text
Create a thumbnail from this image.

Output size: 1200x630 pixels. Aspect ratio: 40:21.
```

The selected preset supplies the prompt above; icons and custom presets use their own instructions. The app receives an `imageGeneration` completion event, decodes the returned image, and writes an exact-size sRGB PNG. If the model returns a different aspect ratio, it fits the full composition within a dark matte rather than stretching or cropping it. Saving settings does not regenerate an existing image; generation is an explicit separate action.

## Privacy and storage

Selected screenshots are sent to OpenAI using your connected Codex account and count toward its usage limits. Generation is not free or offline.

- Credentials: Codex-managed Keychain entry scoped to this app’s home.
- App data: `~/Library/Application Support/SchnapShot/`.
- Originals and generated PNGs: `Captures/<capture-id>/`; retained locally until you remove them. **File → Show saved captures** opens that folder.
- Codex-generated source files and runtime metadata: the app’s `Codex/` subdirectory.
- Named presets and the selected preset: the app’s macOS preferences (`generationPresets.v1`). Previous size defaults migrate to the Thumbnail preset.

Cancel stops the app’s private Codex process. A request already submitted upstream may still consume usage. Existing local captures remain available. Signing out affects SchnapShot only and does not delete saved images.

## Configuration

Built-in generation presets are **Thumbnail · 1200 × 630** and **Icon · 1024 × 1024**. The preset badge opens a three-column card grid. **Click a card to activate it immediately**; the checkmark and blue border identify the active preset. Hover over a card to reveal **Edit** (also available in its context menu). To create another, click **+** or **New preset**, enter a unique name, prompt, width, and height, then **Save preset**. Cancel discards the draft. Selecting or saving never generates an image or consumes inference credits. With a screenshot loaded, the separate Generate button uses the selected settings on that original screenshot.

To change capture keys, open **Settings… → Record shortcut**, press a letter, number, or symbol with Command, Option, or Control, then **Save shortcut**. Escape cancels recording. **Restore default** selects ⌥⌘4; Save applies it. The shortcut persists across launches. Failed registration preserves the previous shortcut; macOS-reserved combinations may not be available. Capture is suppressed while the settings sheet is open.

The main editor shows the active prompt and ratio. Presets persist across launches. Custom sizes allow 64–4096 pixels per side, up to 8 MP and a maximum 3:1 aspect ratio. Icon output is a PNG, not an `.icns` bundle or a guaranteed transparent image.

`CMDSHIFT4_CODEX_BIN` can specify an absolute Codex executable path when launching the executable directly. Otherwise the app checks common CLI locations and the Codex desktop bundle. The account’s default Codex model is used; no account-wide model settings are changed.

## Development

```sh
make test                 # Deterministic sizing/protocol/error tests
make check                # Tests, release bundle, plist and signature validation
CMDSHIFT4_LIVE_CHECK=1 swift test  # Also test the installed app-server handshake
```

`Sources/ThumbnailCore` owns image validation, exact-size encoding, and JSON-RPC transport. `Sources/SchnapShot` owns native capture, account/generation state, the menu bar, and SwiftUI views. Tests use a local fake Codex process and never send screenshots or consume inference usage. The opt-in handshake test connects to the installed CLI without signing in or generating an image.

## References

- [Codex App Server](https://learn.chatgpt.com/docs/app-server)
- [Codex image generation](https://learn.chatgpt.com/docs/image-generation)

Ailised’s device-code sign-in implementation was inspected as a reference. SchnapShot uses Codex’s managed protocol instead of copying its OAuth token-exchange implementation. No Ailised files were changed.

## Website and promo source

- `landing/`: the React/Vinext landing page; see its [local setup](landing/README.md).
- `promo/filmflow/interactive-flow/`: the approved 1080p screenshot-animation renderer and reference assets.
- `promo/storyboards/`: the interaction script.

Production hosting identifiers, local credentials, generated job logs, and temporary renders are excluded from the public repository. The finished promo used by the website is included in `landing/public/`.

## License

SchnapShot code is available under the [MIT license](LICENSE). See [third-party asset notes](THIRD_PARTY_ASSETS.md) for demo screenshots, trademarks, and dependencies.
