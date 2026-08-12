#!/usr/bin/env bash
# Pull theme package onto THIS machine and verify.
# Prefers canonical securiace-dev/securiace-whmcs-theme when it exists;
# otherwise clones from the PDF-repo export branch.
set -euo pipefail

INSTALL_DIR="${1:-${SECURIACE_INSTALL_DIR:-$HOME/securiace-whmcs-theme}}"
ORG="${SECURIACE_GH_ORG:-securiace-dev}"
NAME="${SECURIACE_GH_REPO:-securiace-whmcs-theme}"
EXPORT_SLUG="${SECURIACE_EXPORT_REPO:-securiace-dev/securiace-whmcs-pdf-invoice-template-complex}"
EXPORT_BRANCH="${SECURIACE_EXPORT_BRANCH:-securiace-whmcs-theme}"
canonical_url="https://github.com/${ORG}/${NAME}.git"
export_url="https://github.com/${EXPORT_SLUG}.git"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

use_canonical=0
if command -v gh >/dev/null 2>&1 && gh repo view "${ORG}/${NAME}" >/dev/null 2>&1; then
  use_canonical=1
fi

if [[ -d "${INSTALL_DIR}/.git" ]]; then
  echo "==> Updating ${INSTALL_DIR}"
  cd "${INSTALL_DIR}"
  if [[ "${use_canonical}" -eq 1 ]]; then
    if git remote get-url origin >/dev/null 2>&1; then
      git remote set-url origin "${canonical_url}"
    else
      git remote add origin "${canonical_url}"
    fi
    git fetch origin
    git checkout -B main
    if git show-ref --verify --quiet refs/remotes/origin/main; then
      git reset --hard origin/main
    else
      echo "Canonical repo has no main yet — sync from export branch"
      git fetch "${export_url}" "${EXPORT_BRANCH}"
      git reset --hard FETCH_HEAD
    fi
  else
    git fetch "${export_url}" "${EXPORT_BRANCH}"
    git checkout -B main
    git reset --hard FETCH_HEAD
  fi
else
  echo "==> Cloning → ${INSTALL_DIR}"
  mkdir -p "$(dirname "${INSTALL_DIR}")"
  if [[ "${use_canonical}" -eq 1 ]]; then
    git clone "${canonical_url}" "${INSTALL_DIR}"
  else
    git clone --branch "${EXPORT_BRANCH}" --single-branch "${export_url}" "${INSTALL_DIR}"
  fi
  cd "${INSTALL_DIR}"
  git checkout -B main
fi

bash ./scripts/verify-transfer.sh

echo
echo "==> Local copy ready at ${INSTALL_DIR}"
echo "Remotes:"
git remote -v
echo "Next: bash ./scripts/publish-to-github.sh"
echo "Then: bash ./scripts/setup-my-machines-worker.sh"
echo "Then: cursor \"${INSTALL_DIR}\""
