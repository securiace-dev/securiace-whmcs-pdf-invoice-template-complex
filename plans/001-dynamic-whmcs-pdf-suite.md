# Dynamic WHMCS PDF suite modernization

Baseline commit: `4bc077a`

## Objective

Replace issuer-specific runtime fallbacks and raw Pay To rendering with a
shared, PHP 7.4-compatible profile resolver. Preserve the current visual design,
WHMCS 8.x/9.x contracts, batch behavior, and legacy rollback template while
making invoices and quotes safe across incomplete and changing configuration.

Screenshots and operator-supplied identity/payment values are illustrative
inputs only. Production values must remain in WHMCS settings or protected server
configuration and must never be committed to this public repository.

## Architectural decision

Add a pure helper beside the modern PDF templates. It accepts standard WHMCS
template values, explicitly collected WHMCS settings, optional document
snapshots, and protected configuration. It performs no direct database queries
and emits no output. Both modern templates consume the same normalized profile.

The profile contains:

- issuer name, address lines, support email, mobile, website, and logo metadata;
- PAN, MSME/Udyam, GSTIN, and their display labels;
- validated UPI metadata and atomic, optionally currency-scoped bank accounts;
- policy values for jurisdiction, TDS, late fees, and document titles;
- source provenance, conflicts, and masked-safe validation codes.

Critical bank fields from different sources must never be stitched into a new
account. A complete Pay To account block wins; otherwise use one complete
protected fallback block or omit bank instructions.

## Source precedence

1. Immutable document snapshot, when present and valid.
2. Standard WHMCS template variables and `WHMCS\Config\Setting` values.
3. Structured values parsed from Invoice Pay To text.
4. Protected configuration compatibility fallbacks.
5. Omit an optional value or use a neutral non-branded label.

Precedence is field-aware: WHMCS Company Name remains the issuer heading,
WHMCS Tax Code remains the authoritative GST registration, and Pay To provides
address/contact/payment fields where explicitly labelled.

## Parser contract

- Support labelled and unlabelled layouts, arbitrary order, CRLF, blank lines,
  case differences, and section headings such as `[Bank Account]`.
- Recognise conservative aliases for address, email/helpdesk, phone/mobile, PAN,
  MSME/Udyam, GSTIN, UPI/VPA, beneficiary, account number, IFSC/routing code,
  branch, account type, bank name, and currencies.
- Split labelled lines only at the first colon; decode entities; remove markup,
  control characters, and dangerous length.
- Preserve unknown inputs only as non-published diagnostics.
- Treat duplicate critical payment fields as a conflict and fail closed.
- Never include sensitive values in diagnostics or logs.

## Rendering policies

| Context | Issuer and registrations | Bank | UPI/QR | Extra invoice content |
| --- | --- | --- | --- | --- |
| Unpaid/overdue INR proforma | Yes | Matching complete account | Yes | Payment terms/notes allowed |
| Unpaid non-INR | Yes | Matching complete account | No | Payment terms/notes allowed |
| Paid/final | Yes | No | No | Settlement and transaction evidence |
| Refunded/cancelled/draft/zero balance | Yes | No | No | Status-specific facts only |
| Quote | Yes | No | No | Proposal, validity, quote terms only |
| Admin batch | Yes | No | No | Accounting facts and references only |

## Document lifecycle

- Outstanding requests are `Proforma Invoice` with `PI/<WHMCS invoice ID>`.
- The default current non-GST final title is `Invoice`; `Commercial Invoice` is
  a controlled policy option for clients/use cases that require that wording.
- After an explicit GST effective date and valid registration snapshot, final
  taxable documents become `Tax Invoice` or an accountant-approved export title.
- WHMCS sequential paid numbering remains authoritative. Proforma references do
  not consume that sequence, final numbers are never reused, and the original
  proforma reference remains visible on the final document.
- GST serials must be consecutive, unique in the Indian financial year, limited
  to 16 characters, and use only permitted letters, numerals, hyphen, or slash.
  Do not change production numbering without verifying WHMCS format/reset
  behavior and preserving the current next value.

## Work packages

### 1. Shared resolver

- Add the pure resolver and dependency-free unit tests.
- Add fictional fixtures for current sectioned, legacy unlabelled, missing,
  reordered, conflicting, malformed, long, and multi-currency inputs.
- Add the helper and tests to PHP 7.4–8.3 CI lint/test gates.

### 2. Invoice integration

- Replace raw `$companyaddress` and issuer-specific fallback rendering.
- Render contacts and PAN/MSME/GSTIN chips from the profile.
- Keep compact date normalization and add long-date overlap assertions.
- Preserve and strengthen the red overdue badge, balance panel, due date, and
  days-overdue copy.
- Gate bank and UPI by document status, positive balance, confirmed currency,
  account validity, and batch profile.
- Resolve actual WHMCS late-fee settings or reviewed neutral wording instead of
  an unconditional annual-interest statement.

### 3. Quote and batch profiles

- Use the shared identity profile without exposing payment sections from Pay To.
- Assert quotes never include bank, UPI, QR, invoice notes, renewals,
  transactions, settlement, verification, or authorization content.
- Preserve the lean accounting batch profile.

### 4. Lifecycle and numbering

- Centralize policy-driven titles and proforma/final references.
- Keep default non-GST service invoices aligned with the researched decision;
  expose commercial wording only as an explicit policy.
- Add a future GST activation date/registration gate and 16-character preflight.
- Version verification identifiers before changing their immutable input.

### 5. Snapshots and diagnostics

- Store schema-versioned seller identity/registration snapshots when a document
  becomes final. Do not snapshot payment data into paid PDFs.
- Preserve pre- and post-GST identities without rewriting history.
- Provide a masked diagnostic that reports source selection, missing fields,
  conflicts, and validation codes only.

## Verification gates

- `php -l` for every PHP/template source on PHP 7.4, 8.1, 8.2, and 8.3 in CI.
- Dependency-free resolver, contract, preview, surface-audit, and repair tests.
- TCPDF invoice fixtures for lifecycle, currencies, long dates, A4/Letter,
  multi-page, invalid configuration, and two-document batch output.
- TCPDF quote fixtures for registered/guest recipients, long proposals, and
  explicit payment-detail non-disclosure.
- `node --check` for both browser-preview scripts.
- `git diff --check` and a staged secret/value review before every commit.

## Production deployment

Promote only green `main` content to the existing invoice, quote, and legacy
release streams. Back up active files, deploy the modern templates and helper by
atomic rename, preserve ownership/mode, keep protected configuration server-side,
and verify downloaded plus emailed paid, unpaid, overdue, non-INR, quote, and
batch PDFs. Roll back by restoring the timestamped files; never patch WHMCS core
or vendor code.
