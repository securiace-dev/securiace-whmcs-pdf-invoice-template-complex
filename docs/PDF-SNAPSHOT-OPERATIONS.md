# Immutable issuer snapshots

WHMCS normally builds a PDF from current General Settings. That is correct for
quotes and outstanding proformas, but it can rewrite the seller address,
registration state, and document title when an old paid invoice is downloaded
after a business-profile change.

The optional `securiace_pdf_profile` addon stores a schema-versioned issuer
snapshot when an invoice becomes final:

- `InvoicePaidPreEmail` captures after WHMCS has saved a sequential paid number
  and before the payment-confirmation email attachment is generated.
- `InvoiceCreation` captures a directly issued, non-proforma invoice. The addon
  checks WHMCS's invoice model and skips proformas at this hook.
- One immutable row is retained per invoice. Repeated hooks do not overwrite it.
- Deactivation intentionally preserves the table and historical rows.

These event semantics follow the official
[WHMCS invoice hook reference](https://developers.whmcs.com/hooks-reference/invoices-and-quotes/).
The custom table is created through the addon's activation function, following
the supported [WHMCS addon installation pattern](https://developers.whmcs.com/addon-modules/installation-uninstallation/).

## Data boundary

Snapshots contain only:

- normalized issuer name, address, support contact, mobile, and website;
- validated PAN, Udyam/MSME, and active GSTIN registrations;
- the final document title, GST activation state, issue date, and WHMCS final
  number needed to detect a later mismatch.

Bank accounts, UPI IDs, QR payloads, verification secrets, client details,
invoice items, transaction details, and free-form notes are forbidden. The
reader validates a SHA-256 checksum and rejects unsupported schemas, payment
keys, invalid titles, or malformed identity data before applying a snapshot.

## Installation

1. Copy `securiace-pdf-profile.php` and `securiace-pdf-snapshot.php` to the
   protected `WHMCS_ROOT/includes/` directory.
2. Copy `modules/addons/securiace_pdf_profile/` to the same path under WHMCS.
3. In WHMCS, open Configuration > System Settings > Addon Modules and activate
   **Securiace PDF Profile Snapshots**.
4. Open the module once and confirm the redacted health output reports the
   helper, protected configuration, and snapshot table as available.

The admin health view reports booleans, counts, source names, and validation or
conflict codes. It never prints identifier values, account numbers, UPI IDs,
secrets, or client data.

## Recovery

If the addon is unavailable, current PDFs continue to render from WHMCS settings
and protected fallbacks. If a snapshot is missing, corrupt, or has a final-number
mismatch, the template uses current safe data and exposes only a diagnostic code
to tests/admin tooling. It never changes WHMCS's stored invoice number.
