# Invoice UI/UX and Runtime Audit

Date: 2026-08-05
Scope: the supplied paid and unpaid invoice screenshots, the repaired legacy
`invoicepdf.tpl`, the browser preview, and the implemented
`invoicepdf-modern.tpl`.

## Outcome

The redesign keeps the existing invoice identity, parties, item details, totals,
payment terms, bank details, UPI path, signature/stamp, renewal
information, and transaction history. It changes their hierarchy and makes
payment content status-aware. The approved browser direction is now implemented
as a second, separately named WHMCS PDF template; the repaired legacy template
remains the rollback option.

The sample HTML uses fictional customer, payment, tax, and bank data because
this repository is public. Production assets and values must continue to come
from WHMCS configuration or protected deployment assets.

## Screenshot audit

| Severity | Finding | Customer/operational impact | Redesign response |
| --- | --- | --- | --- |
| Critical | Paid line items and transaction history show zero while Grand Total and Amount Paid show a non-zero value. | The document contradicts itself and cannot be reconciled by a customer or accountant. | Use one source of truth for line totals, invoice total, balance, and transaction total; surface a reconciliation failure during testing instead of silently inventing an amount paid. |
| Critical | A paid invoice includes a prominent `UPI - Scan to Pay` action. | Creates a duplicate-payment risk. | Remove remittance instructions from paid output and keep payment receipt plus transaction evidence. Show the amount-bound QR only for a payable INR invoice/proforma, including an overdue document that remains unpaid. |
| High | The paid-state panel was presented as an authenticated record even though the template did not apply or verify a PDF signature. | Customers could mistake payment-state artwork for cryptographic proof. | Limit the panel to payment facts. Reserve footer space for a separately applied and independently verified post-render signature line. |
| High | Paid and unpaid invoices use unrelated accent systems (lime green versus purple) and every totals row is a saturated banner. | Status colors compete with amounts and make the document look inconsistent across its lifecycle. | Keep aubergine as the brand accent; reserve green/amber/red for semantic status and balance information. |
| High | A single renewal and one transaction are forced onto a sparse second page. | Wastes paper and separates supporting evidence from the financial summary. | Fit short renewal and transaction records on page one; paginate only when content length requires it. |
| High | Fixed-height party boxes leave excess whitespace for short addresses and risk clipping long addresses. | Poor scanning in common cases and possible data loss in edge cases. | Use content-driven panels with minimum heights and flow layout. |
| Medium | The title, status, section bars, totals, and transaction header all compete at headline scale. | No clear reading path. | Use one document title, one compact status, and progressively smaller section labels. |
| Medium | Most supporting copy is 5–7pt in the PDF and several financial rows use white text on bright colors. | Weak print readability and accessibility. | Target an effective 8–10pt print body size, neutral surfaces, and WCAG-aware contrast. |
| Medium | Dates mix long weekday prose with compact numeric ranges. | Slower scanning and ambiguous numeric dates for international clients. | Use `5 Aug 2026` for document dates and ISO-like service ranges where space is constrained. |
| Medium | The unpaid terms state a date later than the header due date. | The customer receives contradictory payment instructions. | Derive both displays from the same WHMCS due-date value. |
| Low | `Billed To` and `Billed By` have equal visual weight despite different tasks. | Slows recognition of the recipient. | Keep both, but emphasize the customer identity and condense seller compliance details. |

## Source-code audit

### Runtime and data integrity

1. Bare `COLOR_*` and `STATUS_*` array references are PHP 8 undefined constants.
   The first branch commit replaces them with variables, isolates the currency
   helper name, removes a trailing output artifact, and adds an idempotent test.
2. WHMCS treats `$invoiceitems[*]['amount']` as the rendered line total. The
   current template reinterprets it as a unit rate and multiplies it by a custom
   `qty` value a second time. The redesigned PDF must either show Description +
   Amount (the WHMCS default) or calculate `rate = line total / quantity` only
   when a reliable quantity exists.
3. Formatted currency values are passed to `floatval()` for balance handling.
   Values beginning with a currency symbol can become zero, and objects can
   produce warnings or misleading values. Every financial input must go through
   one locale-aware normalizer.
4. Paid status forces `amount_paid = final_total` and `balance = 0` without
   reconciling transactions. Status, balance, credit, and transaction totals
   must be displayed as provided by WHMCS; inconsistent source data should be
   logged and visibly testable, not overwritten in the view.
5. Transaction history is limited to `paid`, `partial`, and `refunded`, while a
   partially paid invoice commonly remains `Unpaid`. Any real transaction must
   remain visible regardless of that allow-list.
6. The payment terms initialize from `$duedate` and then add 15 days, producing
   the screenshot's contradictory date. The actual due date must not be mutated.
7. Empty `$invoicenum` is treated as proof of a proforma invoice. WHMCS documents
   that this custom number is only set when proforma or sequential numbering is
   enabled, so `$invoiceid` must remain a valid official invoice number fallback.
8. A template-computed identifier cannot authenticate the final PDF bytes.
   Remove locally invented verification claims. A signing service must receive
   the completed PDF, and only an explicit ready presentation DTO may prepare
   approved seal copy for bytes that pass independent verification before use.
9. Bank, UPI, and company details are declared in a configuration block and then
   repeated as literals later. The second template must consume each value from a
   single configuration source.
10. QR images use a predictable temporary filename and do not guarantee cleanup
    after every failure. Prefer TCPDF's in-document barcode rendering, or use a
    unique temporary file with `finally` cleanup.
11. Layout assumes a 210mm page despite WHMCS exposing configurable PDF paper
    size. Derive usable width and page-break thresholds from the active PDF.
12. Functions declared in a template can collide during batch rendering or with
    add-ons. Use uniquely prefixed helpers and `function_exists()` guards.

### Information and interaction rules

| Content | Payable invoice | Paid invoice |
| --- | --- | --- |
| Status | `Unpaid` or `Overdue`, with due date and positive balance | `Paid`, with paid date and zero balance |
| Primary financial emphasis | Balance due | Payment received |
| UPI QR | Visible only for payable INR invoices/proformas; amount-bound and reference-bound | Hidden to prevent duplicate payment |
| Bank details | Visible as an alternate payment route | Hidden because settlement evidence replaces remittance instructions |
| Signature status | No template-generated claim | No template-generated claim; post-render sealing is a separate delivery concern |
| Signature/stamp | Omitted unless business policy explicitly signs proforma/unpaid documents | Visible using protected production assets |
| Transactions | Empty state or partial-payment records | Full payment records |
| Renewals | Service period remains in the line item | Upcoming renewal summary is shown when known |

## Design contract for the preview

- Intent: a credible tax invoice/receipt that can be understood in under a minute.
- Hierarchy: brand and document identity, status/amount, parties, services,
  reconciliation, payment/supporting records, compliance footer.
- Palette: deep aubergine brand accent; warm neutral paper and ink; green, amber,
  and red only for semantic state.
- Depth: borders and pale tonal surfaces; no decorative shadows in print.
- Typography: system sans-serif with tabular numerals; effective print body size
  of at least 8pt.
- Spacing: 4/8/12/16/24px screen rhythm mapped to compact millimetre spacing in
  print.
- Accessibility: status is always stated in text, values are not distinguished by
  color alone, tables use semantic headers, and controls expose pressed state.

## WHMCS implementation constraints

- `invoicepdf.tpl` is the supported PDF customization point and WHMCS generates
  it with TCPDF. Optional `invoicepdfheader.tpl` and `invoicepdffooter.tpl` files
  can repeat context on multi-page invoices.
- WHMCS supplies `$invoiceid`, optional `$invoicenum`, `$datecreated`, `$duedate`,
  and `$datepaid`; the custom number must not be assumed to exist.
- WHMCS 9.0 requires PHP 8.2 or 8.3, so undefined-constant compatibility and
  collision-safe helpers are mandatory rather than optional hardening.
- Client-data snapshotting should be enabled in WHMCS when historic invoices must
  retain the original recipient identity after a client profile changes.

Primary references:

- [WHMCS: Custom PDF Invoices](https://docs.whmcs.com/8-12/billing-and-invoicing/custom-pdf-invoices/)
- [WHMCS 9.0: Invoice settings](https://docs.whmcs.com/9-0/system/general-settings/general-settings-invoices/)
- [WHMCS 9.0: System requirements](https://docs.whmcs.com/9-0/installation-guide/system-requirements/)

## Acceptance matrix for the WHMCS phase

- Paid, unpaid, overdue, refunded, cancelled, collections, draft, and proforma.
- Partial payment while status is still unpaid.
- Zero total, credit-only settlement, overpayment, refund, and no transactions.
- One and many line items, long descriptions, optional quantity, discounts, late
  fees, gateway fees, one/two taxes, tax-exempt clients, and no tax.
- INR and non-INR currencies; zero-, two-, and three-decimal currencies; all four
  WHMCS number formats.
- Long names/addresses, custom invoice fields, Unicode and right-to-left text.
- Missing logo/signature/stamp, invalid image, absent QR class, and concurrent PDF
  generation.
- A4 and Letter paper; one-page and multi-page output with repeated context.
- Browser download and email attachment for at least one paid and one unpaid
  production-safe test invoice.

## Implementation and renderer findings

The browser prototype remains a design-review artifact; the runtime
implementation is `invoicepdf-modern.tpl`. Its protected settings contract is
documented in `config/securiace-invoice-config.example.php`.

Real TCPDF rendering found and resolved additional issues that were not visible
in the browser prototype:

1. Drawing a footer near the page edge while automatic page breaks were active
   could append a blank page. On multi-page documents, TCPDF's `setPage()` also
   restores the original break setting, so the template now disables it after
   every page switch before drawing repeated context.
2. Short notes could move onto a nearly empty second page. They now share the
   payment-terms panel when short enough; long notes retain a dedicated section.
3. `strtotime()` interpreted an Indian `04/09/2026` service-period end date as
   9 April. Renewal parsing now uses strict `DMY` or `MDY` configuration and
   rejects invalid dates.
4. Mixed invoice items could inherit an invented quantity of `1` when only one
   row supplied `qty`. Missing quantities and rates now render as em dashes.
5. A zero subtotal with a non-zero grand total—the contradiction visible in the
   supplied unpaid screenshot—had no explanatory row. The totals panel now
   exposes the supplied difference as `Invoice adjustment` rather than hiding
   it.
6. A paid record with an inconsistent positive balance could still expose UPI.
   All paid states now block payment actions regardless of balance corruption.
7. A keyed HMAC was previously presented as an authenticated invoice record and
   paired with an IT Act label. Both were removed because neither proves the
   final PDF signature or legal status. Paid-state artwork now shows payment
   facts only; the separately gated Securiace panel is allowed only in the
   fail-closed completed-PDF sealing path.
8. WHMCS 8 and 9 do not pass the same transaction contract. The renderer now
   normalizes WHMCS 8 `transid` and WHMCS 9 `referenceId`, `typeLabel`, and
   credit/debit-note fields before presentation.
9. WHMCS admin batch export reuses one TCPDF object. Footer stamping is now scoped
   to the current invoice's page range, preventing a later invoice from rewriting
   earlier footer context.
10. Currency and proforma state now come from the invoice model when available.
    Unknown currency no longer defaults to INR, and therefore cannot expose a UPI
    action accidentally.
11. The PDF drawing layer now mirrors the approved preview with native rounded
    cards, a rounded commercial table, receipt-integrated authorization assets,
    quiet transaction/renewal records, and a painted paper background.
12. Admin batch PDFs now use a lean accounting profile. They retain financial and
    transaction evidence but omit bank/UPI/QR data, notes, renewals, proof
    artwork, settlement callouts, and authorization images.

The integration renderer covers paid, unpaid, partial, overdue, refunded,
cancelled, collections, draft, zero-total, proforma, paid-with-adjustment,
unreconciled-total, format-2 EUR, invalid-configuration, and 28-line Letter
invoices. Standard fixtures render on one page; the dense Letter fixture renders
on three pages with repeated identity, table headers, and stable `Page X of Y`
footers. The tests use the TCPDF package bundled with local WHMCS 8.12.1 and were
also run under PHP 8.5.9 without template notices or warnings.

The browser preview's final accessibility pass adds a keyboard skip link,
visible focus and hover states, URL-backed state switching, semantic transaction
table markup, explicit QR dimensions, long-content wrapping, touch behavior,
and balanced headings. The print document continues to communicate status in
text rather than color alone.

The repaired legacy template is also exercised through TCPDF with paid and
unpaid fixtures. Both produce valid PDF files without the former
`Undefined constant "COLOR_DARK_GREY"` runtime failure; the paid legacy layout
remains two pages and the unpaid layout one page as a rollback-only baseline.

## Production acceptance boundary

The repository implementation is locally rendered against WHMCS 8.12.1 and 9.0
TCPDF. Production activation remains gated on a green reviewed PR, release-branch
promotion, protected configuration/assets, and paid/unpaid/partial download plus
email-attachment checks inside the target WHMCS instance. No production secret or
customer data belongs in this repository. Quote and full-suite findings are in
`docs/PDF-SUITE-COMPATIBILITY.md`.
