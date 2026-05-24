#!/usr/bin/env bash
# Phase 2 of the weekly Woolies shop. Pure bash, no LLM.
#
# Inputs:
#   $1 — diagram_id of an aggregated shopping list (output of `iris aggregate`
#        against a meal plan). The aggregation profile MUST have
#        include_provenance=true so each line carries an HTML-comment
#        element_id (ADR-217 / iris v6.31.0). If not, lines without
#        provenance fall through to phase 3 as exceptions — graceful
#        degradation, no hard fail.
#   $2 — state_dir for manifest files (cart-result.json, exceptions.json).
#
# Walks each line of the aggregated list. For each line:
#   1. Look up the underlying Iris Ingredient element via `iris elements get`.
#   2. Walk its Product attributes in preferred order (array order).
#   3. For each Product whose notes carry a cached woolies:NNN SKU,
#      try `woolies cart add`. On success, refresh the confirmed: date
#      on that Product attribute via iris_attr_update.
#   4. On stock-out or 404, fall through to the next Product.
#   5. If no Product succeeds, push to exceptions.json for phase 3.
#
# No human-in-the-loop. No LLM. Designed for sub-minute throughput on
# a 30-item weekly shop where most items are cache hits.

set -uo pipefail

DIAGRAM_ID="${1:?usage: phase2_bulk_add.sh <diagram_id> <state_dir>}"
STATE_DIR="${2:?usage: phase2_bulk_add.sh <diagram_id> <state_dir>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/iris_attr_update.sh
source "$SCRIPT_DIR/lib/iris_attr_update.sh"

mkdir -p "$STATE_DIR"
AGGREGATE_MD="$STATE_DIR/aggregate.md"
ADDED_JSONL="$STATE_DIR/added.jsonl"
EXCEPTIONS_JSONL="$STATE_DIR/exceptions.jsonl"
: > "$ADDED_JSONL"
: > "$EXCEPTIONS_JSONL"

# Fetch the aggregated shopping list as markdown.
if ! iris export diagram "$DIAGRAM_ID" --format md > "$AGGREGATE_MD" 2>/dev/null; then
    echo "phase2: iris export diagram $DIAGRAM_ID failed" >&2
    exit 1
fi

# Parse a single shopping-list line. Returns 0 with name/qty/unit/element_id
# echoed as four pipe-separated values on stdout. Returns 1 if the line
# isn't a shopping-list row (heading, blank, etc.).
#
# Line shape (provenance-on profile):
#   - <name>: <qty>[ <unit>][ <!-- iris:element=<uuid> -->]
parse_line() {
    local line="$1"
    [[ "$line" =~ ^-\  ]] || return 1
    local element_id=""
    local rest="${line#- }"
    # Pull the HTML-comment element_id off the end (if present) and trim it
    # plus any surrounding whitespace.
    if [[ "$rest" =~ ^(.*[^[:space:]])[[:space:]]*\<!--[[:space:]]*iris:element=([0-9a-f-]+)[[:space:]]*--\>[[:space:]]*$ ]]; then
        rest="${BASH_REMATCH[1]}"
        element_id="${BASH_REMATCH[2]}"
    fi
    # Match the "<name>: <qty>[ <unit>]" body. The qty must be numeric; if
    # the body doesn't match, this isn't a shopping-list line.
    if [[ ! "$rest" =~ ^(.+):[[:space:]]+([0-9]+(\.[0-9]+)?)([[:space:]]+(.+))?$ ]]; then
        return 1
    fi
    local name="${BASH_REMATCH[1]}"
    local qty="${BASH_REMATCH[2]}"
    local unit_raw="${BASH_REMATCH[5]:-}"
    printf '%s|%s|%s|%s\n' "$name" "$qty" "$unit_raw" "$element_id"
}

# Map a free-text unit on a shopping-list line to the (qty, woolies_unit)
# pair the woolies CLI expects. Grams and millilitres get normalised to
# their bigger sibling (kg / l). Bare counts → Each.
map_unit() {
    local qty="$1"
    local unit_raw="$2"
    case "${unit_raw,,}" in
        g)         printf '%s\nKilogram\n' "$(awk -v q="$qty" 'BEGIN{printf "%.3f", q/1000}')" ;;
        kg)        printf '%s\nKilogram\n' "$qty" ;;
        ml)        printf '%s\nKilogram\n' "$(awk -v q="$qty" 'BEGIN{printf "%.3f", q/1000}')" ;;
        l)         printf '%s\nEach\n'     "$qty" ;;
        ""|each|"x"|can|pack|bottle|jar|tin|bag) printf '%s\nEach\n' "$qty" ;;
        *)         printf '%s\nEach\n'     "$qty" ;;
    esac
}

record_added() {
    local name="$1" element_id="$2" sku="$3" qty="$4" unit="$5" product_idx="$6"
    jq -nc \
        --arg name "$name" --arg element_id "$element_id" \
        --arg sku "$sku" --arg qty "$qty" --arg unit "$unit" \
        --argjson product_idx "$product_idx" \
        '{name: $name, element_id: $element_id, sku: $sku, quantity: ($qty|tonumber), unit: $unit, product_idx: $product_idx}' \
        >> "$ADDED_JSONL"
}

record_exception() {
    local reason="$1" name="$2" element_id="$3" qty="$4" unit="$5"
    jq -nc \
        --arg reason "$reason" --arg name "$name" --arg element_id "$element_id" \
        --arg qty "$qty" --arg unit "$unit" \
        '{reason: $reason, name: $name, element_id: $element_id, quantity: (if $qty == "" then null else ($qty|tonumber) end), unit: $unit}' \
        >> "$EXCEPTIONS_JSONL"
}

# Main loop
while IFS= read -r line; do
    parse_output=$(parse_line "$line") || continue
    IFS='|' read -r name qty_raw unit_raw element_id <<< "$parse_output"

    mapped=$(map_unit "$qty_raw" "$unit_raw")
    qty=$(printf '%s' "$mapped" | head -1)
    unit=$(printf '%s' "$mapped" | tail -1)

    if [ -z "$element_id" ]; then
        record_exception "no_provenance" "$name" "" "$qty" "$unit"
        continue
    fi

    if ! element=$(iris elements get "$element_id" --json 2>/dev/null); then
        record_exception "element_fetch_failed" "$name" "$element_id" "$qty" "$unit"
        continue
    fi

    product_count=$(printf '%s' "$element" | jq '[.data.attributes[] | select(.name == "Product")] | length')
    if [ "$product_count" -eq 0 ]; then
        record_exception "no_products" "$name" "$element_id" "$qty" "$unit"
        continue
    fi

    success=false
    for product_idx in $(seq 0 $((product_count - 1))); do
        product_notes=$(printf '%s' "$element" | jq -r --argjson i "$product_idx" \
            '[.data.attributes[] | select(.name == "Product")] | .[$i].notes // ""')
        sku=$(extract_woolies_sku "$product_notes")
        [ -z "$sku" ] && continue

        if woolies cart add "$sku" "$qty" --unit "$unit" >/dev/null 2>&1; then
            new_notes=$(refresh_confirmed_date "$product_notes")
            iris_attr_update "$element_id" "Product" "$product_idx" "$new_notes" || true
            record_added "$name" "$element_id" "$sku" "$qty" "$unit" "$product_idx"
            success=true
            break
        fi
    done

    if [ "$success" = "false" ]; then
        record_exception "all_cached_skus_failed" "$name" "$element_id" "$qty" "$unit"
    fi
done < "$AGGREGATE_MD"

# Roll up jsonl files into final result manifests.
ADDED_COUNT=$(wc -l < "$ADDED_JSONL")
EXCEPTION_COUNT=$(wc -l < "$EXCEPTIONS_JSONL")

jq -s '{added: ., count: length}' "$ADDED_JSONL" > "$STATE_DIR/cart-result.json"
jq -s '{exceptions: ., count: length}' "$EXCEPTIONS_JSONL" > "$STATE_DIR/exceptions.json"

echo "phase 2: added $ADDED_COUNT items, $EXCEPTION_COUNT exceptions deferred to phase 3" >&2
exit 0
