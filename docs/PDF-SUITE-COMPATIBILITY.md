# WHMCS PDF Suite Compatibility and Deployment Record

Date: 2026-08-05
Source baseline: local licensed WHMCS 8.12.1 and WHMCS 9.0 TCPDF runtime

## Controlled PDF surface

The WHMCS 8.12.1 source tree contains two system-theme PDF templates:

| Template | Generator | Download/email consumers | Custom implementation |
| --- | --- | --- | --- |
| `invoicepdf.tpl` | `WHMCS\Invoice::pdfInvoicePage()` | client/admin download, invoice email attachment, admin batch PDF | `invoicepdf-modern.tpl` or repaired legacy `invoicepdf.tpl` |
| `quotepdf.tpl` | `genQuotePDF()` | client/admin quote download and quote email attachment | `quotepdf-modern.tpl` |

The inventory is reproducible with:

```bash
php scripts/audit-whmcs-pdf-surface.php ~/Projects/WHMCS-8.12.1
```

The command inventories both theme files and literal `pdfAddPage()` targets. An
unknown target fails the gate. No separate theme-controlled order, ticket,
receipt, credit-note, or batch template exists in this source baseline: those
flows either use invoice/quote generation or are not generated through a PDF
theme template.

## Source-contract findings

### Invoice

- `includes/invoicefunctions.php` creates the invoice PDF and delegates page
  composition to `WHMCS\Invoice`.
- `vendor/whmcs/whmcs-foundation/lib/Invoice.php` extracts the invoice variables
  and adds `invoicepdf.tpl`.
- WHMCS 8 supplies formatted totals and transaction `transid`; the invoice model
  remains the reliable currency and proforma source.
- WHMCS 9 additionally supplies `invoiceamount`, `amountpaid`, `invoiceQrHtml`,
  transaction `referenceId`/`typeLabel`, and credit/debit-note flags.
- `admin/csvdownload.php` reuses one TCPDF object for multiple invoice pages.
  Therefore footer stamping must be relative to the current invoice's start and
  end pages, not global page 1 through `getNumPages()`.
- WHMCS line-item `amount` is already the line total. It must not be multiplied by
  an inferred quantity.

### Quote

- `includes/quotefunctions.php::genQuotePDF()` supplies recipient data, subject,
  proposal, customer notes, tax levels, totals, and line items. Customer notes
  are deliberately omitted from the client PDF; client-facing terms must be
  placed in the governed proposal body.
- Quote line items contain real `qty`, raw `unitprice`, percentage `discount`, and
  formatted line `total`; the renderer uses each for its documented purpose.
  Zero-only discounts do not consume a column, long item detail spans the full
  table width, wrapped continuation titles receive a measured header, and
  continuation pages do not duplicate monetary values.
- Guest quotes have `userid = 0` and recipient fields from the quote record rather
  than a WHMCS client profile.
- Proposal content passes through WHMCS decoding. The template removes executable,
  embedded, remote-image, form, and attribute content before rendering a small
  rich-text allow-list.
- In the first `sendQuotePDF()` flow, WHMCS generates the PDF attachment before it
  updates the stage to Delivered. The custom template therefore displays the
  valid-until date, which is stable at generation time, and omits stage entirely.
- The renderer normalizes supported WHMCS date formats, rejects zero/impossible
  numeric dates, detects validity dates before the issue date, and never exports
  a raw `00/00/0000` sentinel. If the stored issue date is unusable, the PDF
  labels its factual generation date and records a source diagnostic. It
  preserves non-numeric localized output when a strict parse is not possible.
- The subject, issuer registrations, acceptance instructions, and quote footer
  are content-driven and remain traceable without invoice-only payment content.
- Quote-to-invoice conversion serializes quote quantity/rate/discount context into
  the new invoice description while assigning the calculated quote line total as
  the invoice item amount. The invoice renderer preserves that total unchanged.

## Rendering and compatibility decisions

- Both modern templates are self-contained system-theme files. They do not patch
  WHMCS core/vendor code and do not require Composer packages in production.
- They honor WHMCS's configured `TCPDFFont`. No custom font is bundled because
  `WHMCS\PDF::SetFont()` controls font selection globally.
- Rounded cards use TCPDF `RoundedRect()`, present with the same signature in the
  locally tested WHMCS 8.12.1 and 9.0 bundles. A rectangular fallback remains for
  the shared card helper.
- Page geometry is derived from the active PDF object and is tested on A4 and
  Letter paper.
- Helpers are template-scoped closures rather than global functions, avoiding
  redeclaration failures during batch output.
- Currency-dependent invoice payment actions fail closed if currency cannot be
  confirmed. The template no longer assumes INR.
- The WHMCS 9 core invoice QR payload is outside template payment controls and is
  suppressed. The only QR rendered is the amount-bound UPI payload for an
  outstanding INR invoice or proforma, including a derived overdue state, with
  positive balance and a configured protected UPI ID.
- Paid PDFs omit remittance/support cards and keep settlement, authorization,
  renewals, and wrapped transaction evidence together. Long localized dates are
  normalized to compact display dates before entering fixed PDF geometry.
- Seller PAN, MSME, and future tax registrations render as dedicated registration
  tags matching the browser design rather than being buried in address text.
- Standard admin `csvdownload.php?type=pdfbatch` output is detected explicitly.
  Its accounting profile keeps invoice identity, parties, line items, totals,
  status, and transaction references while omitting settlement/support cards,
  bank/UPI/QR data, notes, renewals, verification artwork, and authorization
  images.
- Browser previews use fictional data and are review artifacts. Runtime values
  come only from WHMCS and protected server configuration.

## Verification matrix

Automated fixture coverage includes:

- Invoice: paid, unpaid, partial, overdue, refunded, cancelled, collections,
  draft, proforma, zero total, EUR format 2, unknown currency, entity decoding,
  adjustment/reconciliation cases, WHMCS 9 ledger and QR, invalid protected
  configuration, A4/Letter, multi-page, repeated rendering, and two invoices in
  one TCPDF batch.
- Quote: registered and guest recipients, allowed and malicious rich proposal
  markup, entity decoding, quantity, unit price, percentage discount, one/two/no
  tax rows, customer-note suppression, A4/Letter, and a 42-line multi-page
  proposal.
- Runtime: local TCPDF distributions from WHMCS 8.12.1 and WHMCS 9.0.
- Static contracts: invoice/quote browser structure, JavaScript syntax, modern
  visual primitives, quote/invoice semantic separation, repair idempotence, and
  fail-closed PDF surface inventory.

## Standard production deployment

1. Require a green feature PR and promote the reviewed files from `main` to their
   dedicated release branches.
2. Resolve the active WHMCS system theme from production configuration; do not
   assume `twenty-one` if a custom system theme is active.
3. Create timestamped, permission-preserving backups beside both active template
   files.
4. Copy the modern invoice to `invoicepdf.tpl` and modern quote to `quotepdf.tpl`
   through temporary files followed by atomic rename. Preserve the existing owner,
   group, and mode.
5. Do not copy repository example secrets. Keep bank, UPI, registration, and HMAC
   values in `WHMCS_ROOT/includes/securiace-invoice-config.php` and the environment.
6. Clear only WHMCS compiled-template/cache artifacts documented for the running
   version; do not delete broad application or upload directories.
7. Generate and download paid, unpaid, partial, registered-client quote, and guest
   quote PDFs. Email one invoice and one quote through WHMCS and inspect the exact
   received attachments.
8. Exercise quote acceptance/conversion and an admin two-invoice batch export.
9. Verify the application log and PHP error log contain no template warning,
   notice, undefined constant, redeclaration, or TCPDF exception.

Rollback is the reverse atomic rename from the timestamped backups. No database
rollback is needed. Keep the backups until operator acceptance and the next normal
backup cycle.

## Release-branch policy

`release/invoice-legacy`, `release/invoice-modern`, and `release/quote-modern`
represent distributable runtime streams. They are promoted only from reviewed
commits. The licensed stock `quotepdf.tpl` remains a production backup rather than
being published into this repository. This keeps rollback available without
redistributing proprietary WHMCS source.
