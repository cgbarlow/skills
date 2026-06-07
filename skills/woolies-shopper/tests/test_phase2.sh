#!/usr/bin/env bash
# Integration tests for phase2_bulk_add.sh against the smart_markdown shopping
# list format. Stubs out the iris + woolies CLIs with mocks under
# tests/mock-bin/ so the bash flow is exercised end-to-end without touching
# real Iris or Woolworths.
#
# Fixture list (tests/fixtures/diagram-export.json → data.markdown_source):
#   - 2 {{element:1111…}}        cache hit       → added (SKU 111000, qty 2 Each)
#   - {{element:2222…}} x 3      cached SKU OOS  → exception cached_sku_failed
#   - 700 g {{element:3333…}}    no cached SKU   → exception no_cached_sku (0.7 kg)
#   - {{element:4444…}}          no Products attr → exception no_product_attr
#   - [x] {{element:5555…}}      ticked off      → skipped (not added/excepted)
#
# Run with: bash tests/test_phase2.sh   (exit 0 = all pass)

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

if ! bash "$SCRIPTS_DIR/phase2_bulk_add.sh" "any-fixture-id" "$STATE_DIR" 2>"$TMP_DIR/phase2.stderr"; then
    echo "FAIL: phase2_bulk_add.sh exited non-zero" >&2
    cat "$TMP_DIR/phase2.stderr" >&2
    exit 1
fi

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ✓ $*"; }

# ── Added: exactly the one cache-hit line ───────────────────────────────
ADDED_COUNT=$(jq '.count' "$STATE_DIR/cart-result.json")
[ "$ADDED_COUNT" = "1" ] || fail "expected 1 added, got $ADDED_COUNT"
pass "cart-result.json has 1 item added"

CHILLI_SKU=$(jq -r '.added[] | select(.name == "Chilli beans") | .sku' "$STATE_DIR/cart-result.json")
[ "$CHILLI_SKU" = "111000" ] || fail "expected Chilli beans SKU 111000, got '$CHILLI_SKU'"
pass "Chilli beans resolved to cached SKU 111000 (Products notes)"

CHILLI_QTY=$(jq -r '.added[] | select(.name == "Chilli beans") | .quantity' "$STATE_DIR/cart-result.json")
CHILLI_UNIT=$(jq -r '.added[] | select(.name == "Chilli beans") | .unit' "$STATE_DIR/cart-result.json")
{ [ "$CHILLI_QTY" = "2" ] && [ "$CHILLI_UNIT" = "Each" ]; } \
    || fail "expected Chilli beans qty 2 Each, got $CHILLI_QTY $CHILLI_UNIT"
pass "Chilli beans quantity parsed as 2 Each (leading '2 {{element}}')"

# ── Exceptions: three, one per non-hit line; ticked line excluded ───────
EXCEPTION_COUNT=$(jq '.count' "$STATE_DIR/exceptions.json")
[ "$EXCEPTION_COUNT" = "3" ] || fail "expected 3 exceptions, got $EXCEPTION_COUNT"
pass "exceptions.json has 3 items deferred to phase 3"

PORK_REASON=$(jq -r '.exceptions[] | select(.name == "Pork mince") | .reason' "$STATE_DIR/exceptions.json")
[ "$PORK_REASON" = "cached_sku_failed" ] || fail "expected Pork mince reason cached_sku_failed, got '$PORK_REASON'"
pass "Pork mince flagged cached_sku_failed (cached SKU rejected by woolies)"

PORK_SEARCH=$(jq -r '.exceptions[] | select(.name == "Pork mince") | .search' "$STATE_DIR/exceptions.json")
[ "$PORK_SEARCH" = "Woolworths Pork Mince 500g" ] || fail "expected Pork search hint from Preferred product type, got '$PORK_SEARCH'"
pass "Pork mince search hint taken from 'Preferred product' type"

CARROT_REASON=$(jq -r '.exceptions[] | select(.name == "Carrots") | .reason' "$STATE_DIR/exceptions.json")
[ "$CARROT_REASON" = "no_cached_sku" ] || fail "expected Carrots reason no_cached_sku, got '$CARROT_REASON'"
pass "Carrots flagged no_cached_sku (Products present, notes empty)"

CARROT_QTY=$(jq -r '.exceptions[] | select(.name == "Carrots") | .quantity' "$STATE_DIR/exceptions.json")
CARROT_UNIT=$(jq -r '.exceptions[] | select(.name == "Carrots") | .unit' "$STATE_DIR/exceptions.json")
{ [ "$CARROT_QTY" = "0.7" ] && [ "$CARROT_UNIT" = "Kilogram" ]; } \
    || fail "expected Carrots qty 0.7 Kilogram (700 g), got $CARROT_QTY $CARROT_UNIT"
pass "Carrots quantity parsed as 0.7 Kilogram (leading '700 g')"

MYSTERY_REASON=$(jq -r '.exceptions[] | select(.name == "Mystery item") | .reason' "$STATE_DIR/exceptions.json")
[ "$MYSTERY_REASON" = "no_product_attr" ] || fail "expected Mystery item reason no_product_attr, got '$MYSTERY_REASON'"
pass "Mystery item flagged no_product_attr (no 'Products' attribute)"

# ── Ticked line must not appear anywhere ────────────────────────────────
TICKED_HITS=$(grep -c '55555555' "$MOCK_IRIS_LOG" || true)
[ "$TICKED_HITS" = "0" ] || fail "ticked-off item (5555…) was processed ($TICKED_HITS iris calls)"
pass "ticked-off ([x]) line was skipped — never fetched or added"

# ── Confirmed-date refresh: one iris update element per successful add ───
UPDATE_CALLS=$(grep -c '^iris update element' "$MOCK_IRIS_LOG" || true)
[ "$UPDATE_CALLS" = "1" ] || fail "expected 1 iris update element call, got $UPDATE_CALLS"
pass "iris update element called once (confirmed: date refreshed on the cache hit)"

echo ""
echo "All phase2 tests passed."
exit 0
