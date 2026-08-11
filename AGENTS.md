# Agent notes for securiace-whmcs-theme

## GitHub auth (mandatory)

- **Do not** use sandboxed Cursor cloud `gh` / integration tokens to create
  repositories, open org-admin PRs, or debug GitHub 403s from the cloud VM.
- On this workstation the **host macOS** `git` and `gh` are already authorized
  (Keychain). Prefer that host channel for:
  - `gh repo create`
  - `gh pr create` / merge when the cloud token is permission-scoped
  - any GitHub write that fails in the cloud sandbox with
    `Resource not accessible by integration`
- If the agent is running in cloud-only isolation with no host bridge, stop
  retrying sandbox auth. Prepare artifacts and run (or clearly schedule) the
  host publish command instead of investigating the wrong environment.

### Publish this repo from host macOS

```bash
# From a host shell with authenticated gh (not cloud sandbox):
cd /path/to/securiace-whmcs-theme   # or extract the artifact tarball/bundle
./scripts/publish-to-github.sh
```
