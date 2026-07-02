# One More Cap

One More Cap is a native macOS menu-bar app for playing an external subtitle file over a movie that does not include the subtitle track you need.

The MVP flow is:

1. Load an `.srt` or `.vtt` file from the menu bar app.
2. Play a movie in QuickTime Player.
3. Use the floating toolbar Sync control to calibrate subtitles to the current player position.
4. Adjust subtitle offset from the floating toolbar, or resize subtitle width by
   dragging the marked left or right edge of the subtitle container.

## Requirements

- macOS with Xcode or Xcode beta
- SwiftPM through Xcode
- No global dependency installation

The scripts use the active `xcode-select` toolchain by default. If
`$HOME/Applications/Xcode-beta.app/Contents/Developer` exists, the scripts use
it automatically. Set `DEVELOPER_DIR` to override that behavior.

## Commands

```sh
mise exec -- scripts/check.sh
mise exec -- scripts/run.sh
mise exec -- scripts/package-app.sh
SUBTITLES_DISTRIBUTION_CHANNEL=appstore mise exec -- scripts/package-app.sh
```

The default packaged app is the GitHub/full channel and is written to
`build/One More Cap.app`. Set `SUBTITLES_DISTRIBUTION_CHANNEL=appstore` to
package the App Store channel.

`scripts/check.sh` prepares Sparkle for the GitHub/full channel, then builds and
packages both channels. GitHub/full packaging also prepares Sparkle. The App
Store channel uses a Sparkle-free SwiftPM manifest and does not require
`Vendor/Sparkle`. If you run raw `swift build --product SubtitlesApp` or
`swift run` commands in a fresh checkout, run this first:

```sh
mise exec -- scripts/prepare-sparkle.sh
```

## Distribution Channels

The package has two app products:

- `SubtitlesApp`: GitHub/full channel. Includes QuickTime sync, Apple TV sync through Accessibility, and Sparkle updates.
- `SubtitlesAppStore`: App Store channel. Includes QuickTime read-only sync only and does not link Sparkle or the Apple TV Accessibility target.

`scripts/package-app.sh` maps channels to fixed products: `github` selects
`SubtitlesApp`, and `appstore` selects `SubtitlesAppStore`. The product is not
overridable by environment because that would weaken the App Store channel
boundary.

## Signing

`scripts/package-app.sh` defaults to ad-hoc signing, so a public checkout can
build a local `.app` bundle without a private Apple signing identity.

For personal signed builds, put local-only overrides in `.env.local`. That file
is ignored by git; `.env.local.example` documents the supported variables:

```sh
SUBTITLES_CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
SUBTITLES_BUNDLE_IDENTIFIER="com.example.one-more-cap"
```

The same values can also be supplied as environment variables for one-off
builds.

The App Store channel automatically uses `Subtitles.entitlements` when no custom
`SUBTITLES_CODESIGN_ENTITLEMENTS` value is set. That entitlement file enables
App Sandbox, user-selected subtitle file read access, and Apple Events access to
QuickTime Player.

## Updates

The GitHub/full channel uses [Sparkle](https://sparkle-project.org/) for manual
and automatic update checks. Sparkle is downloaded into the ignored
`Vendor/Sparkle/` directory by `scripts/prepare-sparkle.sh`; the binary
framework is not committed to git. The App Store channel does not link Sparkle
and does not show the update menu item.

Development builds without `SUBTITLES_SPARKLE_FEED_URL` and
`SUBTITLES_SPARKLE_PUBLIC_ED_KEY` still build and run, but the `Check for
Updates...` menu item reports that updates are not configured for that build.

Generate or inspect the Sparkle EdDSA key with:

```sh
mise exec -- scripts/generate-sparkle-keys.sh
mise exec -- scripts/generate-sparkle-keys.sh -p
mise exec -- scripts/generate-sparkle-keys.sh -x /tmp/subtitles-sparkle-private-key
```

For GitHub Release appcasts, set these repository secrets:

```sh
SUBTITLES_SPARKLE_PUBLIC_ED_KEY
SUBTITLES_SPARKLE_PRIVATE_KEY
```

`SUBTITLES_SPARKLE_PUBLIC_ED_KEY` is the public key printed by
`generate-sparkle-keys.sh -p`. `SUBTITLES_SPARKLE_PRIVATE_KEY` is the exact
contents of the private key file exported with `-x`; do not commit that file.

Release builds require both secrets. The release workflow embeds the public key
and a stable feed URL in the app, generates `appcast.xml`, and uploads it as a
release asset. The app feed URL is:

```text
https://github.com/deemoe404/onemoresub/releases/latest/download/appcast.xml
```

If the app is renamed later, keep `SUBTITLES_BUNDLE_IDENTIFIER`, the Sparkle
public/private key pair, and the feed URL stable. `SUBTITLES_APP_NAME`,
`SUBTITLES_APP_BUNDLE_NAME`, `SUBTITLES_APP_EXECUTABLE_NAME`, and
`SUBTITLES_STATUS_ITEM_TITLE` can change for display and packaging purposes.

## Release Automation

GitHub Actions runs `scripts/check.sh` on pushes and pull requests to `main`.
That check builds both `SubtitlesApp` and `SubtitlesAppStore`, then verifies that
the GitHub/full package includes Sparkle and the App Store package does not.

When a GitHub Release is published, the release workflow builds the tagged
checkout on a macOS runner, packages `build/One More Cap.app`, zips the app
bundle, generates the Sparkle appcast, and uploads both files back to the
Release assets. It also produces an App Store-channel workflow artifact without
Sparkle.
The release asset is ad-hoc signed by default; Developer ID signing,
notarization, and App Store upload signing are separate distribution steps.

Release tags must use `vX.Y.Z` or `X.Y.Z` format. That tag is written into the
app bundle short version, and the GitHub Actions run number is written into the
bundle build number. Release asset uploads fail if an asset with the same name
already exists.

## License

One More Cap is source-available under the [PolyForm Noncommercial License
1.0.0](LICENSE). Commercial use is not permitted without a separate license.
Packaged app bundles include a copy of the license in `Contents/Resources`.

## CLI Harness

```sh
mise exec -- swift run SubtitleHarness parse Fixtures/sample.srt
mise exec -- swift run SubtitleHarness at Fixtures/sample.srt 3.1 --offset 0.3
```

## App Behavior

- The menu bar item uses the One More Cap template icon.
- The floating subtitle window stays above normal windows and attempts to join fullscreen Spaces.
- Drag `.srt`, `.vtt`, or `.webvtt` files onto the subtitle window to replace the active subtitle.
- Hover over the subtitle window to reveal the Liquid Glass toolbar and the
  subtitle container chrome.
- Drag the marked left or right edge region of the subtitle container to adjust
  subtitle width. Height is calculated from the current subtitle text and system
  caption style.
- Hide or reopen the subtitle window from the menu bar.
- Use the hover Sync control to read the current player position. After calibration, subtitles continue from that player time using the local clock.
- App Store builds sync with QuickTime Player only. GitHub/full builds can sync with QuickTime Player or Apple TV.
- If the selected player is not running, has no open movie document, is missing permission, or returns no position data, Sync reports the calibration failure and leaves the current subtitle timing unchanged.

## Automation Permission

The app reads QuickTime Player's current movie time through QuickTime's scripting interface for Sync calibration. macOS may require Automation permission for that behavior. If the hover Sync control cannot read QuickTime Player, use `Permission > Automation...`, then allow One More Cap to read QuickTime Player in System Settings. The menu and hover controls remain usable without that permission.

GitHub/full builds also include an Apple TV sync target. That path reads TV.app
through Accessibility and is intentionally excluded from the App Store channel.

## Scope

The MVP supports SRT and WebVTT only. ASS/SSA styling, OCR, and notarized
Developer ID distribution are intentionally out of scope for this scaffold.

## Known Limitations

See [docs/known-limitations.md](docs/known-limitations.md) for interaction
limitations that are intentionally handled with product-level workarounds.
