#!/usr/bin/env bash
# Start a My Machines worker so Cloud Agents use THIS machine's gh/git auth.
# Run on macOS (or any host with agent CLI + authorized gh), not in cloud VM.
set -euo pipefail

NAME="${SECURIACE_WORKER_NAME:-kritananda-mac}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(uname -s)" != "Darwin" ]] && [[ "${SECURIACE_ALLOW_NON_MACOS:-}" != "1" ]]; then
  echo "This script targets macOS host auth. Set SECURIACE_ALLOW_NON_MACOS=1 to override." >&2
  exit 1
fi

if ! command -v agent >/dev/null 2>&1; then
  echo "Install Cursor CLI: curl https://cursor.com/install -fsS | bash" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required on the host" >&2
  exit 1
fi

echo "Checking host GitHub auth (must NOT be cloud integration 'cursor' / ghs_*)..."
if gh auth status 2>&1 | grep -q 'Logged in to github.com account cursor'; then
  echo "Still using Cursor cloud integration token. Run: gh auth login" >&2
  exit 1
fi

gh auth status >/dev/null

cd "$ROOT"
REMOTE="$(git remote get-url origin 2>/dev/null || true)"
echo "Worker directory: $ROOT"
echo "Git remote: ${REMOTE:-<none yet — publish script can add origin>}"
echo "Starting My Machines worker: $NAME"
echo "Keep this terminal open. Pick '$NAME' in cursor.com/agents or use worker=$NAME in GitHub comments."
exec agent worker start --name "$NAME" --worker-dir "$ROOT"
