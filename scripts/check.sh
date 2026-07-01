#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.sh
source "$ROOT_DIR/scripts/env.sh"
load_subtitles_env "$ROOT_DIR"
APP_NAME="${SUBTITLES_APP_NAME:-Subtitles}"
APP_EXECUTABLE_NAME="${SUBTITLES_APP_EXECUTABLE_NAME:-$APP_NAME}"

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/prepare-sparkle.sh" >/dev/null
xcrun swift test
xcrun swift build --product SubtitlesApp
xcrun swift run SubtitleHarness parse Fixtures/sample.srt >/tmp/subtitles-harness-srt.txt
xcrun swift run SubtitleHarness parse Fixtures/sample.vtt >/tmp/subtitles-harness-vtt.txt
xcrun swift run SubtitleHarness at Fixtures/sample.srt 3.1 --offset 0.3 >/tmp/subtitles-harness-at.txt

grep -q "format=srt" /tmp/subtitles-harness-srt.txt
grep -q "format=webVTT" /tmp/subtitles-harness-vtt.txt
grep -q "Second cue." /tmp/subtitles-harness-at.txt

APP_PATH="$(scripts/package-app.sh | tail -n 1)"
plutil -lint "$APP_PATH/Contents/Info.plist"
test -x "$APP_PATH/Contents/MacOS/$APP_EXECUTABLE_NAME"
test -d "$APP_PATH/Contents/Frameworks/Sparkle.framework"
test -f "$APP_PATH/Contents/Resources/ThirdPartyLicenses/Sparkle-LICENSE"

echo "Subtitles checks passed."
