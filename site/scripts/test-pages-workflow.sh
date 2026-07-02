#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

workflow=".github/workflows/pages.yml"

if [[ ! -f "${workflow}" ]]; then
  echo "expected ${workflow} to exist" >&2
  exit 1
fi

if ! grep -F 'push:' "${workflow}" >/dev/null || ! grep -F -- '- main' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must deploy direct main-branch updates" >&2
  exit 1
fi

if grep -F 'workflow_run:' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must not deploy from workflow_run because the sync workflow creates a newer commit during the run" >&2
  exit 1
fi

if ! grep -F 'workflow_dispatch:' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must support manual deploys" >&2
  exit 1
fi

if ! grep -F 'pages: write' "${workflow}" >/dev/null || ! grep -F 'id-token: write' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must request Pages artifact deployment permissions" >&2
  exit 1
fi

if ! grep -F 'actions/checkout@v6' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must use a Node 24-compatible checkout action" >&2
  exit 1
fi

if ! grep -F 'actions/configure-pages@v6' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must use a Node 24-compatible configure-pages action" >&2
  exit 1
fi

if ! grep -F 'actions/upload-pages-artifact@v5' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must use a Node 24-compatible Pages artifact action" >&2
  exit 1
fi

if ! grep -F 'actions/deploy-pages@v5' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must use a Node 24-compatible deploy-pages action" >&2
  exit 1
fi

if grep -E 'actions/(checkout@v4|configure-pages@v5|deploy-pages@v4|upload-artifact@v4|upload-pages-artifact@v3)' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must not pin known Node 20-backed GitHub actions" >&2
  exit 1
fi

if ! grep -F 'ref: main' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must deploy the main branch source" >&2
  exit 1
fi

if ! grep -F 'git ls-files -z -- .nojekyll index.html index_editor.html index_editor_preview.html site.yaml assets wwwroot' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must upload the tracked runtime and starter content surface" >&2
  exit 1
fi

if ! grep -F 'path: dist/pages' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must deploy the prepared Pages artifact directory" >&2
  exit 1
fi

if ! grep -F 'include-hidden-files: true' "${workflow}" >/dev/null; then
  echo "YAP Pages workflow must include dotfiles such as .nojekyll in the Pages artifact" >&2
  exit 1
fi

echo "ok - YAP Pages workflow"
