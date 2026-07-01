#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.sh
source "$ROOT_DIR/scripts/env.sh"
load_subtitles_env "$ROOT_DIR"

SPARKLE_KEY_ACCOUNT="${SUBTITLES_SPARKLE_KEY_ACCOUNT:-subtitles}"

"$ROOT_DIR/scripts/prepare-sparkle.sh" >/dev/null
"$ROOT_DIR/Vendor/Sparkle/bin/generate_keys" --account "$SPARKLE_KEY_ACCOUNT" "$@"
