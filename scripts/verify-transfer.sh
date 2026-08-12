#!/usr/bin/env bash
# Verify this checkout matches the cloud→GitHub transfer tip.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

EXPECTED_TIP="${SECURIACE_EXPECTED_TIP:-a77adcf64d25155d2bf4a87c70b5f2b2be7e6abf}"
HEAD="$(git rev-parse HEAD)"
COUNT="$(find . -type f ! -path './.git/*' | wc -l | tr -d ' ')"

echo "HEAD:  $HEAD"
echo "Files: $COUNT"

ok=0
if [[ "$HEAD" == "$EXPECTED_TIP" ]]; then
  echo "OK tip matches transfer audit"
else
  echo "WARN tip differs from audited $EXPECTED_TIP (branch may have advanced)"
fi

test -f templates/securiace/theme.yaml || { echo "MISSING templates/securiace/theme.yaml"; ok=1; }
test -f templates/securiace/css/custom.css || { echo "MISSING custom.css"; ok=1; }
test -f templates/securiace/invoicepdf.tpl || { echo "MISSING packaged invoicepdf.tpl"; ok=1; }
test -f hooks/securiace-theme-mode.php || { echo "MISSING theme hook"; ok=1; }
test -f assets/brand/tokens.json || { echo "MISSING brand tokens"; ok=1; }
test -f invoicepdf-modern.tpl || { echo "MISSING invoicepdf-modern.tpl"; ok=1; }
test -f scripts/publish-to-github.sh || { echo "MISSING publish script"; ok=1; }
test -f docs/TRANSFER-AUDIT.md || { echo "MISSING TRANSFER-AUDIT.md"; ok=1; }

if command -v php >/dev/null 2>&1; then
  php tests/handoff_contract_test.php
  php tests/child_theme_package_contract_test.php
  php tests/modern_invoice_design_contract_test.php
  php tests/modern_quote_template_contract_test.php
  echo "OK contract tests"
else
  echo "SKIP php tests (php not installed)"
fi

if [[ "$ok" -ne 0 ]]; then
  echo "VERIFY FAILED"
  exit 1
fi
echo "VERIFY PASSED"
