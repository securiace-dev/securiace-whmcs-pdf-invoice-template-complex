# Securiace WHMCS Theme

Unified upgrade-safe WHMCS **child theme**, dual dark/light brand system, and
modern invoice/quote PDF suite for Securiace Technologies.

This repository is the canonical home for client-area branding and PDF document
templates. The older `securiace-whmcs-pdf-invoice-template-complex` project is
retained only as historical reference.

## What you get

- `templates/securiace` child theme (parent: `twenty-one`)
  - Dual dark/light mode via semantic CSS tokens + toggle
  - `invoicepdf.tpl` / `quotepdf.tpl` packaged from the modern canonical sources
- Brand kit in `assets/brand/` (tokens + optimized logos)
- Shared issuer helpers, snapshot addon, browser previews, and CI contracts

## Brand tokens

| Token | Hex |
| --- | --- |
| Midnight Navy | `#0B1324` |
| Electric Cyan | `#00E6FF` |
| Teal Blue | `#008DBA` |
| Ice White | `#F4F7FB` |

See [`docs/BRAND-SYSTEM.md`](docs/BRAND-SYSTEM.md) for dark/light rules and PDF
hybrid surface policy.

## Local setup (macOS — not cloud VM)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex/export/securiace-whmcs-theme/scripts/local-bootstrap.sh)"
```

Creates `securiace-dev/securiace-whmcs-theme`, clones this export, runs tests.
Remaining deploy steps: [`docs/LOCAL-HANDOFF.md`](docs/LOCAL-HANDOFF.md).

## Install (staging → production)

1. Back up the WHMCS database and `templates/` directory. Do **not** overwrite
   `templates/twenty-one`.
2. Copy `templates/securiace/` to `WHMCS_ROOT/templates/securiace/`.
3. Copy `hooks/securiace-theme-mode.php` to
   `WHMCS_ROOT/includes/hooks/securiace-theme-mode.php`.
4. Copy `securiace-pdf-profile.php` and `securiace-pdf-snapshot.php` to
   `WHMCS_ROOT/includes/`.
5. Copy `assets/brand/logo.png` to `WHMCS_ROOT/assets/img/logo.png` (optional
   `@2x` if you add one).
6. Install `modules/addons/securiace_pdf_profile/` and activate **Securiace PDF
   Profile Snapshots** when issuer snapshots are required.
7. Copy `config/securiace-invoice-config.example.php` to the protected runtime
   path and replace every example value — never commit production secrets.
8. In General Settings, select **Securiace** as the System Theme and clear the
   template cache.
9. Acceptance:
   - Client area readable in **dark** and **light** (toggle persists)
   - Admin/client invoice + quote PDF downloads return HTTP 200 `application/pdf`
   - Email attachments and batch export when those paths changed

Rollback: switch System Theme back to the previous theme and clear template
cache. Parent `twenty-one` files remain untouched.

Ops detail: [`docs/UPGRADE-SAFE-THEME-OPERATIONS.md`](docs/UPGRADE-SAFE-THEME-OPERATIONS.md).
Living handoff: [`docs/HANDOFF.md`](docs/HANDOFF.md).

## Local verification

```bash
php tests/child_theme_package_contract_test.php
php tests/modern_invoice_design_contract_test.php
php tests/modern_quote_template_contract_test.php
php tests/preview_contract_test.php
php tests/quote_preview_contract_test.php
php tests/handoff_contract_test.php
```

Open `preview/index.html` and `quote-preview/index.html` for visual review. Use
the toolbar mode toggle; the document surface stays print-hybrid.

## License

See [LICENSE](LICENSE).
