# Upgrade-safe PDF theme operations

## Purpose

The repository packages its invoice and quote PDF overrides as the minimal
`securiace` child theme. This keeps custom files outside WHMCS-owned default
theme directories while allowing every unmodified client-area template and
asset to inherit from `twenty-one`.

Do not overwrite `templates/twenty-one/invoicepdf.tpl` or
`templates/twenty-one/quotepdf.tpl`. Do not edit WHMCS core or vendor files.

## Package contract

`templates/securiace/` contains only:

- `theme.yaml`, declaring `twenty-one` as the parent;
- `invoicepdf.tpl`, identical to the canonical `invoicepdf-modern.tpl`; and
- `quotepdf.tpl`, identical to the canonical `quotepdf-modern.tpl`.

CI fails if either packaged template drifts from its canonical source or if an
unreviewed file enters the child theme.

## Staging installation

1. Record hashes of the active system theme, both active PDF templates, shared
   helpers, protected configuration, and addon version/schema.
2. Back up the database and the current `templates` directory.
3. Copy the repository's `templates/securiace` directory to
   `WHMCS_ROOT/templates/securiace` without changing `templates/twenty-one`.
4. Deploy the shared helpers, protected configuration, addon, and optional
   artwork using their existing documented locations.
5. In Configuration > System Settings > General Settings, select
   **Securiace PDF Documents** as the System Theme.
6. Clear the WHMCS template cache.
7. Run the acceptance matrix below before production activation.

The `?systpl=securiace` preview parameter may be used for ordinary client-area
theme review, but authenticated PDF routes must still be exercised directly.

## Required acceptance matrix

- Admin invoice PDF download returns HTTP 200 and `application/pdf`.
- Client invoice PDF download returns HTTP 200 and `application/pdf`.
- Invoice email contains a readable PDF attachment.
- Admin and client quote downloads return readable PDFs.
- Quote email contains a readable PDF attachment.
- Admin invoice batch export remains readable and preserves per-invoice pages.
- One paid, unpaid, overdue, partial, refunded, cancelled, proforma, and
  multi-page fixture satisfies the established content contract.
- Optional helper, snapshot, artwork, and QR failures degrade to a PDF rather
  than an HTTP 5xx.

## WHMCS upgrade gate

Child themes protect custom files from being overwritten, but overridden files
do not automatically inherit upstream changes to the same parent files.
Therefore every WHMCS upgrade must:

1. Be installed in the licensed staging environment first.
2. Run `scripts/audit-whmcs-pdf-surface.php` against the target WHMCS tree.
3. Compare the target release's stock `invoicepdf.tpl` and `quotepdf.tpl`
   contracts with the child overrides.
4. Review WHMCS release notes for PDF, invoice, quote, theme, Smarty, TCPDF, PHP,
   and hook changes.
5. Run the repository CI and real authenticated acceptance matrix.
6. Record target WHMCS, PHP, TCPDF, template hashes, results, and rollback path.
7. Promote the same reviewed artifact to production; do not rebuild it there.

An unexplained template-surface change, PHP warning promoted to an exception,
HTTP 5xx, incorrect MIME type, blank PDF, or missing attachment blocks release.

## Rollback

Select the prior System Theme in General Settings and clear the template cache.
Because the parent files were never modified, switching back to `twenty-one`
restores the stock rendering path. Restore helpers or the addon only when their
deployment was part of the failed release, using the recorded hash-guarded
backup. Preserve snapshot data unless a separately reviewed data rollback is
required.
