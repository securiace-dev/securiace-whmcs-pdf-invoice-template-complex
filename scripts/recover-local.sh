#!/usr/bin/env bash
# One-shot recovery when origin still points at the PDF export repo,
# publish failed with "Unable to add remote origin", or push went to the wrong remote.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Recovering remotes and pushing to securiace-dev/securiace-whmcs-theme"
bash "${ROOT}/scripts/publish-to-github.sh"

echo
echo "==> Verify"
bash "${ROOT}/scripts/verify-transfer.sh"

echo
echo "==> Restart My Machines worker with the corrected origin"
echo "In a dedicated terminal keep this running:"
echo "  bash ${ROOT}/scripts/setup-my-machines-worker.sh"
echo
echo "Then open: cursor ${ROOT}"
