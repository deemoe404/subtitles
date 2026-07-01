#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.sh
source "$ROOT_DIR/scripts/env.sh"
load_subtitles_env "$ROOT_DIR"

APP_DIR="$ROOT_DIR/build/Subtitles.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUNDLE_IDENTIFIER="${SUBTITLES_BUNDLE_IDENTIFIER:-local.Subtitles}"
BUNDLE_SHORT_VERSION="${SUBTITLES_BUNDLE_SHORT_VERSION:-0.1.0}"
BUNDLE_VERSION="${SUBTITLES_BUNDLE_VERSION:-1}"
MINIMUM_SYSTEM_VERSION="${SUBTITLES_MINIMUM_SYSTEM_VERSION:-26.0}"
CODESIGN_IDENTITY="${SUBTITLES_CODESIGN_IDENTITY:--}"

cd "$ROOT_DIR"
xcrun swift build -c release --product SubtitlesApp

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/SubtitlesApp" "$MACOS_DIR/Subtitles"
cp "$ROOT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE"

cat >"$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Subtitles</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Subtitles</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$BUNDLE_SHORT_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUNDLE_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MINIMUM_SYSTEM_VERSION</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign_args=(--force --sign "$CODESIGN_IDENTITY" --identifier "$BUNDLE_IDENTIFIER")
if [[ "${SUBTITLES_CODESIGN_HARDENED_RUNTIME:-0}" == "1" ]]; then
    codesign_args+=(--options runtime)
fi
if [[ -n "${SUBTITLES_CODESIGN_ENTITLEMENTS:-}" ]]; then
    codesign_args+=(--entitlements "$SUBTITLES_CODESIGN_ENTITLEMENTS")
fi

codesign "${codesign_args[@]}" "$APP_DIR"

echo "$APP_DIR"
