# Agent notes for securiace-whmcs-theme

## GitHub auth (mandatory)

Cloud VM `gh` uses the Cursor GitHub App (`cursor`, `ghs_*`). It **cannot**
create org repos or perform other integration-blocked writes (403:
`Resource not accessible by integration`). There is **no** socket bridge to
macOS Keychain.

Full guide: [docs/CLOUD-AGENT-GITHUB-AUTH.md](docs/CLOUD-AGENT-GITHUB-AUTH.md)

### Quick paths

| Goal | Action |
| --- | --- |
| Use Mac Keychain / personal `gh` | My Machines: `./scripts/setup-my-machines-worker.sh` on macOS, then pick worker in cursor.com/agents |
| One-shot publish from Mac | `./scripts/publish-to-github.sh` (or artifact tarball in `/opt/cursor/artifacts/`) |
| Cloud-only with elevated scopes | Add `GH_TOKEN` PAT in Cloud Agents dashboard Secrets |

### Rules

- Do **not** debug cloud sandbox 403s for `gh repo create`.
- If `gh auth status` shows account `cursor`, you are in the wrong environment
  for org writes unless `GH_TOKEN` was set via dashboard secrets.
- Prefer host publish or My Machines over retrying integration-token auth.
