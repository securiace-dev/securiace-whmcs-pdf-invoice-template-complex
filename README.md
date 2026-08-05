# Securiace WHMCS PDF Invoice Templates

This repository contains two WHMCS TCPDF invoice templates:

- `invoicepdf.tpl` is the repaired legacy template retained as the rollback
  option. Its PHP 8 undefined-constant and helper-collision failures are fixed
  without redesigning its established layout.
- `invoicepdf-modern.tpl` is the separately named, status-aware redesign for
  WHMCS 8.x and 9.x. It is the recommended candidate for staging and production
  acceptance testing.

The modern template preserves invoice identity, billing parties, line items,
totals, taxes, credits, terms, notes, bank details, UPI, signature/stamp,
renewals, and transactions while changing their hierarchy and behavior to make
paid and payable invoices harder to misread.

## Modern template behavior

- Paid invoices emphasize settlement, hide the UPI payment action, retain bank
  details as remittance context, and show signature/stamp assets when present.
- Payable invoices emphasize the actual WHMCS balance and render an amount-bound,
  invoice-referenced UPI QR only for INR invoices with a positive balance.
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

## Browser preview

The dependency-free paid/unpaid review prototype is at
[`preview/index.html`](preview/index.html). Open it directly or choose a state:

```text
preview/index.html?state=paid
preview/index.html?state=unpaid
```

The screenshot audit, design decisions, source findings, and edge-case matrix
are in [`docs/INVOICE-UX-AUDIT.md`](docs/INVOICE-UX-AUDIT.md).

## Install the modern template

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

WHMCS core and vendor files must not be edited. The modern template uses only
the supported `invoicepdf.tpl` customization point and TCPDF methods available
in the bundled renderer.

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
- Never enable debug output containing invoice or client data in customer-facing
  PDFs.

## License

See [`LICENSE`](LICENSE). WHMCS, tax, privacy, and legal obligations remain the
operator's responsibility.
