# RESUME — how a new CLI starts here

1. Read `AGENTS.md` at the repo root. Pointers: `CLAUDE.md` (`@AGENTS.md`), `GEMINI.md`, `.cursor/rules/agents.mdc`. Do not replace a product `AGENTS.md` with a generic template.
2. Read `docs/handoff/STATE.md`. Keep `docs/STATE.md` identical (`scripts/check-continuity.sh` reads it, if present).
3. Do the **Next** action in STATE. If another lane is in flight, leave it alone.
4. Work in a new worktree of `origin/main`. Do not switch the user's primary checkout. Unset `GIT_CONFIG_*` and use `gh-account` for fetch/push. No secrets, no ionCube circumvention, write `ADMIN_PATH`, no live deploy. `whmcs-prod-new` merges belong to WHMCS-Prod.
5. Before you stop: rewrite both STATE files, add a decision if one was made, run `bash scripts/check-continuity.sh` when that script exists, commit, and push the branch (`gh-account git-exec yashodhank <path> -- push origin HEAD:branch`). Leave no uncommitted work.
6. Desk checklists: `~/Projects/whmcs-modules/desk-os/SESSION-START.md` and `SESSION-END.md` (box: `/workspace/whmcs-modules/desk-os/`). Convention: `plans/repo-continuity.md`.

Public repo. The product copy in prod has moved on inside whmcs-prod-new; this repo may be stale. Keep docs/HANDOFF.md if present.
