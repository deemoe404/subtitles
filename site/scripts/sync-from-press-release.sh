#!/usr/bin/env bash
set -euo pipefail

archive_path=""
release_url=""
expected_sha256="${PRESS_RELEASE_SHA256:-}"
expected_size="${PRESS_RELEASE_SIZE:-}"
release_tag="${PRESS_RELEASE_TAG:-}"

usage() {
  echo "usage: $0 (--archive path | --url url) [--tag vX.Y.Z] [--sha256 sha256] [--size bytes]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --archive)
      [[ $# -ge 2 ]] || usage
      archive_path="$2"
      shift 2
      ;;
    --url)
      [[ $# -ge 2 ]] || usage
      release_url="$2"
      shift 2
      ;;
    --tag)
      [[ $# -ge 2 ]] || usage
      release_tag="$2"
      shift 2
      ;;
    --sha256)
      [[ $# -ge 2 ]] || usage
      expected_sha256="$2"
      shift 2
      ;;
    --size)
      [[ $# -ge 2 ]] || usage
      expected_size="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "${archive_path}" && -z "${release_url}" ]]; then
  usage
fi
if [[ -n "${archive_path}" && -n "${release_url}" ]]; then
  usage
fi

repo_root="$(git rev-parse --show-toplevel)"
tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

if [[ -n "${release_url}" ]]; then
  archive_path="${tmp_dir}/press-system.zip"
  curl_args=(--fail-with-body --location --silent --show-error --output "${archive_path}")
  if [[ -n "${PRESS_RELEASE_TOKEN:-}" ]]; then
    curl_args+=(--header "Authorization: Bearer ${PRESS_RELEASE_TOKEN}")
  fi
  curl "${curl_args[@]}" "${release_url}"
fi

if [[ ! -f "${archive_path}" ]]; then
  echo "release archive not found: ${archive_path}" >&2
  exit 1
fi

actual_size="$(wc -c < "${archive_path}" | tr -d ' ')"
if [[ -n "${expected_size}" && "${actual_size}" != "${expected_size}" ]]; then
  echo "release archive size mismatch: expected ${expected_size}, got ${actual_size}" >&2
  exit 1
fi

actual_sha256="$(shasum -a 256 "${archive_path}" | awk '{print $1}')"
expected_sha256="${expected_sha256#sha256:}"
if [[ -n "${expected_sha256}" && "${actual_sha256}" != "${expected_sha256}" ]]; then
  echo "release archive SHA-256 mismatch: expected ${expected_sha256}, got ${actual_sha256}" >&2
  exit 1
fi

entries_file="${tmp_dir}/entries.txt"
unzip -Z1 "${archive_path}" > "${entries_file}"

payload_root=""
while IFS= read -r entry; do
  [[ -n "${entry}" ]] || continue
  if [[ "${entry}" == /* || "${entry}" == *\\* ]]; then
    echo "unsafe archive path: ${entry}" >&2
    exit 1
  fi

  IFS='/' read -r -a parts <<< "${entry}"
  for part in "${parts[@]}"; do
    if [[ "${part}" == ".." ]]; then
      echo "unsafe archive path: ${entry}" >&2
      exit 1
    fi
  done

  top="${parts[0]}"
  [[ -n "${top}" ]] || continue
  if [[ -z "${payload_root}" ]]; then
    payload_root="${top}"
  elif [[ "${payload_root}" != "${top}" ]]; then
    echo "release archive must contain a single top-level payload directory" >&2
    exit 1
  fi
done < "${entries_file}"

if [[ -z "${payload_root}" ]]; then
  echo "release archive is empty" >&2
  exit 1
fi

if [[ -n "${release_tag}" && "${payload_root}" != "press-system-${release_tag}" ]]; then
  echo "release archive root ${payload_root} does not match ${release_tag}" >&2
  exit 1
fi

while IFS= read -r entry; do
  [[ -n "${entry}" ]] || continue
  [[ "${entry}" != */ ]] || continue
  rel="${entry#${payload_root}/}"
  [[ "${rel}" != "${entry}" ]] || continue

  case "${rel}" in
    index.html|index_editor.html|index_editor_preview.html|assets/press-system.json|assets/press-runtime-manifest.json|assets/main.js) ;;
    assets/js/*|assets/i18n/*|assets/schema/*|assets/themes/native/*) ;;
    assets/themes/packs.json)
      echo "system release archive must not provide YAP packs.json" >&2
      exit 1
      ;;
    *)
      echo "unexpected system release file: ${rel}" >&2
      exit 1
      ;;
  esac
done < "${entries_file}"

extract_dir="${tmp_dir}/extract"
mkdir -p "${extract_dir}"
unzip -q "${archive_path}" -d "${extract_dir}"
payload_dir="${extract_dir}/${payload_root}"

require_payload_file() {
  local path="$1"
  if [[ ! -f "${payload_dir}/${path}" ]]; then
    echo "system release archive is missing ${path}" >&2
    exit 1
  fi
}

require_payload_dir() {
  local path="$1"
  if [[ ! -d "${payload_dir}/${path}" ]]; then
    echo "system release archive is missing ${path}/" >&2
    exit 1
  fi
}

copy_payload_file() {
  local path="$1"
  require_payload_file "${path}"
  mkdir -p "${repo_root}/$(dirname "${path}")"
  cp "${payload_dir}/${path}" "${repo_root}/${path}"
}

copy_optional_payload_file() {
  local path="$1"
  if [[ -f "${payload_dir}/${path}" ]]; then
    mkdir -p "${repo_root}/$(dirname "${path}")"
    cp "${payload_dir}/${path}" "${repo_root}/${path}"
  else
    rm -f "${repo_root}/${path}"
  fi
}

sync_payload_dir() {
  local path="$1"
  require_payload_dir "${path}"
  mkdir -p "${repo_root}/${path}"
  rsync -a --delete "${payload_dir}/${path}/" "${repo_root}/${path}/"
}

copy_payload_file "index.html"
copy_payload_file "index_editor.html"
copy_payload_file "index_editor_preview.html"
copy_payload_file "assets/press-system.json"
copy_optional_payload_file "assets/press-runtime-manifest.json"
copy_payload_file "assets/main.js"
sync_payload_dir "assets/js"
sync_payload_dir "assets/i18n"
sync_payload_dir "assets/schema"
sync_payload_dir "assets/themes/native"
rm -f "${repo_root}/assets/themes/catalog.json"

require_payload_file "assets/js/theme-manager.js"
require_payload_file "assets/press-system.json"
require_payload_file "assets/themes/native/theme.json"

export PRESS_RELEASE_TAG="${release_tag}"
export PRESS_STARTER_REPO_ROOT="${repo_root}"
node <<'NODE'
const fs = require('fs');
const path = require('path');

const repoRoot = process.env.PRESS_STARTER_REPO_ROOT;
const releaseTag = process.env.PRESS_RELEASE_TAG || '';
const themeDir = path.join(repoRoot, 'assets', 'themes', 'native');
const manifestPath = path.join(themeDir, 'theme.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

function walk(dir, prefix = '') {
  const entries = fs.readdirSync(dir, { withFileTypes: true })
    .sort((a, b) => a.name.localeCompare(b.name));
  const files = [];
  for (const entry of entries) {
    const absolute = path.join(dir, entry.name);
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      files.push(...walk(absolute, relative));
    } else if (entry.isFile()) {
      files.push(relative);
    }
  }
  return files;
}

const registryEntry = {
  value: 'native',
  label: String(manifest.name || 'Native'),
  version: String(manifest.version || ''),
  contractVersion: Number(manifest.contractVersion || 1),
  engines: manifest.engines && typeof manifest.engines === 'object' ? manifest.engines : {},
  builtIn: true,
  removable: false,
  source: {
    type: 'builtin'
  },
  release: releaseTag ? { tag: releaseTag } : {},
  files: walk(themeDir)
};

fs.writeFileSync(
  path.join(repoRoot, 'assets', 'themes', 'packs.json'),
  `${JSON.stringify([registryEntry], null, 2)}\n`,
  'utf8'
);
NODE

echo "Synced Press system release ${release_tag:-unknown} into YAP."
