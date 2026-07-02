#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.sh
source "$ROOT_DIR/scripts/env.sh"
load_onemorecap_env "$ROOT_DIR"

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: scripts/create-appcast.sh <update-archive.zip> [release-notes.md]" >&2
    exit 2
fi

ARCHIVE_PATH="$1"
RELEASE_NOTES_PATH="${2:-}"
SPARKLE_PRIVATE_KEY="${ONEMORECAP_SPARKLE_PRIVATE_KEY:-}"
SPARKLE_PRIVATE_KEY_FILE="${ONEMORECAP_SPARKLE_PRIVATE_KEY_FILE:-}"
SPARKLE_KEY_ACCOUNT="${ONEMORECAP_SPARKLE_KEY_ACCOUNT:-onemorecap}"
OUTPUT_DIR="${ONEMORECAP_SPARKLE_APPCAST_DIR:-$ROOT_DIR/dist/sparkle-feed}"
OUTPUT_PATH="${ONEMORECAP_SPARKLE_APPCAST_PATH:-$OUTPUT_DIR/appcast.xml}"
REPOSITORY="${GITHUB_REPOSITORY:-deemoe404/onemorecap}"
RELEASE_TAG="${RELEASE_TAG:-${GITHUB_REF_NAME:-}}"
DOWNLOAD_URL_PREFIX="${ONEMORECAP_SPARKLE_DOWNLOAD_URL_PREFIX:-}"
FULL_RELEASE_NOTES_URL="${ONEMORECAP_SPARKLE_FULL_RELEASE_NOTES_URL:-}"

if [[ ! -f "$ARCHIVE_PATH" ]]; then
    echo "Update archive does not exist: $ARCHIVE_PATH" >&2
    exit 1
fi

if [[ -n "$RELEASE_NOTES_PATH" && ! -f "$RELEASE_NOTES_PATH" ]]; then
    echo "Release notes file does not exist: $RELEASE_NOTES_PATH" >&2
    exit 1
fi

if [[ -z "$DOWNLOAD_URL_PREFIX" ]]; then
    if [[ -z "$RELEASE_TAG" ]]; then
        echo "RELEASE_TAG or ONEMORECAP_SPARKLE_DOWNLOAD_URL_PREFIX is required" >&2
        exit 1
    fi
    DOWNLOAD_URL_PREFIX="https://github.com/$REPOSITORY/releases/download/$RELEASE_TAG/"
fi

if [[ "$OUTPUT_DIR" == "/" || "$OUTPUT_DIR" == "$ROOT_DIR" || "$OUTPUT_DIR" == "$ROOT_DIR/" ]]; then
    echo "Refusing to use unsafe Sparkle appcast output directory: $OUTPUT_DIR" >&2
    exit 1
fi

"$ROOT_DIR/scripts/prepare-sparkle.sh" >/dev/null

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

ARCHIVE_BASENAME="$(basename "$ARCHIVE_PATH")"
ARCHIVE_STEM="${ARCHIVE_BASENAME%.*}"
cp "$ARCHIVE_PATH" "$OUTPUT_DIR/$ARCHIVE_BASENAME"

if [[ -n "$RELEASE_NOTES_PATH" ]]; then
    cp "$RELEASE_NOTES_PATH" "$OUTPUT_DIR/$ARCHIVE_STEM.md"
fi

generate_args=(
    --account "$SPARKLE_KEY_ACCOUNT"
    --download-url-prefix "$DOWNLOAD_URL_PREFIX"
    --embed-release-notes
    --maximum-deltas 0
    -o "$OUTPUT_PATH"
)

if [[ -n "$FULL_RELEASE_NOTES_URL" ]]; then
    generate_args+=(--full-release-notes-url "$FULL_RELEASE_NOTES_URL")
fi

if [[ -n "$SPARKLE_PRIVATE_KEY" ]]; then
    printf '%s' "$SPARKLE_PRIVATE_KEY" | "$ROOT_DIR/Vendor/Sparkle/bin/generate_appcast" --ed-key-file - "${generate_args[@]}" "$OUTPUT_DIR"
elif [[ -n "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
    "$ROOT_DIR/Vendor/Sparkle/bin/generate_appcast" --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" "${generate_args[@]}" "$OUTPUT_DIR"
else
    "$ROOT_DIR/Vendor/Sparkle/bin/generate_appcast" "${generate_args[@]}" "$OUTPUT_DIR"
fi

if [[ -n "$SPARKLE_PRIVATE_KEY" || -n "$SPARKLE_PRIVATE_KEY_FILE" ]] && ! grep -q 'sparkle:edSignature=' "$OUTPUT_PATH"; then
    echo "Sparkle appcast was generated without an EdDSA signature." >&2
    echo "Check that ONEMORECAP_SPARKLE_PUBLIC_ED_KEY matches the private key used for signing." >&2
    exit 1
fi

echo "$OUTPUT_PATH"
