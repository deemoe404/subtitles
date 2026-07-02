#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

workflow=".github/workflows/sync-from-press-release.yml"

if [[ ! -f "${workflow}" ]]; then
  echo "expected ${workflow} to exist" >&2
  exit 1
fi

if ! grep -F 'repository_dispatch:' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must accept repository_dispatch events" >&2
  exit 1
fi

if ! grep -F 'press-system-release' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must listen for the press-system-release event" >&2
  exit 1
fi

if ! grep -F 'workflow_dispatch:' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must support manual runs" >&2
  exit 1
fi

if ! grep -F 'schedule:' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must include a scheduled catch-up run" >&2
  exit 1
fi

if ! grep -F 'PRESS_REPOSITORY' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must allow the Press repository to be configured" >&2
  exit 1
fi

if ! grep -F 'actions: write' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must be allowed to dispatch the Pages workflow after sync commits" >&2
  exit 1
fi

if ! grep -F 'scripts/sync-from-press-release.sh' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must run the local sync script" >&2
  exit 1
fi

if ! grep -F 'scripts/resolve-press-system-release.js' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must resolve Press release intent before downloading the system package" >&2
  exit 1
fi

if ! grep -F 'scripts/write-press-system-lock.js' "${workflow}" >/dev/null || ! grep -F 'press-system-lock.json' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must write a deterministic Press system lockfile" >&2
  exit 1
fi

if ! grep -F 'DISPATCH_RELEASE_INTENT_SOURCE' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must prefer release_intent.source from dispatch payloads" >&2
  exit 1
fi

if ! grep -F 'canonical_intent_source="https://raw.githubusercontent.com/${PRESS_REPOSITORY}/release-artifacts/${release_tag}/release-intent.json"' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must fall back to the immutable release-intent path for scheduled runs" >&2
  exit 1
fi

if ! grep -F 'payload_intent_source' "${workflow}" >/dev/null || ! grep -F 'dispatch release_intent.source must match' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must treat dispatch release_intent.source as a canonical-source consistency check only" >&2
  exit 1
fi

if ! grep -F 'legacy GitHub release metadata fallback has been sunset' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must fail closed after the legacy release metadata fallback sunset" >&2
  exit 1
fi

if ! grep -F 'PRESS_RELEASE_TARGET_RECONCILER="press-runtime-sync"' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must validate the YAP release intent target kind" >&2
  exit 1
fi

if ! grep -F 'scripts/test-sync-from-press-release.sh' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must validate the sync script before publishing to main" >&2
  exit 1
fi

if ! grep -F 'scripts/test-pages-workflow.sh' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must validate the Pages workflow before publishing to main" >&2
  exit 1
fi

if ! grep -F 'actions/checkout@v6' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must use a Node 24-compatible checkout action" >&2
  exit 1
fi

if grep -E 'actions/(checkout@v4|upload-artifact@v4)' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must not pin known Node 20-backed GitHub actions" >&2
  exit 1
fi

if grep -F 'gh pr create' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must not open pull requests for runtime updates" >&2
  exit 1
fi

if grep -F 'gh pr edit' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must not edit pull requests for runtime updates" >&2
  exit 1
fi

if grep -F 'pull-requests: write' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must not request pull request write permissions" >&2
  exit 1
fi

if ! grep -F 'git pull --rebase origin main' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must rebase on origin/main before publishing" >&2
  exit 1
fi

if ! grep -F 'git push origin HEAD:main' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must publish runtime updates directly to main" >&2
  exit 1
fi

if ! grep -F 'gh workflow run pages.yml --ref main' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must dispatch the owned Pages workflow after syncing" >&2
  exit 1
fi

test_line="$(grep -nF 'scripts/test-sync-from-press-release.sh' "${workflow}" | head -n 1 | cut -d: -f1)"
pages_test_line="$(grep -nF 'scripts/test-pages-workflow.sh' "${workflow}" | head -n 1 | cut -d: -f1)"
push_line="$(grep -nF 'git push origin HEAD:main' "${workflow}" | head -n 1 | cut -d: -f1)"
pages_dispatch_line="$(grep -nF 'gh workflow run pages.yml --ref main' "${workflow}" | head -n 1 | cut -d: -f1)"
if [[ -z "${test_line}" || -z "${pages_test_line}" || -z "${push_line}" || "${test_line}" -ge "${push_line}" || "${pages_test_line}" -ge "${push_line}" ]]; then
  echo "YAP sync workflow must validate sync and Pages scripts before pushing to main" >&2
  exit 1
fi

if [[ -z "${pages_dispatch_line}" || -z "${push_line}" || "${pages_dispatch_line}" -le "${push_line}" ]]; then
  echo "YAP sync workflow must dispatch Pages only after pushing sync changes" >&2
  exit 1
fi

if ! grep -F 'PRESS_RELEASE_TOKEN' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must support a Press release read token" >&2
  exit 1
fi

if ! grep -F 'git status --porcelain' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must detect untracked files after syncing" >&2
  exit 1
fi

if ! grep -Fx 'dist/' .gitignore >/dev/null; then
  echo "YAP sync workflow scratch files must stay out of commits" >&2
  exit 1
fi

if grep -F 'assets/themes/packs.json' "${workflow}" >/dev/null; then
  echo "YAP sync workflow must not copy packs.json directly from Press releases" >&2
  exit 1
fi

node scripts/test-release-intent-resolution.js
node scripts/test-press-system-lock.js

echo "ok - YAP sync workflow"
