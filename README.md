# Subtitles

Subtitles is a native macOS menu-bar app for playing an external subtitle file over a movie that does not include the subtitle track you need.

The MVP flow is:

1. Load an `.srt` or `.vtt` file from the menu bar app.
2. Play a movie in TV.app, or seek another video player to the beginning.
3. Let Apple TV sync follow TV.app automatically, or press Space when you start a non-TV player.
4. Adjust subtitle offset or size from the floating subtitle window.

## Requirements

- macOS with `$HOME/Applications/Xcode-beta.app`
- SwiftPM through Xcode beta 27
- No global dependency installation

The scripts set `DEVELOPER_DIR` explicitly, so they do not require changing global `xcode-select`.

## Commands

```sh
mise exec -- scripts/check.sh
mise exec -- scripts/run.sh
mise exec -- scripts/package-app.sh
```

The packaged app is written to `build/Subtitles.app`.

## CLI Harness

```sh
mise exec -- swift run SubtitleHarness parse Fixtures/sample.srt
mise exec -- swift run SubtitleHarness at Fixtures/sample.srt 3.1 --offset 0.3
```

## App Behavior

- The menu bar item is labeled `Sub`.
- The floating subtitle window stays above normal windows and attempts to join fullscreen Spaces.
- Drag `.srt`, `.vtt`, or `.webvtt` files onto the subtitle window to replace the active subtitle.
- Hover over the subtitle window to reveal controls for font size, window size, offset, playback, reset, and close.
- The close control hides the subtitle window; reopen it from the menu bar.
- `Sync with Apple TV` is enabled by default. When TV.app is running and returns a playback position, subtitles follow TV.app play/pause/seek state.
- If TV.app is stopped, not running, missing permissions, or missing position data, the app falls back to the manual Space-key clock.
- Use the hover control `Calibrate TV` to manually read the current Apple TV playback position when TV.app hides its playback controls. Automatic polling will not wake those controls.

## Hotkey Permission

The app installs a global Space-key monitor so subtitles can start when Apple TV starts. macOS may require Accessibility permission for global key monitoring. If Space does not control subtitles, use the menu item `Request Hotkey Permission`, then enable the app in System Settings. The menu and hover controls remain usable without that permission.

## TV Automation Permission

Apple TV sync uses Apple Events to read `player position` and `player state` from TV.app. Launch the bundled app with `mise exec -- scripts/run.sh`, then use `Request TV Automation Permission` if macOS has not prompted yet. If permission is denied, subtitles keep working in manual mode.

## Scope

The MVP supports SRT and WebVTT only. ASS/SSA styling, OCR, sandboxing, signing, and auto-update are intentionally out of scope for this scaffold.
