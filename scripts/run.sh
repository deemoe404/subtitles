#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/env.sh
source "$ROOT_DIR/scripts/env.sh"
load_onemorecap_env "$ROOT_DIR"

APP_PATH="$("$ROOT_DIR/scripts/package-app.sh" | tail -n 1)"

open "$APP_PATH"
echo "$APP_PATH"
