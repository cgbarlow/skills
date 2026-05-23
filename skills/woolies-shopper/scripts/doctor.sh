#!/usr/bin/env bash
# Single-call health check the SKILL.md runs at preflight.
#
# Emits a JSON line on stdout so the skill prompt can branch on it:
#
#   {"ok": true, "version": "0.1.1", "logged_in": true}
#   {"ok": false, "reason": "not_installed", "hint": "run scripts/install.sh"}
#   {"ok": false, "reason": "not_logged_in", "hint": "run `woolies login`"}
#
# Always exits 0 — the skill reads the JSON and decides what to do.

set -uo pipefail

emit() {
    printf '%s\n' "$1"
    exit 0
}

if ! command -v woolies >/dev/null 2>&1; then
    emit '{"ok": false, "reason": "not_installed", "hint": "Run ./scripts/install.sh to install woolies-nz-cli."}'
fi

VERSION="$(woolies --version 2>/dev/null | awk '{print $NF}' || true)"
if [ -z "$VERSION" ]; then
    VERSION="unknown"
fi

# `woolies doctor` returns nonzero when not logged in (and on other
# auth/path problems). Capture both streams so we can show the real
# message in the hint.
DOCTOR_OUTPUT="$(woolies doctor 2>&1 || true)"
if printf '%s' "$DOCTOR_OUTPUT" | grep -qiE 'credentials not found|not logged in|please.*login'; then
    emit "$(printf '{"ok": false, "reason": "not_logged_in", "version": "%s", "hint": "Run `woolies login` to sign in to Woolworths NZ."}' "$VERSION")"
fi

if printf '%s' "$DOCTOR_OUTPUT" | grep -qiE 'error|failed|missing'; then
    SAFE_MSG="$(printf '%s' "$DOCTOR_OUTPUT" | tr '\n' ' ' | head -c 240 | sed 's/"/\\"/g')"
    emit "$(printf '{"ok": false, "reason": "doctor_reported_problem", "version": "%s", "hint": "%s"}' "$VERSION" "$SAFE_MSG")"
fi

emit "$(printf '{"ok": true, "version": "%s", "logged_in": true}' "$VERSION")"
