#!/usr/bin/env bash
# Pull cloud work from GitHub onto THIS machine and verify.
# Run on macOS with bash (not nushell):
#   bash <(curl -fsSL https://raw.githubusercontent.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex/securiace-whmcs-theme/scripts/pull-to-local.sh)
# Or:
#   curl -fsSL .../pull-to-local.sh -o /tmp/pull-to-local.sh && bash /tmp/pull-to-local.sh
set -euo pipefail

INSTALL_DIR="${1:-${SECURIACE_INSTALL_DIR:-$HOME/securiace-whmcs-theme}}"
EXPORT_SLUG="${SECURIACE_EXPORT_REPO:-securiace-dev/securiace-whmcs-pdf-invoice-template-complex}"
EXPORT_BRANCH="${SECURIACE_EXPORT_BRANCH:-securiace-whmcs-theme}"
export_url="https://github.com/${EXPORT_SLUG}.git"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

if [[ -d "${INSTALL_DIR}/.git" ]]; then
  echo "==> Updating ${INSTALL_DIR}"
  cd "${INSTALL_DIR}"
  git fetch origin "${EXPORT_BRANCH}"
  git checkout -B main "origin/${EXPORT_BRANCH}" 2>/dev/null \
    || git checkout -B main "${EXPORT_BRANCH}"
  git reset --hard "origin/${EXPORT_BRANCH}" 2>/dev/null \
    || git reset --hard "FETCH_HEAD"
else
  echo "==> Cloning ${EXPORT_BRANCH} → ${INSTALL_DIR}"
  mkdir -p "$(dirname "${INSTALL_DIR}")"
  git clone --branch "${EXPORT_BRANCH}" --single-branch "${export_url}" "${INSTALL_DIR}"
  cd "${INSTALL_DIR}"
  git checkout -B main
fi

bash ./scripts/verify-transfer.sh

echo
echo "==> Local copy ready at ${INSTALL_DIR}"
echo "Next: bash ./scripts/publish-to-github.sh"
echo "Then: cursor \"${INSTALL_DIR}\""
