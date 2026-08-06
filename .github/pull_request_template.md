## What

Describe the scoped change and the affected invoice, quote, addon, or operations
surface.

## Why

Explain the problem, risk, or maintenance need this addresses.

## Verification

- [ ] Narrow dependency-free tests passed.
- [ ] Affected TCPDF fixtures passed, or the reason they are not applicable is documented.
- [ ] `git diff --check` passed.
- [ ] Staged content was reviewed for secrets and production issuer/payment values.

## Deployment and rollback

State whether deployment is required. If it is, list the artifacts, live checks,
backup/rollback procedure, and any data/schema step without including secrets.

## Living handoff

Handoff-Impact: updated

<!--
Keep "updated" only when docs/HANDOFF.md changes in this PR.
Otherwise replace the line with:
Handoff-Impact: none - <specific reason no handoff update is required>
-->

- [ ] `docs/HANDOFF.md` was updated when behavior, compatibility, configuration,
      schema, deployment, rollback, legal policy, or operating procedure changed.
- [ ] Blockers and the exact next action are documented, or there are none.
