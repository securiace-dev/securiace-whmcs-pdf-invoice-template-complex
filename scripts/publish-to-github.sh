#!/usr/bin/env bash
# Publish / re-point this checkout to securiace-dev/securiace-whmcs-theme.
# Safe to re-run when origin still points at the PDF export repo.
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

# Always force origin to the canonical theme repo (never leave export remote as origin).
if git remote get-url origin >/dev/null 2>&1; then
  current="$(git remote get-url origin)"
  if [[ "${current}" != *"${ORG}/${NAME}"* ]]; then
    echo "Retargeting origin away from: ${current}"
    git remote remove origin
  fi
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "${canonical_url}"
else
  git remote set-url origin "${canonical_url}"
fi

# Keep a named remote for the temporary export source if useful.
if ! git remote get-url export >/dev/null 2>&1; then
  git remote add export \
    "https://github.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex.git" \
    2>/dev/null || true
fi

# Ensure local branch is main before push.
branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${branch}" != "main" ]]; then
  git branch -M main
fi

if ! gh repo view "${ORG}/${NAME}" >/dev/null 2>&1; then
  echo "Creating ${ORG}/${NAME}"
  gh repo create "${ORG}/${NAME}" \
    --private \
    --description "Unified Securiace WHMCS child theme, brand system, and PDF invoice/quote suite"
fi

echo "Pushing main → ${canonical_url}"
git push -u origin main
echo "Done. origin is now ${ORG}/${NAME}"
git remote -v
gh repo view "${ORG}/${NAME}" --json url,defaultBranchRef --jq '{url,defaultBranch:.defaultBranchRef.name}'
