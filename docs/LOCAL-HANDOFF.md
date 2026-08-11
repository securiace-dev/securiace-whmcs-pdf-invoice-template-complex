# Local handoff — finish on macOS (cloud VM closed)

All theme/PDF work lives in this repository. **Do not continue on the Cursor
cloud VM** for GitHub org writes or deployment — use your Mac with
`yashodhank` GitHub auth.

## One command (macOS Terminal or iTerm)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex/export/securiace-whmcs-theme/scripts/local-bootstrap.sh)"
```

Or, if you already cloned:

```bash
cd ~/securiace-whmcs-theme   # or your install path
bash ./scripts/local-bootstrap.sh
```

Start My Machines worker in the same session:

```bash
SECURIACE_START_WORKER=1 bash ./scripts/local-bootstrap.sh
```

**Nushell:** prefix with `bash` — do not run `.sh` files directly in `nu`.

## What the bootstrap does

1. Clones `export/securiace-whmcs-theme` from the legacy PDF repo (if needed)
2. Creates **`securiace-dev/securiace-whmcs-theme`** with your Mac `gh` auth
3. Pushes `main` to the canonical repo
4. Runs PHP contract tests when `php` is available

## Remaining tasks (local agent / operator)

### A. GitHub (local Cursor)

- [ ] Confirm repo exists: `gh repo view securiace-dev/securiace-whmcs-theme`
- [ ] Open `~/securiace-whmcs-theme` in **Cursor desktop on Mac** (not cloud agent)
- [ ] Merge legacy PR #15 on `securiace-whmcs-pdf-invoice-template-complex`
  (`fix/pdf-http-status-init-poison`) after review — PDF 5xx fix + README cutover

### B. WHMCS staging deploy

Follow `README.md` install steps:

1. Back up DB + `templates/`
2. Copy `templates/securiace/`, hook, helpers, addon, `assets/brand/logo.png`
3. General Settings → System Theme **Securiace** → clear template cache
4. Acceptance: client area dark/light toggle; invoice + quote PDF HTTP 200

Ops: `docs/UPGRADE-SAFE-THEME-OPERATIONS.md`

### C. Production (after staging sign-off)

- Deploy same package to prod (`sat-de-prod01` or current prod host)
- Rollback backup path pattern:
  `/var/backups/securiace-whmcs-pdf/<date>-theme-deploy/`
- Authenticated browser PDF download check (cloud CLI proved HTTP 200; browser still needed)
- Refresh redacted addon health + audit ledger entry

### D. provision20i hook guard (prod)

Ensure duplicate `MAILBOX_FIELD_NAME` hooks stay `defined()`-guarded after WHMCS
module updates (`premium-mailbox/hooks.php`, `mailbox-quota-addon/hooks.php`).

## Cloud VM — do not use for

| Action | Why |
| --- | --- |
| `gh repo create securiace-dev/*` | Integration token 403 |
| Org-admin GitHub writes | Same |
| WHMCS prod SSH from cloud | Operator-owned; use Mac or approved jump host |

## Sources on GitHub until canonical repo exists

| Ref | Purpose |
| --- | --- |
| `securiace-dev/securiace-whmcs-pdf-invoice-template-complex@export/securiace-whmcs-theme` | Full theme export (bootstrap source) |
| `securiace-dev/securiace-whmcs-theme@main` | Canonical home (after bootstrap) |
| `fix/pdf-http-status-init-poison` on legacy repo | PDF HTTP 200 + init-poison fix PR |

## Verify bootstrap succeeded

```bash
gh repo view securiace-dev/securiace-whmcs-theme --web
cd ~/securiace-whmcs-theme && git remote -v && git log --oneline -3
php tests/handoff_contract_test.php
```
