# Subtitles

Subtitles is a native macOS menu-bar app for playing an external subtitle file over a movie that does not include the subtitle track you need.

The MVP flow is:

1. Load an `.srt` or `.vtt` file from the menu bar app.
2. Play a movie in TV.app.
3. Use the floating toolbar Sync control to calibrate subtitles to the current TV.app playback position.
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
```

The packaged app is written to `build/Subtitles.app`.

## Signing

`scripts/package-app.sh` defaults to ad-hoc signing, so a public checkout can
build a local `.app` bundle without a private Apple signing identity.

For personal signed builds, put local-only overrides in `.env.local`. That file
is ignored by git; `.env.local.example` documents the supported variables:

```sh
SUBTITLES_CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
SUBTITLES_BUNDLE_IDENTIFIER="com.example.Subtitles"
```

The same values can also be supplied as environment variables for one-off
builds.

## Release Automation

GitHub Actions runs `scripts/check.sh` on pushes and pull requests to `main`.

When a GitHub Release is published, the release workflow builds the tagged
checkout on a macOS runner, packages `build/Subtitles.app`, zips the app bundle,
and uploads the zip back to the Release assets. The release asset is ad-hoc
signed by default; Developer ID signing and notarization are separate
distribution steps.

Release tags must use `vX.Y.Z` or `X.Y.Z` format. That tag is written into the
app bundle short version, and the GitHub Actions run number is written into the
bundle build number. Release asset uploads fail if an asset with the same name
already exists.

## License

Subtitles is source-available under the [PolyForm Noncommercial License
1.0.0](LICENSE). Commercial use is not permitted without a separate license.
Packaged app bundles include a copy of the license in `Contents/Resources`.

## CLI Harness

```sh
mise exec -- swift run SubtitleHarness parse Fixtures/sample.srt
mise exec -- swift run SubtitleHarness at Fixtures/sample.srt 3.1 --offset 0.3
```

## App Behavior

- The menu bar item is labeled `Sub`.
- The floating subtitle window stays above normal windows and attempts to join fullscreen Spaces.
- Drag `.srt`, `.vtt`, or `.webvtt` files onto the subtitle window to replace the active subtitle.
- Hover over the subtitle window to reveal the Liquid Glass toolbar and the
  subtitle container chrome.
- Drag the marked left or right edge region of the subtitle container to adjust
  subtitle width. Height is calculated from the current subtitle text and system
  caption style.
- Hide or reopen the subtitle window from the menu bar.
- Use the hover Sync control to read the current Apple TV playback position. The Sync button defaults to Apple TV and also exposes an Apple TV menu item. After calibration, subtitles continue from that TV time using the local clock.
- If TV.app is not running, missing Accessibility permission, or missing position data, Sync reports the calibration failure and leaves the current subtitle timing unchanged.

## Accessibility Permission

The app can read TV.app playback controls for Sync calibration. macOS may require Accessibility permission for that behavior. If the hover Sync control cannot read TV.app, use the menu item `Request Accessibility Access`, then enable the app in System Settings. If permission appears granted but behavior is still broken, use `Refresh Accessibility Access` to reopen the permission location and re-enable the app manually. The menu and hover controls remain usable without that permission.

## Scope

The MVP supports SRT and WebVTT only. ASS/SSA styling, OCR, sandboxing, signing, and auto-update are intentionally out of scope for this scaffold.

## Known Limitations

See [docs/known-limitations.md](docs/known-limitations.md) for interaction
limitations that are intentionally handled with product-level workarounds.
