#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_DIR="$ROOT_DIR/site"
OUTPUT_DIR="${1:-$ROOT_DIR/dist/pages}"

copy_path() {
    local relative_path="$1"
    local source_path="$SITE_DIR/$relative_path"
    local target_path="$OUTPUT_DIR/$relative_path"

    if [[ ! -e "$source_path" ]]; then
        echo "Missing site path: $source_path" >&2
        exit 1
    fi

    if [[ -d "$source_path" ]]; then
        mkdir -p "$target_path"
        rsync -a "$source_path/" "$target_path/"
    else
        mkdir -p "$(dirname "$target_path")"
        rsync -a "$source_path" "$target_path"
    fi
}

"$ROOT_DIR/scripts/check-site.sh" >/dev/null

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

copy_path ".nojekyll"
copy_path "index.html"
copy_path "press-system-lock.json"
copy_path "site.yaml"
copy_path "assets"
copy_path "wwwroot"

find "$OUTPUT_DIR" -name ".DS_Store" -delete

printf '%s\n' "$OUTPUT_DIR"
