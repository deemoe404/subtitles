#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

if ! grep -q '^annotate:$' "${repo_root}/site.yaml" \
  || ! grep -q '^  enabled: true$' "${repo_root}/site.yaml" \
  || ! grep -q '^  connectBaseUrl: https://connect-8mr.pages.dev$' "${repo_root}/site.yaml" \
  || ! grep -q '^  discussionCategory: General$' "${repo_root}/site.yaml"; then
  echo "YAP site.yaml must default new sites to enabled Press Annotate comments" >&2
  exit 1
fi

version="v9.9.9"
payload_root="press-system-${version}"
payload_dir="${tmp_dir}/${payload_root}"
starter_dir="${tmp_dir}/starter"

mkdir -p \
  "${payload_dir}/assets/js" \
  "${payload_dir}/assets/i18n" \
  "${payload_dir}/assets/schema" \
  "${payload_dir}/assets/themes/native/modules" \
  "${starter_dir}/scripts" \
  "${starter_dir}/assets/js" \
  "${starter_dir}/assets/themes/native" \
  "${starter_dir}/wwwroot"

printf '<!doctype html>\n' > "${payload_dir}/index.html"
printf '<!doctype html>\n' > "${payload_dir}/index_editor.html"
printf '<!doctype html>\n' > "${payload_dir}/index_editor_preview.html"
printf '{"schemaVersion":1,"type":"press-system","version":"9.9.9","tag":"v9.9.9","upgradeFrom":{"ranges":[">=9.0.0 <9.9.9"],"allowUnknownSource":true,"message":""}}\n' > "${payload_dir}/assets/press-system.json"
printf '{"schemaVersion":1,"type":"press-runtime-assets","version":"9.9.9","tag":"v9.9.9","cacheKey":"press-system-v9.9.9","strategy":"query-param","entries":[]}\n' > "${payload_dir}/assets/press-runtime-manifest.json"
printf 'export const main = true;\n' > "${payload_dir}/assets/main.js"
printf 'export const manager = true;\n' > "${payload_dir}/assets/js/theme-manager.js"
printf 'export const fresh = true;\n' > "${payload_dir}/assets/js/fresh.js"
printf 'export const en = true;\n' > "${payload_dir}/assets/i18n/en.js"
printf '{}\n' > "${payload_dir}/assets/schema/theme.json"
printf '.native {}\n' > "${payload_dir}/assets/themes/native/theme.css"
printf 'export const native = true;\n' > "${payload_dir}/assets/themes/native/modules/interactions.js"
cat > "${payload_dir}/assets/themes/native/theme.json" <<'JSON'
{
  "name": "Native",
  "version": "9.9.9",
  "contractVersion": 1,
  "engines": {
    "press": ">=9.9.9 <10.0.0"
  }
}
JSON

(
  cd "${tmp_dir}"
  zip -qr "${tmp_dir}/press-system.zip" "${payload_root}"
)
archive_size="$(wc -c < "${tmp_dir}/press-system.zip" | tr -d ' ')"
archive_sha256="$(shasum -a 256 "${tmp_dir}/press-system.zip" | awk '{print $1}')"

cp "${repo_root}/scripts/sync-from-press-release.sh" "${starter_dir}/scripts/sync-from-press-release.sh"
printf 'yap-owned\n' > "${starter_dir}/site.yaml"
printf 'yap-owned\n' > "${starter_dir}/wwwroot/index.yaml"
printf 'yap-owned\n' > "${starter_dir}/.nojekyll"
printf 'stale\n' > "${starter_dir}/assets/js/stale.js"
printf 'stale\n' > "${starter_dir}/assets/themes/native/stale.css"
printf '{"schemaVersion":1,"themes":[{"value":"stale"}]}\n' > "${starter_dir}/assets/themes/catalog.json"
printf '[{"value":"arcus","files":["theme.css"]}]\n' > "${starter_dir}/assets/themes/packs.json"

(
  cd "${starter_dir}"
  git init -q
  bash scripts/sync-from-press-release.sh \
    --archive "${tmp_dir}/press-system.zip" \
    --tag "${version}" \
    --sha256 "sha256:${archive_sha256}" \
    --size "${archive_size}"
)

if [[ ! -f "${starter_dir}/.nojekyll" ]]; then
  echo "sync must preserve YAP-owned .nojekyll" >&2
  exit 1
fi
if ! grep -qx 'yap-owned' "${starter_dir}/site.yaml"; then
  echo "sync must preserve YAP-owned site.yaml" >&2
  exit 1
fi
if ! grep -qx 'yap-owned' "${starter_dir}/wwwroot/index.yaml"; then
  echo "sync must preserve YAP-owned wwwroot content" >&2
  exit 1
fi
if [[ ! -f "${starter_dir}/index_editor_preview.html" ]]; then
  echo "sync must copy the editor preview iframe shell" >&2
  exit 1
fi
if [[ -f "${starter_dir}/assets/js/stale.js" ]]; then
  echo "sync must delete stale system JS files" >&2
  exit 1
fi
if [[ -f "${starter_dir}/assets/themes/native/stale.css" ]]; then
  echo "sync must delete stale native theme files" >&2
  exit 1
fi
if [[ -f "${starter_dir}/assets/themes/catalog.json" ]]; then
  echo "sync must delete stale bundled official theme catalog" >&2
  exit 1
fi
if ! grep -q '"version":"9.9.9"' "${starter_dir}/assets/press-system.json" && ! grep -q '"version": "9.9.9"' "${starter_dir}/assets/press-system.json"; then
  echo "sync must copy the Press system version manifest" >&2
  exit 1
fi
if ! grep -q '"type":"press-runtime-assets"' "${starter_dir}/assets/press-runtime-manifest.json" && ! grep -q '"type": "press-runtime-assets"' "${starter_dir}/assets/press-runtime-manifest.json"; then
  echo "sync must copy the generated Press runtime asset manifest" >&2
  exit 1
fi
if ! grep -q '"value": "native"' "${starter_dir}/assets/themes/packs.json"; then
  echo "sync must regenerate native registry entry" >&2
  exit 1
fi
if ! grep -q '"engines"' "${starter_dir}/assets/themes/packs.json"; then
  echo "sync must record native Press engine compatibility in packs.json" >&2
  exit 1
fi
if grep -q 'arcus' "${starter_dir}/assets/themes/packs.json"; then
  echo "sync must not preserve non-native installed registry entries in YAP" >&2
  exit 1
fi
if ! grep -q '"theme.css"' "${starter_dir}/assets/themes/packs.json"; then
  echo "sync must record native files in packs.json" >&2
  exit 1
fi

legacy_payload_root="press-system-v9.8.0"
legacy_payload_dir="${tmp_dir}/${legacy_payload_root}"
mkdir -p \
  "${legacy_payload_dir}/assets/js" \
  "${legacy_payload_dir}/assets/i18n" \
  "${legacy_payload_dir}/assets/schema" \
  "${legacy_payload_dir}/assets/themes/native/modules"
cp "${payload_dir}/index.html" "${legacy_payload_dir}/index.html"
cp "${payload_dir}/index_editor.html" "${legacy_payload_dir}/index_editor.html"
cp "${payload_dir}/index_editor_preview.html" "${legacy_payload_dir}/index_editor_preview.html"
printf '{"schemaVersion":1,"type":"press-system","version":"9.8.0","tag":"v9.8.0","upgradeFrom":{"ranges":[">=9.0.0 <9.8.0"],"allowUnknownSource":true,"message":""}}\n' > "${legacy_payload_dir}/assets/press-system.json"
printf 'export const main = "legacy";\n' > "${legacy_payload_dir}/assets/main.js"
printf 'export const manager = "legacy";\n' > "${legacy_payload_dir}/assets/js/theme-manager.js"
printf 'export const en = "legacy";\n' > "${legacy_payload_dir}/assets/i18n/en.js"
printf '{}\n' > "${legacy_payload_dir}/assets/schema/theme.json"
cp "${payload_dir}/assets/themes/native/theme.css" "${legacy_payload_dir}/assets/themes/native/theme.css"
cp "${payload_dir}/assets/themes/native/modules/interactions.js" "${legacy_payload_dir}/assets/themes/native/modules/interactions.js"
cp "${payload_dir}/assets/themes/native/theme.json" "${legacy_payload_dir}/assets/themes/native/theme.json"
(
  cd "${tmp_dir}"
  zip -qr "${tmp_dir}/legacy-press-system.zip" "${legacy_payload_root}"
)
(
  cd "${starter_dir}"
  bash scripts/sync-from-press-release.sh --archive "${tmp_dir}/legacy-press-system.zip" --tag "v9.8.0"
)
if [[ -f "${starter_dir}/assets/press-runtime-manifest.json" ]]; then
  echo "sync must remove stale runtime manifests when syncing older Press releases" >&2
  exit 1
fi

bad_payload="${tmp_dir}/bad-payload"
mkdir -p "${bad_payload}/${payload_root}/assets/themes"
cp -R "${payload_dir}/." "${bad_payload}/${payload_root}/"
printf '[]\n' > "${bad_payload}/${payload_root}/assets/themes/packs.json"
(
  cd "${bad_payload}"
  zip -qr "${tmp_dir}/bad-press-system.zip" "${payload_root}"
)
if (
  cd "${starter_dir}"
  bash scripts/sync-from-press-release.sh --archive "${tmp_dir}/bad-press-system.zip" --tag "${version}" >/dev/null 2>&1
); then
  echo "sync must reject system archives that include packs.json" >&2
  exit 1
fi

echo "ok - YAP sync from Press release"
