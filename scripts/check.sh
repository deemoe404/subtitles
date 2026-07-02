#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.sh
source "$ROOT_DIR/scripts/env.sh"
load_onemorecap_env "$ROOT_DIR"
APP_NAME="${ONEMORECAP_APP_NAME:-One More Cap}"
APP_BUNDLE_NAME="${ONEMORECAP_APP_BUNDLE_NAME:-One More Cap}"
APP_EXECUTABLE_NAME="${ONEMORECAP_APP_EXECUTABLE_NAME:-One More Cap}"

assert_appstore_build_without_sparkle_vendor() {
    local sparkle_dir="$ROOT_DIR/Vendor/Sparkle"
    local backup_dir="$ROOT_DIR/Vendor/Sparkle.check-backup"
    local status=0

    restore_sparkle_vendor() {
        if [[ -d "$backup_dir" ]]; then
            rm -rf "$sparkle_dir"
            mv "$backup_dir" "$sparkle_dir"
        fi
    }

    trap restore_sparkle_vendor RETURN EXIT

    rm -rf "$backup_dir"
    if [[ -d "$sparkle_dir" ]]; then
        mv "$sparkle_dir" "$backup_dir"
    fi

    ONEMORECAP_DISTRIBUTION_CHANNEL=appstore xcrun swift build --product OneMoreCapAppStore || status=$?

    restore_sparkle_vendor
    trap - RETURN EXIT

    return "$status"
}

assert_appstore_entitlements() {
    local app_path="$1"
    local entitlements_file
    local sandbox
    local automation
    local user_selected_read_only
    local quicktime_exception
    local quicktime_exception_extra

    entitlements_file="$(mktemp)"
    codesign -d --entitlements - --xml "$app_path" >"$entitlements_file" 2>/dev/null

    sandbox="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$entitlements_file" 2>/dev/null || true)"
    automation="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.automation.apple-events' "$entitlements_file" 2>/dev/null || true)"
    user_selected_read_only="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.files.user-selected.read-only' "$entitlements_file" 2>/dev/null || true)"
    quicktime_exception="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.temporary-exception.apple-events:0' "$entitlements_file" 2>/dev/null || true)"
    quicktime_exception_extra="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.temporary-exception.apple-events:1' "$entitlements_file" 2>/dev/null || true)"

    rm -f "$entitlements_file"

    test "$sandbox" = "true"
    test "$automation" = "true"
    test "$user_selected_read_only" = "true"
    test "$quicktime_exception" = "com.apple.QuickTimePlayerX"
    test -z "$quicktime_exception_extra"
}

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/prepare-sparkle.sh" >/dev/null
xcrun swift test
xcrun swift build --product OneMoreCapApp
ONEMORECAP_DISTRIBUTION_CHANNEL=appstore xcrun swift build --product OneMoreCapAppStore
assert_appstore_build_without_sparkle_vendor
xcrun swift run SubtitleHarness parse Fixtures/sample.srt >/tmp/onemorecap-harness-srt.txt
xcrun swift run SubtitleHarness parse Fixtures/sample.vtt >/tmp/onemorecap-harness-vtt.txt
xcrun swift run SubtitleHarness at Fixtures/sample.srt 3.1 --offset 0.3 >/tmp/onemorecap-harness-at.txt

grep -q "format=srt" /tmp/onemorecap-harness-srt.txt
grep -q "format=webVTT" /tmp/onemorecap-harness-vtt.txt
grep -q "Second cue." /tmp/onemorecap-harness-at.txt

/usr/bin/python3 scripts/assert-png-template-alpha.py \
    Resources/MenuBarIcon.png \
    Resources/MenuBarIcon@2x.png

GITHUB_APP_PATH="$(
    ONEMORECAP_DISTRIBUTION_CHANNEL=github \
    ONEMORECAP_APP_BUNDLE_NAME="One More Cap-GitHub" \
    scripts/package-app.sh | tail -n 1
)"
plutil -lint "$GITHUB_APP_PATH/Contents/Info.plist"
test -x "$GITHUB_APP_PATH/Contents/MacOS/$APP_EXECUTABLE_NAME"
test -f "$GITHUB_APP_PATH/Contents/Resources/Assets.car"
test -f "$GITHUB_APP_PATH/Contents/Resources/AppIcon.icns"
test -f "$GITHUB_APP_PATH/Contents/Resources/MenuBarIcon.png"
test -f "$GITHUB_APP_PATH/Contents/Resources/MenuBarIcon@2x.png"
/usr/bin/python3 scripts/assert-png-template-alpha.py \
    "$GITHUB_APP_PATH/Contents/Resources/MenuBarIcon.png" \
    "$GITHUB_APP_PATH/Contents/Resources/MenuBarIcon@2x.png"
test "$(plutil -extract CFBundleDisplayName raw -o - "$GITHUB_APP_PATH/Contents/Info.plist")" = "$APP_NAME"
test "$(plutil -extract CFBundleExecutable raw -o - "$GITHUB_APP_PATH/Contents/Info.plist")" = "$APP_EXECUTABLE_NAME"
test "$(plutil -extract CFBundleIconName raw -o - "$GITHUB_APP_PATH/Contents/Info.plist")" = "AppIcon"
test "$(plutil -extract SUBDistributionChannel raw -o - "$GITHUB_APP_PATH/Contents/Info.plist")" = "github"
test -d "$GITHUB_APP_PATH/Contents/Frameworks/Sparkle.framework"
test -f "$GITHUB_APP_PATH/Contents/Resources/ThirdPartyLicenses/Sparkle-LICENSE"
otool -L "$GITHUB_APP_PATH/Contents/MacOS/$APP_EXECUTABLE_NAME" >/tmp/onemorecap-github-otool.txt
grep -q "Sparkle.framework" /tmp/onemorecap-github-otool.txt
grep -q "ApplicationServices.framework" /tmp/onemorecap-github-otool.txt

APPSTORE_APP_PATH="$(
    env -u ONEMORECAP_SPARKLE_FEED_URL -u ONEMORECAP_SPARKLE_PUBLIC_ED_KEY \
    ONEMORECAP_DISTRIBUTION_CHANNEL=appstore \
    ONEMORECAP_APP_BUNDLE_NAME="One More Cap-AppStore" \
    ONEMORECAP_BUNDLE_IDENTIFIER=local.OneMoreCap.AppStore \
    scripts/package-app.sh | tail -n 1
)"
plutil -lint "$APPSTORE_APP_PATH/Contents/Info.plist"
test -x "$APPSTORE_APP_PATH/Contents/MacOS/$APP_EXECUTABLE_NAME"
test -f "$APPSTORE_APP_PATH/Contents/Resources/Assets.car"
test -f "$APPSTORE_APP_PATH/Contents/Resources/AppIcon.icns"
test -f "$APPSTORE_APP_PATH/Contents/Resources/MenuBarIcon.png"
test -f "$APPSTORE_APP_PATH/Contents/Resources/MenuBarIcon@2x.png"
/usr/bin/python3 scripts/assert-png-template-alpha.py \
    "$APPSTORE_APP_PATH/Contents/Resources/MenuBarIcon.png" \
    "$APPSTORE_APP_PATH/Contents/Resources/MenuBarIcon@2x.png"
test "$(plutil -extract CFBundleDisplayName raw -o - "$APPSTORE_APP_PATH/Contents/Info.plist")" = "$APP_NAME"
test "$(plutil -extract CFBundleExecutable raw -o - "$APPSTORE_APP_PATH/Contents/Info.plist")" = "$APP_EXECUTABLE_NAME"
test "$(plutil -extract CFBundleIconName raw -o - "$APPSTORE_APP_PATH/Contents/Info.plist")" = "AppIcon"
test "$(plutil -extract SUBDistributionChannel raw -o - "$APPSTORE_APP_PATH/Contents/Info.plist")" = "appstore"
test ! -e "$APPSTORE_APP_PATH/Contents/Frameworks/Sparkle.framework"
test ! -e "$APPSTORE_APP_PATH/Contents/Resources/ThirdPartyLicenses/Sparkle-LICENSE"
test "$(plutil -extract NSAppleEventsUsageDescription raw -o - "$APPSTORE_APP_PATH/Contents/Info.plist")" = "$APP_NAME reads the current playback position from QuickTime Player when you use Sync."
assert_appstore_entitlements "$APPSTORE_APP_PATH"
otool -L "$APPSTORE_APP_PATH/Contents/MacOS/$APP_EXECUTABLE_NAME" >/tmp/onemorecap-appstore-otool.txt
! grep -q "Sparkle.framework" /tmp/onemorecap-appstore-otool.txt
! grep -q "ApplicationServices.framework" /tmp/onemorecap-appstore-otool.txt

echo "One More Cap checks passed."
