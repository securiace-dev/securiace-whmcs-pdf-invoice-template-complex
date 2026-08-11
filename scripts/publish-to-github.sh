#!/usr/bin/env bash
# Publish securiace-whmcs-theme to GitHub using host-authorized gh/git.
# Run on the macOS workstation (or any host with org-create scopes), not in
# the Cursor cloud sandbox.
# Prefer: bash ./scripts/local-bootstrap.sh (handles export-branch clone too).
set -euo pipefail

ORG="${SECURIACE_GH_ORG:-securiace-dev}"
NAME="${SECURIACE_GH_REPO:-securiace-whmcs-theme}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required on the host" >&2
  exit 1
fi

gh auth status >/dev/null

canonical_url="https://github.com/${ORG}/${NAME}.git"
origin_url="$(git remote get-url origin 2>/dev/null || true)"
if [[ -n "${origin_url}" ]] && [[ "${origin_url}" != *"${ORG}/${NAME}"* ]]; then
  echo "Removing non-canonical origin: ${origin_url}"
  git remote remove origin
fi

if gh repo view "${ORG}/${NAME}" >/dev/null 2>&1; then
  echo "Remote ${ORG}/${NAME} already exists"
else
  gh repo create "${ORG}/${NAME}" \
    --private \
    --description "Unified Securiace WHMCS child theme, brand system, and PDF invoice/quote suite" \
    --source . \
    --remote origin \
    --push
  echo "Created and pushed ${ORG}/${NAME}"
  exit 0
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "${canonical_url}"
fi

git push -u origin HEAD
echo "Pushed to ${ORG}/${NAME}"
