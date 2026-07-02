#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_DIR="$ROOT_DIR/site"
CONTENT_DIR="$SITE_DIR/wwwroot"

required_paths=(
    "$SITE_DIR/.nojekyll"
    "$SITE_DIR/index.html"
    "$SITE_DIR/index_editor.html"
    "$SITE_DIR/site.yaml"
    "$SITE_DIR/assets/main.js"
    "$SITE_DIR/assets/onemorecap/app-icon.png"
    "$SITE_DIR/assets/onemorecap/site.css"
    "$SITE_DIR/assets/onemorecap/site.js"
    "$SITE_DIR/assets/themes/arcus/theme.json"
    "$SITE_DIR/assets/themes/arcus/theme.css"
    "$SITE_DIR/assets/themes/arcus/modules/layout.js"
    "$SITE_DIR/assets/themes/arcus/modules/interactions.js"
    "$ROOT_DIR/scripts/build-site.sh"
    "$CONTENT_DIR/index.yaml"
    "$CONTENT_DIR/tabs.yaml"
    "$CONTENT_DIR/tab/home/en.md"
    "$CONTENT_DIR/tab/home/chs.md"
    "$CONTENT_DIR/tab/privacy/en.md"
    "$CONTENT_DIR/tab/privacy/chs.md"
    "$CONTENT_DIR/tab/support/en.md"
    "$CONTENT_DIR/tab/support/chs.md"
)

for path in "${required_paths[@]}"; do
    if [[ ! -e "$path" ]]; then
        echo "Missing required site path: $path" >&2
        exit 1
    fi
done

grep -q '^siteTitle: One More Cap$' "$SITE_DIR/site.yaml"
grep -q '^themePack: arcus$' "$SITE_DIR/site.yaml"
grep -q '^showAllPosts: false$' "$SITE_DIR/site.yaml"
grep -q '^landingTab: Home$' "$SITE_DIR/site.yaml"
grep -q '^  owner: deemoe404$' "$SITE_DIR/site.yaml"
grep -q '^  name: onemorecap$' "$SITE_DIR/site.yaml"

grep -q '^Home:$' "$CONTENT_DIR/tabs.yaml"
grep -q '^Privacy:$' "$CONTENT_DIR/tabs.yaml"
grep -q '^Support:$' "$CONTENT_DIR/tabs.yaml"
grep -q 'location: tab/home/en.md' "$CONTENT_DIR/tabs.yaml"
grep -q 'location: tab/privacy/en.md' "$CONTENT_DIR/tabs.yaml"
grep -q 'location: tab/support/en.md' "$CONTENT_DIR/tabs.yaml"
grep -q 'location: tab/home/chs.md' "$CONTENT_DIR/tabs.yaml"
grep -q 'location: tab/privacy/chs.md' "$CONTENT_DIR/tabs.yaml"
grep -q 'location: tab/support/chs.md' "$CONTENT_DIR/tabs.yaml"

grep -q '^{}$' "$CONTENT_DIR/index.yaml"
grep -q '"value": "arcus"' "$SITE_DIR/assets/themes/packs.json"
grep -q '"digest": "sha256:987ed220ee6bc5a5b707efd7c77bf39419ecb5defd0c62e1e32e2f47c8c4c95b"' "$SITE_DIR/assets/themes/packs.json"
grep -q '"value": "en"' "$SITE_DIR/assets/i18n/languages.json"
grep -q '"value": "chs"' "$SITE_DIR/assets/i18n/languages.json"

if grep -q '"value": "\(cht-tw\|cht-hk\|ja\)"' "$SITE_DIR/assets/i18n/languages.json"; then
    echo "Language menu must only expose languages with One More Cap content pages." >&2
    exit 1
fi

if grep -q 'copy_path "index_editor' "$ROOT_DIR/scripts/build-site.sh"; then
    echo "Pages artifact must not publish Press editor entrypoints." >&2
    exit 1
fi

echo "Site checks passed."
