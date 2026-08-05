# Securiace WHMCS PDF Document Templates

This repository contains a maintained WHMCS TCPDF document suite:

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

- Paid invoices emphasize settlement, hide the UPI payment action, retain bank
  details as remittance context, and show signature/stamp assets when present.
- Customer invoices in exact WHMCS `Unpaid` state emphasize the actual balance
  and render an amount-bound, invoice-referenced UPI QR only when the model
  confirms INR, the balance is positive, and a protected UPI ID is configured.
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
- Quotes intentionally contain no UPI action, bank-remittance call to action,
  payment receipt, transaction history, invoice verification, or paid balance.
- Customer notes are omitted so internal commentary is not leaked; essential
  client-facing scope and terms belong in the proposal body.
- A4 and Letter output, long proposals, many line items, taxes, discounts,
  guest recipients, and missing optional data are covered by TCPDF fixtures.

## Browser preview

The dependency-free paid/unpaid invoice review prototype is at
[`preview/index.html`](preview/index.html). Open it directly or choose a state:

```text
preview/index.html?state=paid
preview/index.html?state=unpaid
```

The matching quote review prototype is at
[`quote-preview/index.html`](quote-preview/index.html). It deliberately shows
validity rather than a workflow-stage badge, matching the runtime quote template.

The screenshot audit, design decisions, source findings, and edge-case matrix
are in [`docs/INVOICE-UX-AUDIT.md`](docs/INVOICE-UX-AUDIT.md).

## Install the modern invoice template

1. Back up the active system-theme template, usually:

   ```text
   WHMCS_ROOT/templates/twenty-one/invoicepdf.tpl
   ```

2. Copy `invoicepdf-modern.tpl` into that directory as `invoicepdf.tpl`.
   WHMCS selects this exact filename; the separate repository name exists to
   preserve the rollback template.

3. Copy `config/securiace-invoice-config.example.php` to the protected runtime
   path below and replace every example value:

   ```text
   WHMCS_ROOT/includes/securiace-invoice-config.php
   ```

4. Provide the verification secret through the
   `SECURIACE_INVOICE_VERIFY_SECRET` environment variable. Do not commit bank
   account values, the secret, signatures, or production client data.

5. Place optional visual assets in WHMCS:

   ```text
   WHMCS_ROOT/assets/img/logo.png
   WHMCS_ROOT/assets/img/sign.png
   WHMCS_ROOT/assets/img/stamp.png
   ```

   The logo may also be `logo.jpg` or `logo.jpeg`. Missing assets degrade safely:
   the company name replaces the logo, and absent signature/stamp images do not
   stop PDF generation.

6. Generate and download one paid and one unpaid test invoice in staging. Also
   send each as an email attachment before production activation.

To roll back, restore the backed-up `invoicepdf.tpl`. No database or WHMCS core
file changes are required.

## Install the modern quote template

1. Back up the active system-theme file, usually
   `WHMCS_ROOT/templates/twenty-one/quotepdf.tpl`.
2. Copy `quotepdf-modern.tpl` to that directory as `quotepdf.tpl`.
3. Generate a quote for a registered client and a guest recipient. Download each
   PDF, email one through WHMCS, and convert an accepted test quote to an invoice.
4. Confirm that proposal formatting, line-item discounts, one/two taxes, totals,
   and validity match the WHMCS admin record; confirm internal customer notes are
   absent from the PDF.

Rollback is file-only: restore the backed-up `quotepdf.tpl`. The custom template
does not require a database migration, hook, core edit, or custom font install.

## Protected configuration

The public example exposes this contract:

- company email, phone, PAN, and MSME registration;
- bank account details and UPI ID;
- HMAC verification secret;
- ambiguous numeric-date order (`DMY` by default, or `MDY`);
- electronic-record label, jurisdiction, overdue-interest copy, and TDS note.

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
It asserts payment-action gating, stable verification IDs, DMY renewal parsing,
reconciliation behavior, PDF file headers, and page-count stability.

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
