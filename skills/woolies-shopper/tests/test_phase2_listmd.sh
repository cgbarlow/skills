#!/usr/bin/env bash
# Integration test for phase2_bulk_add.sh in its --list-md form (v0.3.0).
# shop.sh produces the shopping list itself (from one of four phase-1 routes)
# and hands phase 2 a pre-rendered markdown file rather than a diagram id.
# This asserts the file form yields the same result as the diagram form and
# does NOT call `iris export diagram`.
#
# Run with: bash tests/test_phase2_listmd.sh
# Exits 0 if all checks pass, 1 otherwise.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$REPO_ROOT/tests"
SCRIPTS_DIR="$REPO_ROOT/scripts"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
export MOCK_FIXTURES_DIR="$TESTS_DIR/fixtures"
export MOCK_IRIS_LOG="$TMP_DIR/iris-calls.log"
export MOCK_WOOLIES_LOG="$TMP_DIR/woolies-calls.log"
: > "$MOCK_IRIS_LOG"
: > "$MOCK_WOOLIES_LOG"

chmod +x "$TESTS_DIR/mock-bin/iris" "$TESTS_DIR/mock-bin/woolies"
export PATH="$TESTS_DIR/mock-bin:$PATH"

STATE_DIR="$TMP_DIR/state"
mkdir -p "$STATE_DIR"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ✓ $*"; }

# Pre-stage the shopping list exactly as shop.sh would, then run the file form.
cp "$TESTS_DIR/fixtures/aggregate-output.md" "$STATE_DIR/aggregate.md"
if ! bash "$SCRIPTS_DIR/phase2_bulk_add.sh" --list-md "$STATE_DIR/aggregate.md" "$STATE_DIR" \
        2>"$TMP_DIR/phase2.stderr"; then
    echo "FAIL: phase2_bulk_add.sh --list-md exited non-zero" >&2
    cat "$TMP_DIR/phase2.stderr" >&2
    exit 1
fi

# Same outcome as the diagram-mode test: 2 added, 3 deferred.
ADDED_COUNT=$(jq '.count' "$STATE_DIR/cart-result.json")
[ "$ADDED_COUNT" = "2" ] || fail "expected 2 added, got $ADDED_COUNT"
pass "cart-result.json has 2 items added (same as diagram mode)"

EXCEPTION_COUNT=$(jq '.count' "$STATE_DIR/exceptions.json")
[ "$EXCEPTION_COUNT" = "3" ] || fail "expected 3 exceptions, got $EXCEPTION_COUNT"
pass "exceptions.json has 3 items deferred"

# The file form must NOT shell out to `iris export diagram`.
if grep -q '^iris export diagram' "$MOCK_IRIS_LOG"; then
    fail "--list-md mode should not call 'iris export diagram'"
fi
pass "--list-md mode did not call 'iris export diagram'"

# Writeback still fires for the 2 cache hits.
UPDATE_CALLS=$(grep -c '^iris update element' "$MOCK_IRIS_LOG" || true)
[ "$UPDATE_CALLS" = "2" ] || fail "expected 2 iris update element calls, got $UPDATE_CALLS"
pass "iris update element called twice (confirmed-date refresh)"

echo ""
echo "All phase2 --list-md tests passed."
exit 0
