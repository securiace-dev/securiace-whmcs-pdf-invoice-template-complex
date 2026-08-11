# Agent notes — LOCAL macOS ONLY

**Stop using the Cursor cloud VM for this project.** Cloud agents authenticate
as GitHub integration `cursor` (`ghs_*`) and cannot create org repos or deploy
to WHMCS.

## Where to work

| Environment | Use for |
| --- | --- |
| **Cursor desktop on Mac** | All implementation, GitHub, tests, PRs |
| **My Machines worker** (optional) | Cloud agent loop with Mac terminal/git |
| Cloud VM | **Do not use** — export branch is read-only bootstrap source |

## First run on Mac

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex/export/securiace-whmcs-theme/scripts/local-bootstrap.sh)"
```

Then open the install dir in Cursor: `cursor ~/securiace-whmcs-theme`

Full checklist: [docs/LOCAL-HANDOFF.md](docs/LOCAL-HANDOFF.md)

## Rules

- Run shell scripts with **`bash ./scripts/...`** (nushell cannot execute them directly).
- Do not retry cloud sandbox `gh repo create` 403s.
- `gh auth status` must show your personal account (e.g. `yashodhank`), not `cursor`.
