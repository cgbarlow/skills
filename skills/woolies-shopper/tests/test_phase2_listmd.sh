#!/usr/bin/env bash
# Integration test for phase2_bulk_add.sh in its --list-md form, exercising the
# AGGREGATION-output line format (`- name: qty <!-- iris:element=… -->`) that the
# meal-plan phase-1 routes produce. (The smart_markdown `{{element:…}}` format is
# covered by test_phase2.sh via the diagram-id form.) shop.sh hands phase 2 a
# pre-rendered markdown file; this asserts the file form parses the aggregate
# format, uses the Products cache, and does NOT call `iris export diagram`.
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

# Aggregate-format outcome against the Products fixtures: 1 added, 4 deferred.
#   Chilli beans (1111) cache hit → added; Pork mince (2222) STOCKOUT →
#   cached_sku_failed; Carrots (3333) empty notes → no_cached_sku; Mystery item
#   (4444) no Products attr → no_product_attr; loose line → no_provenance.
ADDED_COUNT=$(jq '.count' "$STATE_DIR/cart-result.json")
[ "$ADDED_COUNT" = "1" ] || fail "expected 1 added, got $ADDED_COUNT"
pass "cart-result.json has 1 item added (aggregate-format cache hit)"

CHILLI_QTY=$(jq -r '.added[] | select(.name == "Chilli beans") | .quantity' "$STATE_DIR/cart-result.json")
[ "$CHILLI_QTY" = "2" ] || fail "expected Chilli beans qty 2 (aggregate '2 can'), got $CHILLI_QTY"
pass "aggregate-format quantity parsed (Chilli beans: 2 can → 2 Each)"

EXCEPTION_COUNT=$(jq '.count' "$STATE_DIR/exceptions.json")
[ "$EXCEPTION_COUNT" = "4" ] || fail "expected 4 exceptions, got $EXCEPTION_COUNT"
pass "exceptions.json has 4 items deferred"

NOPROV=$(jq -r '[.exceptions[] | select(.reason == "no_provenance")] | length' "$STATE_DIR/exceptions.json")
[ "$NOPROV" = "1" ] || fail "expected 1 no_provenance exception (line without an element comment), got $NOPROV"
pass "line with no element comment flagged no_provenance"

# The file form must NOT shell out to `iris export diagram`.
if grep -q '^iris export diagram' "$MOCK_IRIS_LOG"; then
    fail "--list-md mode should not call 'iris export diagram'"
fi
pass "--list-md mode did not call 'iris export diagram'"

# Writeback fires once, for the single cache hit.
UPDATE_CALLS=$(grep -c '^iris update element' "$MOCK_IRIS_LOG" || true)
[ "$UPDATE_CALLS" = "1" ] || fail "expected 1 iris update element call, got $UPDATE_CALLS"
pass "iris update element called once (confirmed-date refresh on the cache hit)"

echo ""
echo "All phase2 --list-md tests passed."
exit 0
