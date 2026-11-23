# ADR-0001: AGENTS.md is the cross-tool source of truth

- **Date:** 2026-11-23 IST
- **Status:** accepted
- **Deciders:** Mr. Y (t152u) / WHMCS-Modules desk

## Context

Work was drifting between Claude Code, Codex, agy, OpenCode/DeepSeek and Cursor, each reading its own file.

## Decision

`AGENTS.md` at the repo root is the only source of agent instructions. `CLAUDE.md`, `GEMINI.md` and `.cursor/rules/agents.mdc` are thin pointers. `docs/STATE.md` carries the live state and is rewritten each session; `scripts/check-continuity.sh` (inputs in `docs/continuity.conf`) runs from `.githooks/pre-push`.

## Consequences

Rules live in one place. A new tool needs only a pointer file. Changes to rules go in `AGENTS.md`, not in the pointers.
