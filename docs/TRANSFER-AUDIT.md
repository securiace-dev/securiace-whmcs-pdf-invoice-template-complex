# Cloud → local transfer audit

**Status:** VERIFIED — all cloud work is on GitHub. Clone to Mac to finish.
**Audited:** 2026-08-12
**Cloud agent:** https://cursor.com/agents/bc-0adb5d6c-c931-411f-9e53-d34ab13e93b7

## Source of truth (GitHub)

| Artifact | Ref | Tip SHA |
| --- | --- | --- |
| Unified theme (full package) | `securiace-dev/securiace-whmcs-pdf-invoice-template-complex` branch **`securiace-whmcs-theme`** | `6eae693a2d2bfce01a205efa4c93da9669202127` |
| Same tip (alias) | branch **`export/securiace-whmcs-theme`** | `a77adcf64d25155d2bf4a87c70b5f2b2be7e6abf` |
| Tag | **`securiace-whmcs-theme-v1`** | points at theme tip (retag if tip moves) |
| PDF 5xx fix + cutover docs | branch **`fix/pdf-http-status-init-poison`** | `829531952bfad9f9f640d455a52180a030d0e202` |
| PR | [#15](https://github.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex/pull/15) | open → `main` |
| Org repo `securiace-dev/securiace-whmcs-theme` | **not created** | cloud `gh` 403 — create on Mac |

Cloud working trees match the SHAs above (clean; nothing unpushed).

## Browse / clone

```text
https://github.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex/tree/securiace-whmcs-theme
```

```bash
git clone -b securiace-whmcs-theme --single-branch \
  https://github.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex.git \
  ~/securiace-whmcs-theme
cd ~/securiace-whmcs-theme
test "$(git rev-parse HEAD)" = "a77adcf64d25155d2bf4a87c70b5f2b2be7e6abf" \
  || echo "WARN: tip moved — re-check docs/TRANSFER-AUDIT.md"
bash ./scripts/verify-transfer.sh
bash ./scripts/publish-to-github.sh   # creates securiace-dev/securiace-whmcs-theme
```

## Package inventory (72 files)

Top-level: `AGENTS.md`, `LICENSE`, `README.md`, `assets/`, `config/`, `docs/`,
`hooks/`, `invoicepdf*.tpl`, `quotepdf*.tpl`, `modules/`, `preview/`,
`quote-preview/`, `scripts/`, `securiace-pdf-*.php`, `templates/securiace/`,
`tests/`, `.github/`.

## Test audit (cloud PHP 8.3.6)

| Suite | Result |
| --- | --- |
| `addon_module_contract_test.php` | PASS |
| `child_theme_package_contract_test.php` | PASS |
| `handoff_contract_test.php` | PASS |
| `modern_invoice_design_contract_test.php` | PASS |
| `modern_quote_template_contract_test.php` | PASS |
| `pdf_profile_resolver_test.php` | PASS |
| `pdf_snapshot_test.php` | PASS |
| `preview_contract_test.php` | PASS |
| `quote_preview_contract_test.php` | PASS |
| `whmcs_invoice_template_repair_test.php` | PASS |
| `whmcs_pdf_surface_audit_test.php` | PASS |
| `render_modern_*_fixtures.php` | SKIP (need TCPDF path args — not CI unit tests) |

Legacy PDF branch `fix/pdf-http-status-init-poison`: handoff + repair contracts PASS.

## Still Mac / operator-owned

1. `bash ./scripts/publish-to-github.sh` → create `securiace-dev/securiace-whmcs-theme`
2. Open `~/securiace-whmcs-theme` in Cursor desktop
3. Merge PR #15 when ready
4. WHMCS staging/prod theme deploy (`README.md` install steps)
5. Authenticated browser PDF acceptance

## Cloud cannot

- Write files to `/Users/kritananda`
- Create org repos (`Resource not accessible by integration`)
- Bridge to macOS Keychain / `yashodhank` `gh` session
