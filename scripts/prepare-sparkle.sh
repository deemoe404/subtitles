#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.sh
source "$ROOT_DIR/scripts/env.sh"
load_onemorecap_env "$ROOT_DIR"

SPARKLE_VERSION="${ONEMORECAP_SPARKLE_VERSION:-2.9.3}"
SPARKLE_URL="${ONEMORECAP_SPARKLE_URL:-https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-for-Swift-Package-Manager.zip}"
SPARKLE_CHECKSUM="${ONEMORECAP_SPARKLE_ZIP_CHECKSUM:-}"

if [[ -z "$SPARKLE_CHECKSUM" ]]; then
    case "$SPARKLE_VERSION" in
        2.9.3)
            SPARKLE_CHECKSUM="3a5d7fd698acc39c122e75764ed3614b472b284cc483f32ae7006d86c513370c"
            ;;
        *)
            echo "ONEMORECAP_SPARKLE_ZIP_CHECKSUM is required for Sparkle $SPARKLE_VERSION" >&2
            exit 1
            ;;
    esac
fi

VENDOR_DIR="$ROOT_DIR/Vendor/Sparkle"
XCFRAMEWORK_DIR="$VENDOR_DIR/Sparkle.xcframework"
BIN_DIR="$VENDOR_DIR/bin"
LICENSE_FILE="$VENDOR_DIR/LICENSE"

if [[ -d "$XCFRAMEWORK_DIR" && -x "$BIN_DIR/sign_update" && -x "$BIN_DIR/generate_keys" && -x "$BIN_DIR/generate_appcast" && -f "$LICENSE_FILE" ]]; then
    echo "$XCFRAMEWORK_DIR"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ZIP_PATH="$TMP_DIR/Sparkle-for-Swift-Package-Manager.zip"
EXTRACT_DIR="$TMP_DIR/extract"

curl --fail --location --silent --show-error --retry 3 --retry-delay 2 --output "$ZIP_PATH" "$SPARKLE_URL"

ACTUAL_CHECKSUM="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
if [[ "$ACTUAL_CHECKSUM" != "$SPARKLE_CHECKSUM" ]]; then
    echo "Sparkle checksum mismatch for $SPARKLE_URL" >&2
    echo "expected: $SPARKLE_CHECKSUM" >&2
    echo "actual:   $ACTUAL_CHECKSUM" >&2
    exit 1
fi

mkdir -p "$EXTRACT_DIR"
/usr/bin/ditto -x -k "$ZIP_PATH" "$EXTRACT_DIR"

rm -rf "$VENDOR_DIR"
mkdir -p "$VENDOR_DIR"
/usr/bin/ditto "$EXTRACT_DIR/Sparkle.xcframework" "$XCFRAMEWORK_DIR"
/usr/bin/ditto "$EXTRACT_DIR/bin" "$BIN_DIR"
cp "$EXTRACT_DIR/LICENSE" "$LICENSE_FILE"
cp "$EXTRACT_DIR/INSTALL" "$VENDOR_DIR/INSTALL"

echo "$XCFRAMEWORK_DIR"
