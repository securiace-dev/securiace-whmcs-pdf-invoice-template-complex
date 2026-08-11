# Cloud Agent GitHub auth (macOS / local vs cloud sandbox)

Cloud agents run in an isolated Linux VM. That VM authenticates to GitHub as
the **Cursor GitHub App integration** (`gh auth status` shows account `cursor`,
token prefix `ghs_*`). That token is scoped to repos the app can access and
**cannot** perform org-admin actions such as `gh repo create` in
`securiace-dev` (HTTP 403: `Resource not accessible by integration`).

There is **no bridge** from the cloud VM to macOS Keychain or your personal
`gh auth login` session. `CURSOR_AGENT_SOCKET` (`/run/cursor/api.sock`) mints
OIDC workload tokens only — not GitHub credentials.

## Choose a path

| Need | Recommended path |
| --- | --- |
| Use your Mac's existing `gh` / git auth for all GitHub writes | **My Machines** (below) |
| Stay on Cursor-hosted cloud VM but create org repos / elevated scopes | **Runtime secret** `GH_TOKEN` (PAT) in Cloud Agents dashboard |
| One-time publish of this repo before My Machines is set up | **Host publish script** (below) |

## Option A — My Machines (use macOS GitHub auth)

[My Machines](https://cursor.com/docs/cloud-agent/self-hosted-guides/my-machines)
runs the agent loop in Cursor's cloud but executes **terminal, git, and file
edits on your Mac**. Commands use credentials already on that machine (Keychain,
`gh auth login`, SSH keys).

### One-time setup on macOS

```bash
# 1. Install Cursor CLI
curl https://cursor.com/install -fsS | bash

# 2. Sign in (browser)
agent login

# 3. Confirm GitHub auth on the Mac (not inside a cloud agent terminal)
gh auth status
git config --global credential.helper '!gh auth git-credential'   # optional HTTPS helper

# 4. Clone or open this repo, then start a named worker
cd /path/to/securiace-whmcs-theme
./scripts/setup-my-machines-worker.sh
```

Or manually:

```bash
agent worker start --name "kritananda-mac" --worker-dir "$(pwd)"
```

Keep the worker process running while agents use it.

### Run agents on your Mac

1. [cursor.com/agents](https://cursor.com/agents) → environment dropdown → pick your machine.
2. GitHub comment: `@cursoragent worker=kritananda-mac publish securiace-whmcs-theme`
3. API: `"env": { "type": "machine", "name": "kritananda-mac" }`

The worker's registered repo must match the trigger repo (git remote in the
directory where you started the worker).

### Preflight

```bash
agent worker start --debug
```

Checks auth, repo labels, and whether Cursor can route to your worker.

## Option B — Runtime secret (cloud VM + PAT)

When you must stay on Cursor-hosted VMs but need scopes the integration token
lacks:

1. Create a fine-grained or classic PAT with the scopes your org allows (e.g.
   `repo`, and org repo creation if policy permits).
2. Cloud Agents dashboard → **Secrets** → add `GH_TOKEN` (or `GITHUB_TOKEN`).
3. Restart the agent. `gh` and git HTTPS in the VM prefer that env var.

Do not commit tokens. Do not put secrets in `.cursor/environment.json`.

## Option C — Host publish (one-shot, no My Machines yet)

Artifacts from cloud runs:

- `/opt/cursor/artifacts/securiace-whmcs-theme-git.tgz`
- `/opt/cursor/artifacts/securiace-whmcs-theme.bundle`
- `/opt/cursor/artifacts/publish-securiace-whmcs-theme.sh`

On macOS (Terminal.app / iTerm, **not** a cloud agent shell):

```bash
mkdir -p ~/securiace-whmcs-theme && tar -xzf /path/to/securiace-whmcs-theme-git.tgz -C ~
cd ~/securiace-whmcs-theme
./scripts/publish-to-github.sh
```

Or from a bundle:

```bash
git clone /path/to/securiace-whmcs-theme.bundle ~/securiace-whmcs-theme
cd ~/securiace-whmcs-theme
./scripts/publish-to-github.sh
```

## Agent rules (mandatory)

1. **Do not** debug cloud sandbox 403s for org repo create — wrong environment.
2. **Do not** assume `CURSOR_AGENT_SOCKET` can reach macOS or GitHub.
3. If `gh auth status` shows account `cursor` and token `ghs_*`, you are in the
   cloud sandbox unless `GH_TOKEN` was injected via dashboard secrets.
4. For org writes, either switch to **My Machines** or run the **host publish**
   script and report the result.
5. After My Machines is active, start the worker from this repo checkout so
   GitHub triggers route correctly.

## References

- [My Machines](https://cursor.com/docs/cloud-agent/self-hosted-guides/my-machines.md)
- [Choose where Cloud Agents run](https://cursor.com/docs/cloud-agent/self-hosted-guides/choose-runtime.md)
- [Cloud Agent security (GitHub App model)](https://cursor.com/docs/cloud-agent/security.md)
- [OIDC / CURSOR_AGENT_SOCKET](https://cursor.com/docs/cloud-agent/identity.md)
