# Agent notes for the WHMCS PDF suite

This repository contains WHMCS invoice and quote PDF templates, dependency-free
PHP contract tests, TCPDF rendering fixtures, and static browser previews. It is
not a long-running application. Treat `README.md` and
`.github/workflows/validate.yml` as the command and compatibility authorities.

## Safety boundaries

- Never access, modify, remove, or inspect any `License.php` file.
- Do not use ET server or ET client tooling.
- Do not send real invoice or quote data to third-party services from tests.
- Do not pipe downloaded scripts into a shell. Inspect repository-owned scripts
  before executing them.
- Keep provider credentials out of templates, fixtures, logs, commits, and
  command arguments.

## Runtime and dependencies

- CI covers PHP 7.4, 8.1, 8.2, and 8.3. Keep templates compatible with the
  complete supported matrix.
- `gd` is required only for fixture artwork; production templates do not depend
  on it.
- Node is used only to syntax-check the preview JavaScript.
- TCPDF is intentionally not vendored and there is no root Composer project.
  Install a clean test dependency in a temporary directory:

  ```bash
  tcpdf_dir="$(mktemp -d)"
  composer require --working-dir="$tcpdf_dir" --no-interaction --no-progress tecnickcom/tcpdf:^6.7
  tcpdf_file="$tcpdf_dir/vendor/tecnickcom/tcpdf/tcpdf.php"
  ```

Do not reuse a production WHMCS tree as the test dependency.

## Verification

- Lint the source list maintained by `.github/workflows/validate.yml`.
- Run every dependency-free `tests/*_test.php` file directly with PHP.
- Exercise all PDF paths:

  ```bash
  php tests/render_modern_invoice_fixtures.php "$tcpdf_file" "$(mktemp -d)" modern
  php tests/render_modern_invoice_fixtures.php "$tcpdf_file" "$(mktemp -d)" legacy
  php tests/render_modern_quote_fixtures.php "$tcpdf_file" "$(mktemp -d)"
  ```

- Check previews with `node --check preview/app.js` and
  `node --check quote-preview/app.js`.
- Run `git diff --check` before committing.

The invoice renderer accepts `modern` and `legacy` modes. Quote rendering has no
mode argument. The fixtures verify PDF signatures, page behavior, and guarded
presentation contracts; they do not prove native WHMCS download or email paths.

## Pull-request contracts

Production-facing changes must either update `docs/HANDOFF.md` and declare
`Handoff-Impact: updated` in the PR body, or provide the exact
`Handoff-Impact: none - <reason>` exemption required by CI. Keep stacked PRs
targeted at their immediate parent until the parent merges, then retarget or
restack according to the repository workflow.

Theme-transfer background is in [`docs/THEME-CLONE.md`](docs/THEME-CLONE.md).
Use reviewed local Git operations for any transfer; do not use a remote
curl-to-shell bootstrap.

## Gates and conventions (added by continuity pass)

`docs/HANDOFF.md` stays the long operator handoff; `docs/STATE.md` is the short current-state file. Docs-only PRs declare `Handoff-Impact: none - <reason>`. Addon version: `'version'` in `modules/addons/securiace_pdf_profile/securiace_pdf_profile.php` (`1.0.0`); a change must also update the contract markers in `docs/HANDOFF.md` (checked by `tests/handoff_contract_test.php`). No CHANGELOG exists; do not invent one.

```bash
for t in tests/*_test.php; do php "$t" || break; done
node --check preview/app.js && node --check quote-preview/app.js
bash scripts/check-continuity.sh
```

Public repo: no issuer, customer, bank, UPI, tax values or secrets. Branch `feat|fix|docs|chore/<scope>` from `origin/main`; PR against `main`. This desk may merge module PRs after review; leave `whmcs-prod-new` PRs for WHMCS-Prod; never commit directly to `main`.

## Continuity (tool-agnostic)

This repo follows the desk continuity standard (`CONTINUITY-STANDARD.md` in desk-os). Claude Code, Codex, agy, OpenCode, Cursor and any future tool start here.

- **Entry point:** this file (`AGENTS.md`). `CLAUDE.md`, `GEMINI.md` and `.cursor/rules/agents.mdc` only point here.
- **Session state:** `docs/STATE.md` — current version, what is in flight, next steps, last-session summary. Rewrite it at the end of every session (IST timestamps).
- **Decisions:** `docs/decisions/` (ADR files). Add one when the owner or an architecture choice is made. Do not rewrite old ADRs.
- **Agreement gate:** `bash scripts/check-continuity.sh` must pass before push (`docs/continuity.conf`). It fails if the version, CHANGELOG and STATE disagree.
- **Checkpoints:** small commits; push the feature or WIP branch before you stop; leave no uncommitted work in the worktree; never switch or dirty the user's primary checkout. Use a new worktree from `origin/<default-branch>`.
- **Desk checklists:** `SESSION-START.md` and `SESSION-END.md` in desk-os (`/workspace/whmcs-modules/desk-os/` or `~/Projects/whmcs-modules/desk-os/`).
- Enable hooks in each clone or worktree: `git config core.hooksPath .githooks`.

### Hard rules (fleet)

- No secrets in chat or commits. Never print the live admin folder name (write `ADMIN_PATH`). Never circumvent ionCube. Never touch the WHMCS core licence.
- Production is read-only for this desk. No live deploy. `whmcs-prod-new` merges belong to WHMCS-Prod; deploys belong to CntbOps after Mr. Y's own pick.
- Local checks only; no paid GitHub Actions. Use `gh-account` (unset `GIT_CONFIG_*` first). Repos stay private unless the owner says otherwise.
