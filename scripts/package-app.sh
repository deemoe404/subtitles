#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.sh
source "$ROOT_DIR/scripts/env.sh"
load_subtitles_env "$ROOT_DIR"

APP_NAME="${SUBTITLES_APP_NAME:-Subtitles}"
APP_BUNDLE_NAME="${SUBTITLES_APP_BUNDLE_NAME:-$APP_NAME}"
APP_EXECUTABLE_NAME="${SUBTITLES_APP_EXECUTABLE_NAME:-$APP_NAME}"
APP_DIR="$ROOT_DIR/build/$APP_BUNDLE_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
THIRD_PARTY_LICENSES_DIR="$RESOURCES_DIR/ThirdPartyLicenses"
BUNDLE_IDENTIFIER="${SUBTITLES_BUNDLE_IDENTIFIER:-local.Subtitles}"
BUNDLE_SHORT_VERSION="${SUBTITLES_BUNDLE_SHORT_VERSION:-0.1.0}"
BUNDLE_VERSION="${SUBTITLES_BUNDLE_VERSION:-1}"
MINIMUM_SYSTEM_VERSION="${SUBTITLES_MINIMUM_SYSTEM_VERSION:-26.0}"
CODESIGN_IDENTITY="${SUBTITLES_CODESIGN_IDENTITY:--}"
STATUS_ITEM_TITLE="${SUBTITLES_STATUS_ITEM_TITLE:-Sub}"
SPARKLE_FEED_URL="${SUBTITLES_SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SUBTITLES_SPARKLE_PUBLIC_ED_KEY:-}"
SPARKLE_FRAMEWORK_SOURCE="$ROOT_DIR/Vendor/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
SPARKLE_LICENSE_SOURCE="$ROOT_DIR/Vendor/Sparkle/LICENSE"

if [[ -n "$SPARKLE_FEED_URL" && -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    echo "SUBTITLES_SPARKLE_PUBLIC_ED_KEY is required when SUBTITLES_SPARKLE_FEED_URL is set" >&2
    exit 1
fi

if [[ -z "$SPARKLE_FEED_URL" && -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    echo "SUBTITLES_SPARKLE_FEED_URL is required when SUBTITLES_SPARKLE_PUBLIC_ED_KEY is set" >&2
    exit 1
fi

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/prepare-sparkle.sh" >/dev/null
xcrun swift build -c release --product SubtitlesApp

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$THIRD_PARTY_LICENSES_DIR"
cp "$ROOT_DIR/.build/release/SubtitlesApp" "$MACOS_DIR/$APP_EXECUTABLE_NAME"
cp "$ROOT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE"
/usr/bin/ditto "$SPARKLE_FRAMEWORK_SOURCE" "$FRAMEWORKS_DIR/Sparkle.framework"
cp "$SPARKLE_LICENSE_SOURCE" "$THIRD_PARTY_LICENSES_DIR/Sparkle-LICENSE"

cat >"$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST

plutil -replace CFBundleDevelopmentRegion -string en "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleExecutable -string "$APP_EXECUTABLE_NAME" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleIdentifier -string "$BUNDLE_IDENTIFIER" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleInfoDictionaryVersion -string "6.0" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleName -string "$APP_NAME" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleDisplayName -string "$APP_NAME" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundlePackageType -string APPL "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleShortVersionString -string "$BUNDLE_SHORT_VERSION" "$CONTENTS_DIR/Info.plist"
plutil -replace CFBundleVersion -string "$BUNDLE_VERSION" "$CONTENTS_DIR/Info.plist"
plutil -replace LSMinimumSystemVersion -string "$MINIMUM_SYSTEM_VERSION" "$CONTENTS_DIR/Info.plist"
plutil -replace LSUIElement -bool YES "$CONTENTS_DIR/Info.plist"
plutil -replace NSHighResolutionCapable -bool YES "$CONTENTS_DIR/Info.plist"
plutil -replace SUBStatusItemTitle -string "$STATUS_ITEM_TITLE" "$CONTENTS_DIR/Info.plist"

if [[ -n "$SPARKLE_FEED_URL" ]]; then
    plutil -replace SUFeedURL -string "$SPARKLE_FEED_URL" "$CONTENTS_DIR/Info.plist"
    plutil -replace SUPublicEDKey -string "$SPARKLE_PUBLIC_ED_KEY" "$CONTENTS_DIR/Info.plist"
fi

codesign_nested_args=(--force --sign "$CODESIGN_IDENTITY")
codesign_app_args=(--force --sign "$CODESIGN_IDENTITY" --identifier "$BUNDLE_IDENTIFIER")
if [[ "${SUBTITLES_CODESIGN_HARDENED_RUNTIME:-0}" == "1" ]]; then
    codesign_nested_args+=(--options runtime)
    codesign_app_args+=(--options runtime)
fi
if [[ -n "${SUBTITLES_CODESIGN_ENTITLEMENTS:-}" ]]; then
    codesign_app_args+=(--entitlements "$SUBTITLES_CODESIGN_ENTITLEMENTS")
fi

for nested_code in \
    "$FRAMEWORKS_DIR/Sparkle.framework/XPCServices/"*.xpc \
    "$FRAMEWORKS_DIR/Sparkle.framework/Updater.app" \
    "$FRAMEWORKS_DIR/Sparkle.framework/Autoupdate"; do
    codesign "${codesign_nested_args[@]}" "$nested_code"
done
codesign "${codesign_nested_args[@]}" "$FRAMEWORKS_DIR/Sparkle.framework"
codesign "${codesign_app_args[@]}" "$APP_DIR"

echo "$APP_DIR"
