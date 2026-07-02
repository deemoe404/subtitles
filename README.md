# One More Cap

One More Cap is a native macOS menu-bar app for showing an external subtitle
file over a movie that does not include the subtitle track you need.

It is meant for the simple case: you have a video open, you have an `.srt` or
`.vtt` subtitle file, and you want one more caption layer on top.

## What It Does

- Loads SRT and WebVTT subtitle files.
- Shows subtitles in a floating overlay above the player.
- Syncs subtitle timing to QuickTime Player.
- Lets you adjust subtitle offset and subtitle width from the floating toolbar.
- Uses the macOS caption style settings where possible.
- The GitHub version can also sync with Apple TV through Accessibility.

## How To Use

1. Open One More Cap from the menu bar.
2. Load an `.srt`, `.vtt`, or `.webvtt` subtitle file.
3. Start the movie in QuickTime Player.
4. Hover over the subtitle overlay and press Sync.
5. Adjust the offset or subtitle width from the floating toolbar if needed.

You can also drag a subtitle file directly onto the subtitle window to replace
the active subtitle.

## Permissions And Privacy

One More Cap may ask macOS for permission to read the current playback time from
QuickTime Player. The GitHub version may also ask for Accessibility permission
when syncing with Apple TV.

Subtitle files stay on your Mac. One More Cap reads player timing for sync; it
does not upload your subtitles or movies.

## Supported Formats

One More Cap currently supports:

- `.srt`
- `.vtt`
- `.webvtt`

ASS/SSA styling and OCR are not part of the current scope.

## Downloads

The GitHub version is published through GitHub Releases:

[Download the latest release](https://github.com/deemoe404/onemorecap/releases/latest)

The GitHub version can check for updates and supports Apple TV sync. The App
Store version is separate and supports QuickTime sync only.

## Documentation

- [Development](docs/development.md)
- [Distribution](docs/distribution.md)
- [Permissions](docs/permissions.md)
- [Known Limitations](docs/known-limitations.md)

## Website

The App Store support and privacy pages live in `site/`. The site is a
self-contained Press static site deployed from this repository through GitHub
Pages.

## License

One More Cap is source-available under the [PolyForm Noncommercial License
1.0.0](LICENSE). Commercial use is not permitted without a separate license.
