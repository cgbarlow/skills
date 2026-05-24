#!/usr/bin/env bash
# Integration tests for phase2_bulk_add.sh. Stubs out iris + woolies CLIs
# with mocks under tests/mock-bin/ so the bash flow is exercised
# end-to-end without touching real Iris or Woolworths.
#
# Run with: bash tests/test_phase2.sh
# Exits 0 if all checks pass, 1 otherwise.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIR="$REPO_ROOT/tests"
SCRIPTS_DIR="$REPO_ROOT/scripts"

# Set up isolated test state.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
export MOCK_FIXTURES_DIR="$TESTS_DIR/fixtures"
export MOCK_IRIS_LOG="$TMP_DIR/iris-calls.log"
export MOCK_WOOLIES_LOG="$TMP_DIR/woolies-calls.log"
: > "$MOCK_IRIS_LOG"
: > "$MOCK_WOOLIES_LOG"

# Prepend mock-bin/ to PATH so `iris` and `woolies` resolve to mocks.
chmod +x "$TESTS_DIR/mock-bin/iris" "$TESTS_DIR/mock-bin/woolies"
export PATH="$TESTS_DIR/mock-bin:$PATH"

STATE_DIR="$TMP_DIR/state"
mkdir -p "$STATE_DIR"

# ── Run phase 2 against the fixture aggregate ─────────────────────────
DIAGRAM_ID="any-fixture-id"
if ! bash "$SCRIPTS_DIR/phase2_bulk_add.sh" "$DIAGRAM_ID" "$STATE_DIR" 2>"$TMP_DIR/phase2.stderr"; then
    echo "FAIL: phase2_bulk_add.sh exited non-zero" >&2
    cat "$TMP_DIR/phase2.stderr" >&2
    exit 1
fi

# ── Assertions ────────────────────────────────────────────────────────
fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ✓ $*"; }

# cart-result.json must contain the expected 3 successful adds:
#   - Chilli beans → 11111111... → Product[0] (SKU 111000)
#   - Pork mince   → 22222222... → Product[1] (SKU 222001, fallback after STOCKOUT)
#   - (Carrots is element-no-cache → no cached SKU → exception, not added)
ADDED_COUNT=$(jq '.count' "$STATE_DIR/cart-result.json")
[ "$ADDED_COUNT" = "2" ] || fail "expected 2 added, got $ADDED_COUNT"
pass "cart-result.json has 2 items added"

# Chilli beans should be SKU 111000 from Product[0] (cache hit, no fallback).
CHILLI_SKU=$(jq -r '.added[] | select(.name == "Chilli beans") | .sku' "$STATE_DIR/cart-result.json")
[ "$CHILLI_SKU" = "111000" ] || fail "expected Chilli beans SKU 111000, got '$CHILLI_SKU'"
pass "Chilli beans resolved to cached SKU 111000 (Product[0])"

CHILLI_PRODUCT_IDX=$(jq -r '.added[] | select(.name == "Chilli beans") | .product_idx' "$STATE_DIR/cart-result.json")
[ "$CHILLI_PRODUCT_IDX" = "0" ] || fail "expected Chilli product_idx 0, got '$CHILLI_PRODUCT_IDX'"
pass "Chilli beans used the preferred Product attribute (index 0)"

# Pork mince Product[0] notes carry SKU "STOCKOUT" which the mock woolies
# rejects. The fallback should be Product[1] with SKU 222001.
PORK_SKU=$(jq -r '.added[] | select(.name == "Pork mince") | .sku' "$STATE_DIR/cart-result.json")
[ "$PORK_SKU" = "222001" ] || fail "expected Pork mince fallback SKU 222001, got '$PORK_SKU'"
pass "Pork mince fell back to Product[1] after Product[0] cart-add failed"

PORK_PRODUCT_IDX=$(jq -r '.added[] | select(.name == "Pork mince") | .product_idx' "$STATE_DIR/cart-result.json")
[ "$PORK_PRODUCT_IDX" = "1" ] || fail "expected Pork product_idx 1, got '$PORK_PRODUCT_IDX'"
pass "Pork mince used the fallback Product attribute (index 1)"

# Carrots → element-no-cache → Product has empty notes → should be in exceptions
# with reason all_cached_skus_failed (we walked Product rows but none had a SKU).
EXCEPTION_COUNT=$(jq '.count' "$STATE_DIR/exceptions.json")
[ "$EXCEPTION_COUNT" = "3" ] || fail "expected 3 exceptions (Carrots, Unknown thing, Mystery item), got $EXCEPTION_COUNT"
pass "exceptions.json has 3 items deferred to phase 3"

CARROT_REASON=$(jq -r '.exceptions[] | select(.name == "Carrots") | .reason' "$STATE_DIR/exceptions.json")
[ "$CARROT_REASON" = "all_cached_skus_failed" ] || fail "expected Carrots reason all_cached_skus_failed, got '$CARROT_REASON'"
pass "Carrots flagged as all_cached_skus_failed (Product had no cached SKU)"

UNKNOWN_REASON=$(jq -r '.exceptions[] | select(.name == "Unknown thing") | .reason' "$STATE_DIR/exceptions.json")
[ "$UNKNOWN_REASON" = "no_products" ] || fail "expected Unknown thing reason no_products, got '$UNKNOWN_REASON'"
pass "Unknown thing flagged as no_products (no Product attributes on the element)"

MYSTERY_REASON=$(jq -r '.exceptions[] | select(.name == "Mystery item") | .reason' "$STATE_DIR/exceptions.json")
[ "$MYSTERY_REASON" = "no_provenance" ] || fail "expected Mystery item reason no_provenance, got '$MYSTERY_REASON'"
pass "Mystery item flagged as no_provenance (no HTML-comment element_id in aggregate line — graceful degradation path)"

# Sanity check on confirmed-date refresh: we should have called
# iris update element exactly twice (one per successful add).
UPDATE_CALLS=$(grep -c '^iris update element' "$MOCK_IRIS_LOG" || true)
[ "$UPDATE_CALLS" = "2" ] || fail "expected 2 iris update element calls, got $UPDATE_CALLS"
pass "iris update element called twice (refresh confirmed: date per successful add)"

echo ""
echo "All phase2 tests passed."
exit 0
