#!/usr/bin/env bash
# Live, self-contained test of the woolies-shopper SKU cache writeback against a
# REAL iris element — exercising the same scripts/lib/iris_attr_update.sh helper
# that phase 2 / phase 3 use.
#
# It is SAFE: it snapshots the element's current data, performs the writeback,
# reads it back to confirm the SKU landed in the cache attribute's notes, then
# restores the original data byte-for-byte (even on failure, via a trap).
#
# Requires write auth. Authenticate first:
#     source scripts/iris-auth.sh
# Then:
#     ./scripts/test-writeback.sh <element_id> [sku]
#
# The SKU cache lives in the "Products" attribute's notes (override with
# SHOP_SKU_ATTR). If the element lacks that attribute the test adds a temporary
# one, writes to it, verifies, then removes it on restore.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/iris_attr_update.sh
source "$SCRIPT_DIR/lib/iris_attr_update.sh"

EL="${1:?usage: test-writeback.sh <element_id> [sku]}"
SKU="${2:-TESTSKU$(date +%H%M%S)}"
SKU_ATTR="${SHOP_SKU_ATTR:-Products}"
TODAY="$(date +%Y-%m-%d)"
NEW_NOTES="woolies:${SKU} | confirmed:${TODAY}"

pass() { printf '\033[32m✓ %s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
die()  { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# ── Preflight: must be authenticated (writeback needs write scope) ──────
# Authenticated whoami has a `.username` (no `.anonymous`/`.url` field); the
# anonymous shape is {"anonymous":true,"url":…}. Classify by `.username`.
WHO=$(iris --json whoami 2>/dev/null || true)
WHO_USER=$(printf '%s' "$WHO" | jq -r '.username // empty' 2>/dev/null || true)
[ -n "$WHO_USER" ] || \
    die "Not authenticated (writeback needs write scope). Run: source scripts/iris-auth.sh  then re-run."
info "iris: authenticated as $WHO_USER"

# ── Snapshot the element ────────────────────────────────────────────────
ORIG=$(iris --json elements get "$EL" 2>/dev/null) || die "could not GET element $EL"
NAME=$(printf '%s' "$ORIG" | jq -r '.name // "?"')
ORIG_DATA=$(printf '%s' "$ORIG" | jq -c '.data')
info "element: $NAME ($EL)"

RESTORE_FILE=$(mktemp)
printf '%s' "$ORIG_DATA" > "$RESTORE_FILE"
restore() {
    iris update element "$EL" --data-json "$(cat "$RESTORE_FILE")" >/dev/null 2>&1 \
        && pass "restored original element data" \
        || printf '\033[31m✗ RESTORE FAILED — original data is in %s\033[0m\n' "$RESTORE_FILE" >&2
    [ -f "$RESTORE_FILE" ] && rm -f "$RESTORE_FILE"
}
trap restore EXIT

# ── Ensure the cache attribute exists (add a temp one if not) ───────────
PCOUNT=$(printf '%s' "$ORIG_DATA" | jq --arg a "$SKU_ATTR" '[.attributes[]? | select(.name==$a)] | length')
if [ "$PCOUNT" -eq 0 ]; then
    info "no '$SKU_ATTR' attribute — adding a temporary one (simulates the no_product_attr path)"
    SETUP_DATA=$(printf '%s' "$ORIG_DATA" | jq -c --arg a "$SKU_ATTR" \
        '.attributes += [{name:$a, type:"", notes:"", scope:"Public", lower_bound:"", upper_bound:""}]')
    iris update element "$EL" --data-json "$SETUP_DATA" >/dev/null 2>&1 \
        || die "failed to add temporary '$SKU_ATTR' attribute"
fi

# ── The writeback under test ────────────────────────────────────────────
info "writing back: $NEW_NOTES  → ${SKU_ATTR}[0].notes"
iris_attr_update "$EL" "$SKU_ATTR" 0 "$NEW_NOTES" || die "iris_attr_update returned non-zero"

# ── Verify by reading back ──────────────────────────────────────────────
AFTER=$(iris --json elements get "$EL" 2>/dev/null) || die "could not re-GET element"
GOT=$(printf '%s' "$AFTER" | jq -r --arg a "$SKU_ATTR" '[.data.attributes[] | select(.name==$a)][0].notes // ""')
[ "$GOT" = "$NEW_NOTES" ] || die "notes mismatch — wrote '$NEW_NOTES', read back '$GOT'"
pass "${SKU_ATTR}[0].notes persisted: $GOT"

GOT_SKU=$(extract_woolies_sku "$GOT")
[ "$GOT_SKU" = "$SKU" ] || die "extract_woolies_sku got '$GOT_SKU', expected '$SKU'"
pass "extract_woolies_sku → $GOT_SKU (round-trips through the cache convention)"

echo
pass "WRITEBACK TEST PASSED — restoring original data…"
# trap performs the restore on exit.
