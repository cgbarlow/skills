#!/usr/bin/env bash
# Phase 2 of the weekly Woolies shop. Pure bash, no LLM.
#
# Inputs (two forms):
#   phase2_bulk_add.sh --list-md <file> <state_dir>
#        <file> — a pre-rendered shopping-list markdown (produced by shop.sh
#        from any of its phase-1 routes). This is the form shop.sh uses.
#   phase2_bulk_add.sh <diagram_id> <state_dir>
#        <diagram_id> — diagram id of a shopping-list View. A smart_markdown
#        diagram is read from data.markdown_source; anything else falls back to
#        `iris export diagram --format markdown`. Retained for standalone use.
#
# The list can be in EITHER of two line formats, detected per line:
#   • smart_markdown checklist (the combined meal-plan + recurring list):
#       - [x|optional] [<qty>] {{element:<uuid>:name}} [<qty>] [_(notes)_]
#     `[x]` = ticked off / already handled (ADR-239); bare/`[ ]` = still to buy.
#     By default only un-ticked lines are processed (SHOP_PROCESS_TICKED=true
#     for all). The {{element:…}} token IS the provenance.
#   • aggregation output (meal-plan routes, ADR-217 include_provenance=true):
#       - <name>: <qty>[ <unit>] [<!-- iris:element=<uuid> -->]
#     Lines with no element id (e.g. a shopping-list-from-photo) become
#     no_provenance exceptions — graceful degradation, no hard fail.
#
# For each processable line we fetch the Iris element and, if its "Products"
# attribute notes carry a cached woolies:NNN SKU, `woolies cart add` it and
# refresh the confirmed: date. Otherwise we push an exception (with a search
# hint) to exceptions.json for phase 3. The SKU is a property of the product,
# so it lives on "Products"; "Preferred product" is a name-only pointer used
# only for the search hint. Override the cache attribute with SHOP_SKU_ATTR.
#
# No human-in-the-loop. No LLM.

set -uo pipefail

USAGE="usage: phase2_bulk_add.sh --list-md <file> <state_dir> | phase2_bulk_add.sh <diagram_id> <state_dir>"
if [ "${1:-}" = "--list-md" ]; then
    LIST_MD="${2:?$USAGE}"
    STATE_DIR="${3:?$USAGE}"
    SOURCE_MODE="file"
else
    DIAGRAM_ID="${1:?$USAGE}"
    STATE_DIR="${2:?$USAGE}"
    SOURCE_MODE="diagram"
fi

# Which attribute holds the cached SKU (and gets the writeback).
SKU_ATTR="${SHOP_SKU_ATTR:-Products}"
# Process ticked-off (`- [x]`) smart_markdown lines too? Default: no.
PROCESS_TICKED="${SHOP_PROCESS_TICKED:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/iris_attr_update.sh
source "$SCRIPT_DIR/lib/iris_attr_update.sh"

mkdir -p "$STATE_DIR"
AGGREGATE_MD="$STATE_DIR/aggregate.md"
ADDED_JSONL="$STATE_DIR/added.jsonl"
EXCEPTIONS_JSONL="$STATE_DIR/exceptions.jsonl"
: > "$ADDED_JSONL"
: > "$EXCEPTIONS_JSONL"

# Obtain the shopping list as markdown at $AGGREGATE_MD.
if [ "$SOURCE_MODE" = "file" ]; then
    if [ ! -s "$LIST_MD" ]; then
        echo "phase2: list markdown '$LIST_MD' is missing or empty" >&2
        exit 1
    fi
    [ "$LIST_MD" = "$AGGREGATE_MD" ] || cp "$LIST_MD" "$AGGREGATE_MD"
else
    # A smart_markdown diagram keeps its body in data.markdown_source; the
    # `--format markdown` export only returns a metadata summary. Prefer
    # markdown_source, fall back to the markdown export for other diagram types.
    SRC=$(iris --json export diagram "$DIAGRAM_ID" --format json 2>/dev/null \
        | jq -r '.diagram.data.markdown_source // empty')
    if [ -n "$SRC" ]; then
        printf '%s\n' "$SRC" > "$AGGREGATE_MD"
    elif ! iris export diagram "$DIAGRAM_ID" --format markdown > "$AGGREGATE_MD" 2>/dev/null; then
        echo "phase2: could not read diagram $DIAGRAM_ID (no markdown_source, export failed)" >&2
        exit 1
    fi
fi

# Parse one markdown line. On a processable item line echoes
#   <element_id>|<qty_num>|<unit_word>|<line_name>
# (element_id/line_name may be empty) and returns 0. Returns 1 for headings,
# prose, blanks, and (by default) ticked-off smart_markdown items.
parse_line() {
    local line="$1"
    [[ "$line" =~ ^-\  ]] || return 1
    local rest="${line#- }"

    # ── smart_markdown checklist line (has an {{element:…}} token) ──
    if [[ "$rest" == *'{{element:'* ]]; then
        local ticked=0
        if [[ "$rest" == "[x] "* ]]; then ticked=1; rest="${rest#\[x\] }"
        elif [[ "$rest" == "[ ] "* ]]; then rest="${rest#\[ \] }"
        fi
        [ "$ticked" = "1" ] && [ "$PROCESS_TICKED" != "true" ] && return 1

        [[ "$rest" =~ \{\{element:([0-9a-fA-F-]+):[a-zA-Z_]+\}\} ]] || return 1
        local element_id="${BASH_REMATCH[1]}"
        local token="${BASH_REMATCH[0]}"
        local before="${rest%%"$token"*}"
        local after="${rest#*"$token"}"
        after="${after%%_(*}"
        before="$(printf '%s' "$before" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
        after="$(printf '%s' "$after" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

        local qty_num="" unit_word=""
        if [[ "$before" =~ ^([0-9]+([.][0-9]+)?)[[:space:]]*([a-zA-Z]+)?$ ]]; then
            qty_num="${BASH_REMATCH[1]}"; unit_word="${BASH_REMATCH[3]:-}"
        fi
        if [ -z "$qty_num" ]; then
            local a="${after#x }"; a="${a#x}"
            a="$(printf '%s' "$a" | sed -E 's/^[[:space:]]+//')"
            if [[ "$a" =~ ^([0-9]+([.][0-9]+)?)[[:space:]]*([a-zA-Z]+)? ]]; then
                qty_num="${BASH_REMATCH[1]}"; unit_word="${BASH_REMATCH[3]:-}"
            fi
        fi
        if [ -z "$qty_num" ] && [[ "$after" =~ ([0-9]+([.][0-9]+)?)[[:space:]]*(g|kg|ml|l)([[:space:]]|$) ]]; then
            qty_num="${BASH_REMATCH[1]}"; unit_word="${BASH_REMATCH[3]}"
        fi
        [ -z "$qty_num" ] && qty_num="1"
        printf '%s|%s|%s|\n' "$element_id" "$qty_num" "$unit_word"
        return 0
    fi

    # ── aggregation-output line: "<name>: <qty>[ unit] [<!-- iris:element=… -->]" ──
    local element_id=""
    if [[ "$rest" =~ ^(.*[^[:space:]])[[:space:]]*\<!--[[:space:]]*iris:element=([0-9a-f-]+)[[:space:]]*--\>[[:space:]]*$ ]]; then
        rest="${BASH_REMATCH[1]}"
        element_id="${BASH_REMATCH[2]}"
    fi
    [[ "$rest" =~ ^(.+):[[:space:]]+([0-9]+(\.[0-9]+)?)([[:space:]]+(.+))?$ ]] || return 1
    printf '%s|%s|%s|%s\n' "$element_id" "${BASH_REMATCH[2]}" "${BASH_REMATCH[5]:-}" "${BASH_REMATCH[1]}"
}

# Map a free-text unit to the (qty, woolies_unit) pair the CLI expects.
# Grams/millilitres normalise to kg; counts and pack-words → Each.
map_unit() {
    local qty="$1" unit_raw="$2"
    case "${unit_raw,,}" in
        g|ml)  printf '%s\nKilogram\n' "$(awk -v q="$qty" 'BEGIN{printf "%.3f", q/1000}')" ;;
        kg)    printf '%s\nKilogram\n' "$qty" ;;
        *)     printf '%s\nEach\n'     "$qty" ;;
    esac
}

record_added() {
    local name="$1" element_id="$2" sku="$3" qty="$4" unit="$5" attr_idx="$6"
    jq -nc \
        --arg name "$name" --arg element_id "$element_id" --arg sku "$sku" \
        --arg qty "$qty" --arg unit "$unit" --argjson attr_idx "$attr_idx" \
        '{name: $name, element_id: $element_id, sku: $sku, quantity: ($qty|tonumber), unit: $unit, attr_idx: $attr_idx}' \
        >> "$ADDED_JSONL"
}

record_exception() {
    local reason="$1" name="$2" element_id="$3" qty="$4" unit="$5" search="$6"
    jq -nc \
        --arg reason "$reason" --arg name "$name" --arg element_id "$element_id" \
        --arg qty "$qty" --arg unit "$unit" --arg search "$search" \
        '{reason: $reason, name: $name, element_id: $element_id,
          quantity: (if $qty == "" then null else ($qty|tonumber) end),
          unit: $unit, search: $search}' \
        >> "$EXCEPTIONS_JSONL"
}

# Main loop
while IFS= read -r line; do
    parse_output=$(parse_line "$line") || continue
    IFS='|' read -r element_id qty_raw unit_raw line_name <<< "$parse_output"

    mapped=$(map_unit "$qty_raw" "$unit_raw")
    qty=$(printf '%s' "$mapped" | head -1)
    unit=$(printf '%s' "$mapped" | tail -1)

    # No element id → no provenance → can't use the cache (e.g. photo-OCR list).
    if [ -z "$element_id" ]; then
        record_exception "no_provenance" "${line_name:-unknown}" "" "$qty" "$unit" "${line_name:-}"
        continue
    fi

    if ! element=$(iris --json elements get "$element_id" 2>/dev/null); then
        record_exception "element_fetch_failed" "${line_name:-$element_id}" "$element_id" "$qty" "$unit" "${line_name:-}"
        continue
    fi

    name=$(printf '%s' "$element" | jq -r '.name // empty')
    [ -z "$name" ] && name="${line_name:-unknown}"

    # Search hint for phase 3: chosen-product name → catalogue name → element name.
    pref_type=$(printf '%s' "$element" | jq -r \
        '[.data.attributes[] | select(.name == "Preferred product")] | .[0].type // ""')
    prod_type=$(printf '%s' "$element" | jq -r \
        '[.data.attributes[] | select(.name == "Products")] | .[0].type // ""')
    search="$pref_type"; [ -z "$search" ] && search="$prod_type"; [ -z "$search" ] && search="$name"

    pref_count=$(printf '%s' "$element" | jq --arg a "$SKU_ATTR" \
        '[.data.attributes[] | select(.name == $a)] | length')
    if [ "$pref_count" -eq 0 ]; then
        record_exception "no_product_attr" "$name" "$element_id" "$qty" "$unit" "$search"
        continue
    fi

    pref_notes=$(printf '%s' "$element" | jq -r --arg a "$SKU_ATTR" \
        '[.data.attributes[] | select(.name == $a)] | .[0].notes // ""')
    sku=$(extract_woolies_sku "$pref_notes")
    if [ -z "$sku" ]; then
        record_exception "no_cached_sku" "$name" "$element_id" "$qty" "$unit" "$search"
        continue
    fi

    if woolies cart add "$sku" "$qty" --unit "$unit" >/dev/null 2>&1; then
        new_notes=$(refresh_confirmed_date "$pref_notes")
        iris_attr_update "$element_id" "$SKU_ATTR" 0 "$new_notes" || true
        record_added "$name" "$element_id" "$sku" "$qty" "$unit" 0
    else
        record_exception "cached_sku_failed" "$name" "$element_id" "$qty" "$unit" "$search"
    fi
done < "$AGGREGATE_MD"

# Roll up jsonl files into final result manifests.
ADDED_COUNT=$(wc -l < "$ADDED_JSONL")
EXCEPTION_COUNT=$(wc -l < "$EXCEPTIONS_JSONL")

jq -s '{added: ., count: length}' "$ADDED_JSONL" > "$STATE_DIR/cart-result.json"
jq -s '{exceptions: ., count: length}' "$EXCEPTIONS_JSONL" > "$STATE_DIR/exceptions.json"

echo "phase 2: added $ADDED_COUNT items, $EXCEPTION_COUNT exceptions deferred to phase 3" >&2
exit 0
