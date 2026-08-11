# Upgrade-safe Securiace theme operations

## Purpose

The repository packages the Securiace client-area skin and PDF overrides as the
`securiace` child theme. Custom files stay outside WHMCS-owned `twenty-one`
directories while unmodified templates inherit from the parent.

Do not overwrite `templates/twenty-one/*`. Do not edit WHMCS core or vendor
files.

## Package contract

`templates/securiace/` contains:

- `theme.yaml` — name **Securiace**, parent `twenty-one`
- `css/custom.css` — semantic dark/light brand skin
- `js/custom.js` and `js/theme-mode.js` — mode resolution + toggle
- `img/` — on-light / on-dark / icon SVG marks
- `invoicepdf.tpl` / `quotepdf.tpl` — byte-identical to canonical modern sources

Also deploy (outside the theme tree):

- `hooks/securiace-theme-mode.php` → `WHMCS_ROOT/includes/hooks/`
- Shared PDF helpers, addon, protected config, and `assets/img/logo.png`

CI fails if packaged PDF templates drift from canonical sources or if unreviewed
top-level theme entries appear.

## Dark / light mode

- One System Theme; mode is not a second theme.
- Default: dark when no stored preference and no useful OS preference path.
- Persistence: `localStorage` key `securiace-theme-mode`.
- PDF generation always uses the print-hybrid navy header + ice body surface.

## Staging installation

1. Record hashes of the active system theme, PDF templates, helpers, protected
   configuration, and addon version/schema.
2. Back up the database and `templates/` directory.
3. Copy `templates/securiace` to `WHMCS_ROOT/templates/securiace`.
4. Copy the theme-mode hook, helpers, addon, and brand logo as documented in the
   README.
5. Select **Securiace** as the System Theme; clear template cache.
6. Run the acceptance matrix before production activation.

## Required acceptance matrix

- Client area loads in dark and light; toggle persists across refresh.
- Admin invoice PDF download returns HTTP 200 and `application/pdf`.
- Client invoice PDF download returns HTTP 200 and `application/pdf`.
- Invoice email contains a readable PDF attachment.
- Admin and client quote downloads return readable PDFs.
- Quote email contains a readable PDF attachment.
- Admin invoice batch export remains readable and preserves per-invoice pages.
- Optional helper/snapshot/artwork/QR failures degrade to a PDF, not HTTP 5xx.

## WHMCS upgrade gate

1. Install the target WHMCS release in licensed staging first.
2. Run `scripts/audit-whmcs-pdf-surface.php` against the target tree.
3. Compare stock parent `invoicepdf.tpl` / `quotepdf.tpl` contracts with child
   overrides.
4. Review release notes for PDF, theme, Smarty, TCPDF, PHP, and hook changes.
5. Re-run CI and the authenticated acceptance matrix in both color modes.
6. Record target WHMCS/PHP/TCPDF, hashes, results, and rollback path.
7. Promote the same reviewed artifact; do not rebuild on production.

## Rollback

Select the prior System Theme and clear the template cache. Restore helpers or
the theme-mode hook only when they were part of the failed release, using the
dated hash-guarded backup.
