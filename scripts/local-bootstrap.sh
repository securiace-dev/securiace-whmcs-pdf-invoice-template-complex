#!/usr/bin/env bash
# One-shot macOS/local setup: clone export branch, publish canonical repo, run tests.
# Usage (any shell — including nushell):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex/export/securiace-whmcs-theme/scripts/local-bootstrap.sh)"
# Or after clone:
#   bash ./scripts/local-bootstrap.sh
#   bash ./scripts/local-bootstrap.sh ~/Projects/securiace-whmcs-theme
set -euo pipefail

ORG="${SECURIACE_GH_ORG:-securiace-dev}"
REPO_NAME="${SECURIACE_GH_REPO:-securiace-whmcs-theme}"
EXPORT_SLUG="${SECURIACE_EXPORT_REPO:-securiace-dev/securiace-whmcs-pdf-invoice-template-complex}"
EXPORT_BRANCH="${SECURIACE_EXPORT_BRANCH:-export/securiace-whmcs-theme}"
INSTALL_DIR="${1:-${SECURIACE_INSTALL_DIR:-$HOME/securiace-whmcs-theme}}"
WORKER_NAME="${SECURIACE_WORKER_NAME:-kritananda-mac}"
START_WORKER="${SECURIACE_START_WORKER:-0}"

export_url="https://github.com/${EXPORT_SLUG}.git"
canonical_url="https://github.com/${ORG}/${REPO_NAME}.git"

log() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

require_cmd git
require_cmd gh

log "Checking GitHub auth on THIS machine (must not be cloud integration 'cursor')"
if gh auth status 2>&1 | grep -q 'Logged in to github.com account cursor'; then
  die "Still on Cursor cloud integration token. Run on your Mac: gh auth login"
fi
gh auth status

if [[ -d "${INSTALL_DIR}/.git" ]]; then
  log "Updating existing checkout: ${INSTALL_DIR}"
  cd "${INSTALL_DIR}"
  git fetch origin "${EXPORT_BRANCH}" 2>/dev/null || git fetch --all
else
  log "Cloning export branch into ${INSTALL_DIR}"
  mkdir -p "$(dirname "${INSTALL_DIR}")"
  git clone --branch "${EXPORT_BRANCH}" --single-branch "${export_url}" "${INSTALL_DIR}"
  cd "${INSTALL_DIR}"
fi

# Normalize local branch name to main for the canonical repo.
current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${current_branch}" != "main" ]]; then
  git checkout -B main
fi

log "Publishing canonical repo ${ORG}/${REPO_NAME}"
origin_url="$(git remote get-url origin 2>/dev/null || true)"
if [[ -n "${origin_url}" ]] && [[ "${origin_url}" != *"${ORG}/${REPO_NAME}"* ]]; then
  log "Removing temporary export remote (${origin_url})"
  git remote remove origin
fi

if gh repo view "${ORG}/${REPO_NAME}" >/dev/null 2>&1; then
  log "Remote ${ORG}/${REPO_NAME} already exists — pushing main"
  if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "${canonical_url}"
  else
    git remote set-url origin "${canonical_url}"
  fi
  git push -u origin main
else
  log "Creating ${ORG}/${REPO_NAME}"
  gh repo create "${ORG}/${REPO_NAME}" \
    --private \
    --description "Unified Securiace WHMCS child theme, brand system, and PDF invoice/quote suite" \
    --source . \
    --remote origin \
    --push
fi

if command -v php >/dev/null 2>&1; then
  log "Running contract tests"
  php tests/handoff_contract_test.php
  php tests/child_theme_package_contract_test.php
  php tests/modern_invoice_design_contract_test.php
  php tests/modern_quote_template_contract_test.php
  php tests/preview_contract_test.php
  php tests/quote_preview_contract_test.php
else
  log "php not found — skipping tests (install php and re-run tests from README)"
fi

log "Done. Canonical repo: ${canonical_url}"
log "Open this folder in Cursor on your Mac:"
printf '  cursor "%s"\n' "${INSTALL_DIR}"

if [[ "${START_WORKER}" == "1" ]]; then
  log "Starting My Machines worker (${WORKER_NAME})"
  exec bash "${INSTALL_DIR}/scripts/setup-my-machines-worker.sh"
fi

cat <<EOF

Next (local Cursor agent on Mac — not cloud VM):
  cd "${INSTALL_DIR}"
  cursor .

Optional My Machines worker (keep terminal open):
  bash ./scripts/setup-my-machines-worker.sh

Remaining operator tasks: docs/LOCAL-HANDOFF.md
EOF
