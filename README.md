# Securiace WHMCS PDF Document Templates (legacy)

> **Canonical home moved.** New theme, brand, and PDF work lives on branch
> [`securiace-whmcs-theme`](https://github.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex/tree/securiace-whmcs-theme)
> (clone instructions: [`docs/THEME-CLONE.md`](docs/THEME-CLONE.md)).
> After Mac publish, the org repo will be
> `securiace-dev/securiace-whmcs-theme`.

This repository retains the historical WHMCS TCPDF document suite snapshot:

- `invoicepdf.tpl` is the repaired legacy template retained as the rollback
  option. Its PHP 8 undefined-constant and helper-collision failures are fixed
  without redesigning its established layout.
- `invoicepdf-modern.tpl` is the separately named, status-aware redesign for
  WHMCS 8.x and 9.x. It is the recommended candidate for staging and production
  acceptance testing.
- `quotepdf-modern.tpl` applies the same visual system to quotes while using the
  quote-specific recipient, proposal, quantity, unit-price, discount, tax,
  validity, and client-note contract.

The modern template preserves invoice identity, billing parties, line items,
totals, taxes, credits, terms, notes, bank details, UPI, signature/stamp,
renewals, and transactions while changing their hierarchy and behavior to make
paid and payable invoices harder to misread.

## Modern invoice behavior

- Paid invoices emphasize settlement and transaction evidence, omit UPI and
  remittance-instruction cards, and show signature/stamp assets when present.
- Proforma documents use the display reference `PI/<WHMCS invoice ID>` while the
  paid record retains WHMCS's stored sequential final number and links back to
  the original proforma reference.
- Outstanding invoices render an amount-bound, reference-bound UPI QR only when
  the model confirms INR, the balance is positive, and a protected UPI ID is
  configured. This includes an overdue proforma because it remains unpaid.
- The template derives a red Overdue presentation from an outstanding balance
  and a due date earlier than the generation date; it does not expect WHMCS to
  replace its underlying `Unpaid` status.
- Partial payments remain visible even when WHMCS still reports the invoice as
  `Unpaid`.
- Refunded, cancelled, collections, and draft states do not offer a payment QR.
- An empty custom invoice number falls back to `$invoiceid`; it does not silently
  turn the document into a proforma invoice.
- WHMCS item `amount` values remain line totals. Quantity and calculated unit
  rate appear only when an explicit positive `qty` exists.
- The totals panel exposes an `Invoice adjustment` when the supplied subtotal,
  discount, tax, credit, and grand total cannot otherwise be reconciled.
- Paid transaction mismatches are disclosed as a credit or administrative
  adjustment instead of inventing a matching transaction amount.
- Renewal dates use an explicit configurable date order instead of ambiguous
  `strtotime()` parsing.
- Layout dimensions, page breaks, continuation context, and footers derive from
  the active A4 or Letter page.
- WHMCS 9 invoice amount, amount-paid, reference-ID, transaction-type, and
  credit/debit-note fields are normalized without changing WHMCS 8 output. Its
  opaque core QR is suppressed so the controlled UPI payload is the only QR.
- Batch exports stamp only the pages created for the current invoice instead of
  overwriting footers belonging to earlier invoices in the same TCPDF object.
- Admin batch exports use a lean accounting profile: no settlement callout,
  protected bank details, UPI, QR, terms/notes, renewals, verification artwork,
  stamp/signature, or support cards. Invoice facts and transaction references
  remain because they are reconciliation evidence.

## Modern quote behavior

- Quotes use the real WHMCS `qty`, `unitprice`, `discount`, and line `total`
  fields; invoice line-total assumptions are never reused.
- Registered clients and guest recipients both receive complete party details.
- Proposal markup is restricted to a small, attribute-free TCPDF tag set. Script,
  style, form, embedded-media, remote-image, and tracking content is removed.
- The PDF presents the valid-until date instead of the internal stage. WHMCS 8.12
  creates the first emailed attachment before changing the stage to Delivered,
  so printing that stage can produce a stale document.
- Numeric issue/validity dates are normalized to an unambiguous `5 Sep 2026`
  display using the protected `date_order` setting (`DMY` by default). Missing,
  zero, malformed, or chronologically invalid dates fail closed. A missing
  stored issue date is labelled with its factual PDF generation date while a
  non-sensitive diagnostic records that the WHMCS source value needs repair.
- Proposal subjects are rendered in full using an adaptive summary card. Item
  detail spans the table width and continues safely across pages; a discount
  column appears only when at least one line has a non-zero discount.
- Acceptance copy directs the recipient to the WHMCS client area or written
  confirmation from an authorised contact, and every footer carries the quote
  number for detached-page traceability.
- Quotes intentionally contain no UPI action, bank-remittance call to action,
  payment receipt, transaction history, invoice verification, or paid balance.
- Customer notes are omitted so internal commentary is not leaked; essential
  client-facing scope and terms belong in the proposal body.
- The template never rewrites authored commercial or tax terms. For a currently
  non-GST-registered supplier, review the proposal wording before delivery and
  state plainly that GST is not charged because the supplier is not registered
  under GST as of the quote date; do not describe supplier registration as
  pending client confirmation.
- A4 and Letter output, long proposals, many line items, taxes, discounts,
  guest recipients, and missing optional data are covered by TCPDF fixtures.

## Browser preview

The dependency-free paid/unpaid invoice review prototype is at
[`preview/index.html`](preview/index.html). Open it directly or choose a state:

```text
preview/index.html?state=paid
preview/index.html?state=unpaid
preview/index.html?state=overdue
```

The matching quote review prototype is at
[`quote-preview/index.html`](quote-preview/index.html). It deliberately shows
validity rather than a workflow-stage badge, matching the runtime quote template.

The screenshot audit, design decisions, source findings, and edge-case matrix
are in [`docs/INVOICE-UX-AUDIT.md`](docs/INVOICE-UX-AUDIT.md).
The approved current/future-GST document lifecycle, statutory number constraints,
and WHMCS settings are in
[`docs/INVOICE-NAMING-AND-NUMBERING.md`](docs/INVOICE-NAMING-AND-NUMBERING.md).
The evergreen source-of-truth map, update triggers, deployment evidence, rollback
requirements, and next-maintainer checklist are in
[`docs/HANDOFF.md`](docs/HANDOFF.md). Runtime issuer/payment values and transient
health counts are deliberately read live instead of being copied into the
handoff.

## Install the modern invoice template

1. Back up the database and active `templates` directory. Do not overwrite the
   WHMCS-owned `twenty-one` theme.

2. Copy `templates/securiace/` to `WHMCS_ROOT/templates/securiace/`. This
   minimal child theme inherits from `twenty-one` and owns the invoice and quote
   PDF overrides, keeping them outside directories overwritten by WHMCS
   upgrades. Copy `securiace-pdf-profile.php` and
   `securiace-pdf-snapshot.php` to `WHMCS_ROOT/includes/`. The shared helpers
   fail closed if a partial deployment omits them.

3. Copy `config/securiace-invoice-config.example.php` to the protected runtime
   path below and replace every example value:

   ```text
   WHMCS_ROOT/includes/securiace-invoice-config.php
   ```

   Keep `gst_registered` false until registration is effective. Future tax
   titles require `gst_registered=true`, a valid GSTIN in the WHMCS Tax Code
   setting, and an invoice issue date on or after `gst_effective_date`.
   `commercial_invoice_currencies` remains empty unless a reviewed workflow
   explicitly needs that title; foreign currency alone does not change the
   document type.

4. For immutable historical issuer details, copy
   `modules/addons/securiace_pdf_profile/` into `WHMCS_ROOT/modules/addons/` and
   activate **Securiace PDF Profile Snapshots** in WHMCS. Its redacted health
   screen must report the helpers and snapshot table as available. See
   [`docs/PDF-SNAPSHOT-OPERATIONS.md`](docs/PDF-SNAPSHOT-OPERATIONS.md).

5. Provide the verification secret through the
   `SECURIACE_INVOICE_VERIFY_SECRET` environment variable. Do not commit bank
   account values, the secret, signatures, or production client data.

6. Place optional visual assets in WHMCS:

   ```text
   WHMCS_ROOT/assets/img/logo.png
   WHMCS_ROOT/assets/img/sign.png
   WHMCS_ROOT/assets/img/stamp.png
   ```

   The logo may also be `logo.jpg` or `logo.jpeg`. Missing assets degrade safely:
   the company name replaces the logo, and absent signature/stamp images do not
   stop PDF generation.

7. In WHMCS General Settings, select **Securiace PDF Documents** as the System
   Theme and clear the template cache. Generate and download one paid and one
   unpaid test invoice in staging, then send each as an email attachment before
   production activation.

To roll back the rendering layer, select the previous System Theme and clear the
template cache. The parent theme remains untouched. The addon never edits WHMCS
core and retains historical snapshot rows when it is deactivated.

## Install the modern quote template

1. Install and activate the `templates/securiace` child theme as described
   above; its packaged `quotepdf.tpl` is synchronized with
   `quotepdf-modern.tpl` by CI.
2. Ensure `WHMCS_ROOT/includes/securiace-pdf-profile.php` is present. The quote
   consumes only the resolved identity and registration projection; payment
   data is discarded.
3. Generate a quote for a registered client and a guest recipient. Download each
   PDF, email one through WHMCS, and convert an accepted test quote to an invoice.
4. Confirm that proposal formatting, line-item discounts, one/two taxes, totals,
   and validity match the WHMCS admin record; confirm internal customer notes are
   absent from the PDF.

Rollback is a System Theme switch plus template-cache clear. The custom template
does not require a database migration, core edit, or custom font install. See
[`docs/UPGRADE-SAFE-THEME-OPERATIONS.md`](docs/UPGRADE-SAFE-THEME-OPERATIONS.md)
for the staging, upgrade, acceptance, and rollback gates.

## Protected configuration

The public example exposes this contract:

- company email, phone, PAN, and MSME registration;
- bank account details and UPI ID;
- HMAC verification secret;
- ambiguous numeric-date order (`DMY` by default, or `MDY`);
- electronic-record label, jurisdiction, reviewed late-fee copy, and TDS note;
- explicit GST activation date/title gates and opt-in commercial currencies.

The verification ID is a stable keyed integrity identifier over immutable
invoice fields when a secret is configured. It is not a cryptographic PDF
signature and should not be represented as one. The visible IT Act wording is
an electronic-record label, not an automatic legal-compliance certification.
Have tax and legal copy reviewed for the deployed business entity.

## Verification

Repair and regression checks for the existing template:

```bash
php scripts/repair-whmcs-invoice-template.php /absolute/path/invoicepdf.tpl
php tests/whmcs_invoice_template_repair_test.php
```

The repair command creates a timestamped rollback copy beside the target before
atomically replacing it. Its JSON output includes the exact backup path.

Render the modern template against a real WHMCS TCPDF installation:

```bash
output_dir="$(mktemp -d /tmp/securiace-invoice-fixtures.XXXXXX)"
php tests/render_modern_invoice_fixtures.php \
  /absolute/path/to/WHMCS/vendor/tecnickcom/tcpdf/tcpdf.php \
  "$output_dir"
```

The renderer produces paid, unpaid, partial, overdue, refunded, cancelled,
collections, draft, zero-total, proforma, paid-with-adjustment,
unreconciled-total, format-2 EUR, invalid-configuration, and dense multi-page
Letter fixtures.
It asserts payment-action gating, derived overdue state, long localized date
normalization, proforma/final references, seller registrations, stable
verification IDs, DMY renewal parsing, reconciliation behavior, PDF file
headers, and page-count stability.

The fixture renderer requires the PHP GD extension only to create temporary test
artwork. The production template does not require GD for those assets.

Render the quote suite against the same TCPDF installation:

```bash
quote_output_dir="$(mktemp -d /tmp/securiace-quote-fixtures.XXXXXX)"
php tests/render_modern_quote_fixtures.php \
  /absolute/path/to/WHMCS/vendor/tecnickcom/tcpdf/tcpdf.php \
  "$quote_output_dir"
```

Audit a WHMCS source tree for newly added PDF template surfaces:

```bash
php scripts/audit-whmcs-pdf-surface.php /absolute/path/to/WHMCS
```

The audit currently expects `invoicepdf.tpl` and `quotepdf.tpl`. It fails closed
if an upgrade adds another `*pdf.tpl` or explicit `pdfAddPage()` target so that
the new document receives a deliberate compatibility and design decision.

Use the same renderer in `legacy` mode to prove that the repaired rollback
template can generate both paid and unpaid PDFs without the former undefined
constant failure:

```bash
legacy_output_dir="$(mktemp -d /tmp/securiace-legacy-invoices.XXXXXX)"
php tests/render_modern_invoice_fixtures.php \
  /absolute/path/to/WHMCS/vendor/tecnickcom/tcpdf/tcpdf.php \
  "$legacy_output_dir" legacy
```

## Compatibility

- Template target: WHMCS 8.x and 9.x.
- PHP target: 7.4 through 8.3, covering the supported runtime range across those
  WHMCS generations.
- Current local integration gate: the TCPDF distribution bundled with WHMCS
  8.12.1, executed under PHP 8.5.9 as an additional forward-compatibility check.
- Paper: A4 and Letter, using the PDF object's active dimensions.

WHMCS core and vendor files must not be edited. The suite uses only the supported
`invoicepdf.tpl` and `quotepdf.tpl` system-theme customization points and TCPDF
methods available in the bundled renderer. Local source review of WHMCS 8.12.1
found no additional theme-controlled business PDF template.

## Release streams

- `release/invoice-legacy` preserves the repaired rollback invoice.
- `release/invoice-modern` tracks the reviewed modern invoice release.
- `release/quote-modern` tracks the reviewed modern quote release after its
  feature PR is merged.
- `main` remains the integrated, tested source of the complete PDF suite.

Release branches are promoted from a green `main`; they are not used as parallel
development bases. The proprietary WHMCS stock quote template is retained only
on the licensed WHMCS installation as the runtime rollback and is not copied into
this public repository.

## Legacy runtime repair

The original production error was caused by PHP 8 treating bare names such as
`COLOR_DARK_GREY[0]` as undefined constants. The repaired legacy template uses
the corresponding color variables, avoids a global `formatCurrency()` collision,
and removes a trailing output artifact. The repair script is idempotent and its
test remains part of the repository gate.

## Security and privacy

- Keep production configuration under `WHMCS_ROOT/includes`, not in the public
  template repository.
- Use a high-entropy environment secret for authenticated verification IDs.
- The QR is rendered directly into the PDF; no predictable temporary QR file is
  created.
- The template escapes invoice descriptions before passing HTML to TCPDF.
- The quote template strips active/remote markup and all element attributes from
  rich proposal content before passing its small allow-list to TCPDF.
- Never enable debug output containing invoice or client data in customer-facing
  PDFs.

## License

See [`LICENSE`](LICENSE). WHMCS, tax, privacy, and legal obligations remain the
operator's responsibility.
