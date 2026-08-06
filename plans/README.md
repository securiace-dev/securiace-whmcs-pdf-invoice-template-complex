# WHMCS PDF modernization plan

Baseline: `4bc077a`

This directory records the approved implementation sequence for dynamic issuer,
payment, lifecycle, and historical-identity handling in the WHMCS PDF suite.

| Order | Plan | Status | Depends on |
| --- | --- | --- | --- |
| 1 | [Dynamic PDF suite modernization](001-dynamic-whmcs-pdf-suite.md) | In progress | — |

## Delivery stack

1. `feat/pdf-issuer-resolver` — shared resolver and parser tests.
2. `feat/pdf-invoice-integration` — invoice identity, date, overdue, payment,
   and late-fee integration.
3. `feat/pdf-quote-batch-profiles` — quote and batch isolation.
4. `feat/pdf-document-lifecycle` — proforma/final/tax naming and numbering.
5. `feat/pdf-issuer-snapshots` — immutable seller snapshots and diagnostics.

Every branch is reviewed as a dependent PR against its immediate parent. Merge
bottom-up. If GitHub squash- or rebase-merges a parent, restack all descendants
with recovery refs, unchanged-tree verification, and force-with-lease before the
next merge.
