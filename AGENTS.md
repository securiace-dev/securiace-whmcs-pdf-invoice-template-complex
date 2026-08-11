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
