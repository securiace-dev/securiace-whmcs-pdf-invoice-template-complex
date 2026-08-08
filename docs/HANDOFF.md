# Living handoff

This is the canonical maintenance handoff for the WHMCS PDF suite. It records
the operating contract and the evidence a future maintainer must refresh. It
does not duplicate production issuer, customer, bank, UPI, tax, credential, or
server values.

The handoff is intentionally evergreen: current runtime health comes from the
redacted **Securiace PDF Profile Snapshots** addon screen, release state comes
from Git, and deployment history comes from the operator audit ledger. A copied
screenshot or a value pasted into this repository is never a source of truth.

## Contract markers

- Handoff contract version: `1`
- Addon module version: `1.0.0`
- Snapshot schema version: `1`
- Shared profile helper SHA-256: `75879d938f2dc3f100835e3a2826a35c166d3002d5b006d65b4a84e8e5b0db61`
- Supported WHMCS line: `8.x and 9.x`
- Supported PHP line: `7.4 through 8.3`

The CI handoff contract test compares the addon and snapshot markers above with
their source definitions. A version or schema change must update this document
in the same PR.

## Invoice download incident contract

The August 2026 invoice-download incident established that a green synthetic
render is insufficient when a newly deployed path depends on production rows or
runtime helpers. Invoice and quote templates must contain failures from the
protected config, shared profile helper, snapshot validator, optional artwork,
and TCPDF barcode renderer. A failure in any optional integration must produce a
safe fallback PDF plus a redacted diagnostic code, never an HTTP 5xx.

Every snapshot-affecting deployment must render at least one controlled final
invoice after a snapshot row exists. Deployment evidence must record hashes for
the active invoice template, quote template, profile helper, snapshot validator,
and addon version/schema. Addon activation or a zero-row health screen does not
exercise snapshot consumption.

## Current environment handoff

The repository now ships the approved PDF overrides in the minimal
`templates/securiace` child theme. Production remains on its recorded active
theme until an operator installs, validates, and selects the child theme using
`docs/UPGRADE-SAFE-THEME-OPERATIONS.md`; repository packaging alone is not
evidence of production activation.

At this handoff closure, production has been verified with:

- `securiace-pdf-profile.php` copied into the WHMCS `includes` area and readable
  by the WHMCS runtime;
- the deployed helper matching the repository SHA-256 contract marker above
  after an atomic refresh, with its previous copy retained at
  `/var/backups/securiace-whmcs-pdf/20260806-handoff-helper-refresh-62777cd/`;
- **Securiace PDF Profile Snapshots** activated through WHMCS Addon Modules;
- the addon version recorded and its invoice hook registered;
- issuer snapshot storage available at the expected schema version;
- the protected configuration available;
- redacted diagnostics reporting no source warnings or conflicts;
- the active `templates/twenty-one/quotepdf.tpl` matching quote-fix commit
  `21273df891b0cff34bacc4b719ad0c01f7fde40b` at SHA-256
  `8be7a5b40a06ac17c57a035d6f53eff0ff2a0aed9355ace61027886caaee317b`;
- the prior quote template and hash-guarded rollback retained at
  `/var/backups/securiace-whmcs-pdf/20260806T091534Z-quote-21273df/`; and
- and a production-native render of the affected zero-date quote returning a valid
  one-page PDF under the WHMCS site user, with the fallback date and redesigned
  hierarchy visually verified before all temporary client-data artifacts were
  removed.

This section is current environment context, not a substitute for live checks.
Future deployers must refresh it when any listed state changes. Do not add live
issuer/payment identifiers or snapshot counts here.

## Sources of truth

| Concern | Canonical source | Never use as authority |
| --- | --- | --- |
| Invoice behavior | `invoicepdf-modern.tpl` and its fixtures | Screenshot or generated sample alone |
| Quote behavior | `quotepdf-modern.tpl` and its fixtures | Invoice assumptions copied into quotes |
| Issuer resolution | `securiace-pdf-profile.php` | Hardcoded company values in templates |
| Historical issuer identity | Valid immutable snapshot selected by `securiace-pdf-snapshot.php` | Current settings applied retroactively |
| Runtime issuer and payment values | WHMCS settings, labelled Pay To text, protected server configuration | Repository examples or handoff prose |
| Runtime health | Redacted addon diagnostics in WHMCS Admin | A previously captured health response |
| Document lifecycle | `docs/INVOICE-NAMING-AND-NUMBERING.md` | Informal invoice-title convention |
| Snapshot operations | `docs/PDF-SNAPSHOT-OPERATIONS.md` | Direct database edits |
| Supported PDF surfaces | `scripts/audit-whmcs-pdf-surface.php` | Memory of an older WHMCS release |
| Upgrade-safe theme package | `templates/securiace/` and `tests/child_theme_package_contract_test.php` | Files copied into a WHMCS-owned default theme |
| Integrated release | Green `main` and maintained `release/*` refs | Unreviewed feature branch |
| Deployment and rollback evidence | Sanitized operator audit ledger and dated server backup | Mutable image/tag or verbal confirmation |

## Stable behavior that must not regress

- Issuer identity, address, contacts, registrations, bank accounts, and UPI are
  resolved dynamically with source provenance and fail-closed validation.
- Current non-GST final documents use `Invoice`. Proformas use their separate
  `PI/<WHMCS invoice ID>` display identity. Commercial wording is opt-in, and
  GST tax titles require explicit registration, valid GSTIN, and effective date.
- WHMCS owns final sequential invoice numbers. The template validates but never
  silently rewrites the stored number.
- UPI/QR is available only for a positive, payable unpaid/overdue INR invoice.
- Paid, refunded, cancelled, draft, zero-balance, quote, and admin-batch outputs
  do not expose UPI/QR. Quotes and batch PDFs remain free of invoice-specific
  payment instructions and unrelated additions.
- Quote issue/validity dates fail closed for zero, malformed, missing, or
  chronologically invalid values. Supported numeric dates use the configured
  DMY/MDY order and render with an unambiguous abbreviated month. An unusable
  stored issue date falls back to a labelled generation date plus a diagnostic.
- Quote subjects never truncate silently. Long line-item detail uses the full
  commercial-table width and can continue across pages without repeating
  monetary values; wrapped continuation titles expand their measured header
  instead of overlapping detail, and zero-only discount columns are omitted.
- Quote issuer registrations share one compact dynamic block, acceptance points
  to the WHMCS client area or authorised written confirmation, and every page
  footer carries the WHMCS-owned quote number.
- Long and localized dates cannot overlap. Overdue invoices remain visibly
  distinct even though WHMCS keeps the underlying status as `Unpaid`.
- PAN and Udyam/MSME render when valid. GSTIN remains hidden before GST mode is
  explicitly active.
- Snapshot payloads contain immutable issuer/document identity only. They never
  contain bank, UPI, client, transaction, credential, or verification-secret
  values.
- Invalid config/helper/snapshot results and optional QR/artwork failures degrade
  to safe text/identity output and retain only redacted diagnostic codes.

## Update triggers

Update this handoff in the same PR whenever any of these changes:

1. Invoice, quote, batch, status, currency, payment, layout, or fallback behavior.
2. Resolver precedence, labels, validation, conflict handling, or diagnostics.
3. Addon version, hook, schema, capture event, payload, retention, or recovery.
4. Protected configuration keys or WHMCS settings consumed by the suite.
5. WHMCS, PHP, TCPDF, paper-size, font, or theme compatibility.
6. Proforma, commercial, GST, numbering, legal-copy, or jurisdiction policy.
7. Test matrix, CI gate, release branch, deployment, rollback, or backup process.
8. A production incident or discovery that changes the safe operating procedure.

If a production-facing file changes but this document does not, the PR must
carry `Handoff-Impact: none - <specific reason>`. A generic “not applicable” is
not sufficient. CI enforces this declaration for the protected runtime surface.

## Required handoff payload

Every implementation or deployment handoff must state:

- what changed and which behavior or risk it affects;
- the exact commit/release ref reviewed or deployed;
- tests and live checks run, including skipped checks and why;
- runtime state changed, or an explicit statement that no deployment occurred;
- backup and rollback location or procedure, without secrets;
- redacted diagnostics outcome: module, hook, version, schema, warnings, and
  conflicts—not issuer/payment identifiers;
- what remains blocked, why, and the exact next command or user action;
- whether this handoff was updated or why no update was required.

Never claim completion from a root-page HTTP success alone. A PDF deployment
requires WHMCS-native render evidence for the affected document contexts.

## Pull-request maintenance

Use `.github/pull_request_template.md` for every PR. Keep exactly one
`Handoff-Impact` declaration and explain migration/deployment effects.

Before requesting review:

1. Confirm the branch started from current `main` and contains no unrelated work.
2. Run the dependency-free tests and the affected TCPDF fixtures.
3. Run `php tests/handoff_contract_test.php`.
4. Run `git diff --check` and inspect staged content for production values or
   secrets.
5. Update this file when an update trigger applies.
6. Push, open a PR, and merge only after all supported PHP jobs are green.
7. Promote release branches only from green integrated content.

## Deployment handoff

For an invoice/quote/helper/addon deployment:

1. Record the local commit and hashes of only the artifacts being promoted.
2. Back up active runtime files to a dated, access-restricted server directory.
3. Upload to a temporary directory, verify hashes and PHP syntax, then install
   atomically with the existing owner and mode.
4. Preserve the protected configuration. Compare its hash before/after without
   printing its values.
5. Verify through WHMCS:
   - paid invoice;
   - current unpaid INR invoice;
   - overdue INR invoice;
   - non-INR invoice when payment/currency behavior changed;
   - quote;
   - admin batch when batch behavior changed;
   - emailed attachments when the mail path changed.
6. Check the redacted addon diagnostics for active module, registered hook,
   expected version/schema, available table/helper/config, and zero warnings or
   conflicts.
7. Retain the rollback backup and remove temporary staging/test artifacts.
8. Append the sanitized outcome to the operator audit ledger.

The live snapshot count is expected to change and must never be frozen in this
document. Verify capture by creating or finalizing a controlled test invoice
only when that state change is explicitly authorized.

## Rollback handoff

- Rendering rollback restores the dated `invoicepdf.tpl` and/or `quotepdf.tpl`
  backup and verifies a WHMCS-native PDF render.
- Helper rollback must be compatible with both active templates; never restore
  one shared helper without impact-checking invoice and quote consumers.
- Addon deactivation retains historical snapshots. Do not drop or rewrite the
  snapshot table as part of an ordinary rollback.
- Protected issuer/payment configuration is a separate artifact and is not
  replaced by repository examples.
- Record the reason, restored artifact hashes, validation, and remaining risk in
  the audit ledger.

## Future GST transition

Before enabling GST mode:

1. Obtain accounting/legal approval for registration, effective date, titles,
   numbering format, place-of-supply fields, tax display, and export wording.
2. Back up WHMCS invoice settings and record the current next final number
   without exposing client or credential data.
3. Configure a valid GSTIN and reviewed effective date; keep activation false
   until all prerequisites are present.
4. Render pre-effective, effective-date, post-effective, paid, proforma,
   cancelled/refunded, domestic, and reviewed export fixtures.
5. Confirm pre-GST snapshots remain unchanged and the first GST final document
   receives the intended title/number without reusing a prior sequence.
6. Update lifecycle documentation, this handoff, tests, config example, addon
   version/schema if required, and the deployment audit together.

## Staleness safeguards

- CI fails when this document's addon/schema markers diverge from source.
- CI requires an explicit handoff-impact declaration when production-facing
  files change without `docs/HANDOFF.md`.
- The PR template requires validation, deployment, rollback, and handoff notes.
- Runtime values and transient health counts are read live, never copied here.
- A WHMCS upgrade must run the PDF-surface audit before compatibility is claimed.
- A production incident must update code/tests, operating documentation, and the
  audit ledger in the same recovery stream.

## Next-maintainer start

```bash
git status --short --branch
git pull origin main
php tests/handoff_contract_test.php
php tests/addon_module_contract_test.php
php tests/pdf_profile_resolver_test.php
php tests/pdf_snapshot_test.php
```

Then read the redacted WHMCS addon health page and the latest sanitized operator
audit entry. If either disagrees with this contract, treat the handoff as stale,
stop deployment, and reconcile source, tests, documentation, and runtime state.
