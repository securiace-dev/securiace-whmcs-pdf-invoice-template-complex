# Agent notes (legacy PDF repo)

## GitHub auth

Cloud agents use the Cursor GitHub App integration (`cursor` / `ghs_*`), not your
macOS Keychain. Org repo create and other elevated writes fail with 403 in the
cloud sandbox.

**Use macOS local auth via My Machines**, or a dashboard `GH_TOKEN` secret, or
host-side publish — see the canonical guide in the unified theme repo:

`docs/CLOUD-AGENT-GITHUB-AUTH.md` in
[securiace-whmcs-theme](https://github.com/securiace-dev/securiace-whmcs-theme)
(also under `/home/ubuntu/securiace-whmcs-theme` on cloud VMs).

Do not retry sandbox `gh repo create` for `securiace-dev/*`.
