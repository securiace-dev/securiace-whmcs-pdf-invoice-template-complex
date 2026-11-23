#!/usr/bin/env bash
# check-continuity.sh — fail if version, CHANGELOG and docs/STATE.md disagree.
#
# Config file: docs/continuity.conf (KEY=VALUE, # comments, no secrets).
# Typical keys:
#   STATE=docs/STATE.md          (required; default docs/STATE.md)
#   VERSION_FILE=<path>          (optional)
#   VERSION_REGEX=<ere>          (required if VERSION_FILE is set; first capture is the version)
#   CHANGELOG=CHANGELOG.md       (optional; checked when a version is found)
#   CHANGELOG_PATTERN=<ere>      (optional; default is the version string, grep -F)
#
# This script never prints secrets and never talks to the network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="$ROOT/docs/continuity.conf"
FAILED=0
WARNED=0

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1" >&2; FAILED=1; }
warn() { printf 'WARN  %s\n' "$1" >&2; WARNED=1; }

# Match a version as a whole token so 2.3.4 does not match 2.3.40 or 12.3.4.
has_version_token() {
    local haystack="$1" ver="$2" escaped
    escaped="$(printf '%s' "$ver" | sed -e 's/[][(){}.^$*+?|\\]/\\&/g')"
    printf '%s\n' "$haystack" | grep -qE "(^|[^0-9A-Za-z.])${escaped}([^0-9A-Za-z]|$)"
}

STATE="docs/STATE.md"
VERSION_FILE=""
VERSION_REGEX=""
CHANGELOG=""
CHANGELOG_PATTERN=""

if [ ! -f "$CONF" ]; then
    fail "missing $CONF"
    echo "RESULT: FAIL"
    exit 1
fi

while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        ''|\#*) continue ;;
    esac
    key="${line%%=*}"
    val="${line#*=}"
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    val="${val%"${val##*[![:space:]]}"}"
    val="${val#"${val%%[![:space:]]*}"}"
    case "$key" in
        STATE) STATE="$val" ;;
        VERSION_FILE) VERSION_FILE="$val" ;;
        VERSION_REGEX) VERSION_REGEX="$val" ;;
        CHANGELOG) CHANGELOG="$val" ;;
        CHANGELOG_PATTERN) CHANGELOG_PATTERN="$val" ;;
        *) warn "unknown key in continuity.conf: $key" ;;
    esac
done < "$CONF"

STATE_PATH="$ROOT/$STATE"
if [ ! -s "$STATE_PATH" ]; then
    fail "STATE missing or empty: $STATE"
else
    if grep -qE '^(\*\*)?Updated:' "$STATE_PATH"; then
        pass "STATE has an Updated line: $STATE"
    else
        fail "STATE has no Updated: line: $STATE"
    fi
    if grep -qiE '^## In flight' "$STATE_PATH" && grep -qiE '^## Next' "$STATE_PATH"; then
        pass "STATE has In flight and Next sections"
    else
        fail "STATE must have both ## In flight and ## Next headings"
    fi
fi

VERSION=""
if [ -n "$VERSION_FILE" ]; then
    VF="$ROOT/$VERSION_FILE"
    if [ ! -f "$VF" ]; then
        fail "VERSION_FILE not found: $VERSION_FILE"
    elif [ -z "$VERSION_REGEX" ]; then
        fail "VERSION_REGEX is required when VERSION_FILE is set"
    else
        if VERSION="$(grep -oE "$VERSION_REGEX" "$VF" | head -n 1)"; then
            # If the regex included a capture-like pattern, try to extract the version-looking token.
            if printf '%s' "$VERSION" | grep -qE '[0-9]+\.[0-9]+'; then
                VERSION="$(printf '%s' "$VERSION" | grep -oE '[0-9]+[0-9A-Za-z._-]*' | head -n 1)"
            fi
        fi
        if [ -z "$VERSION" ]; then
            # Fallback: use the first capture by running sed when the regex has a group.
            VERSION="$(sed -nE "s/.*${VERSION_REGEX}.*/\\1/p" "$VF" | head -n 1 || true)"
        fi
        if [ -z "$VERSION" ]; then
            fail "could not extract a version from $VERSION_FILE with VERSION_REGEX"
        else
            pass "version $VERSION from $VERSION_FILE"
        fi
    fi
fi

if [ -n "$VERSION" ]; then
    if [ -n "$CHANGELOG" ]; then
        CL="$ROOT/$CHANGELOG"
        if [ ! -f "$CL" ]; then
            fail "CHANGELOG not found: $CHANGELOG"
        else
            # Only the start of the changelog must mention the current version (avoids stale-only hits).
            HEAD="$(head -n 80 "$CL")"
            if [ -n "$CHANGELOG_PATTERN" ]; then
                if printf '%s\n' "$HEAD" | grep -qE "$CHANGELOG_PATTERN"; then
                    pass "CHANGELOG mentions current version (pattern)"
                else
                    fail "CHANGELOG $CHANGELOG first 80 lines do not match CHANGELOG_PATTERN"
                fi
            else
                if has_version_token "$HEAD" "$VERSION"; then
                    pass "CHANGELOG mentions $VERSION in the first 80 lines"
                else
                    fail "CHANGELOG $CHANGELOG first 80 lines do not mention $VERSION as a whole token"
                fi
            fi
        fi
    else
        warn "no CHANGELOG configured; skipped changelog check"
    fi
    if [ -s "$STATE_PATH" ]; then
        if grep -qE "^(\*\*)?Version:" "$STATE_PATH"; then
            verline="$(grep -E "^(\*\*)?Version:" "$STATE_PATH" | head -n 1)"
            if has_version_token "$verline" "$VERSION"; then
                pass "STATE Version line mentions $VERSION"
            else
                fail "STATE Version line does not mention $VERSION as a whole token"
            fi
        elif has_version_token "$(cat "$STATE_PATH")" "$VERSION"; then
            pass "STATE mentions $VERSION"
        else
            fail "STATE does not mention version $VERSION"
        fi
    fi
fi

echo
if [ "$FAILED" -ne 0 ]; then
    echo "RESULT: FAIL"
    exit 1
fi
echo "RESULT: PASS"
exit 0
