#!/usr/bin/env bash
# Phase 2 of the weekly Woolies shop. Pure bash, no LLM.
#
# Inputs:
#   $1 — diagram_id of the smart_markdown shopping list. This is the FINAL
#        combined list (meal plan + recurring list already merged), authored as
#        a smart_markdown diagram whose body lives in `data.markdown_source` and
#        references each item as a `{{element:<uuid>:name}}` token (the element
#        UUID IS the provenance — there are no `<!-- iris:element -->` comments).
#        Items are GFM checklist lines (ADR-239): `- [x]` = ticked off / already
#        handled, bare `- ` (or `- [ ]`) = still to buy. By default we process
#        only the un-ticked lines; set SHOP_PROCESS_TICKED=true to process all.
#   $2 — state_dir for manifest files (cart-result.json, exceptions.json).
#
# For each un-ticked item line:
#   1. Extract the element UUID from its {{element:uuid:name}} token + a best-
#      effort quantity from the surrounding free text.
#   2. Fetch the Ingredient element via `iris elements get`.
#   3. If its "Products" attribute notes carry a cached woolies:NNN
#      SKU, `woolies cart add` it; on success refresh the confirmed: date.
#   4. Otherwise push an exception (with a search hint) to exceptions.json for
#      phase 3 — the common first-run case, since SKUs are cached lazily.
#
# No human-in-the-loop. No LLM. The SKU cache lives in the element's
# "Products" attribute notes — the SKU belongs to the individual product.
# The "Preferred product" attribute is a name-only pointer used for the
# search hint; see ADR-217 for the provenance mechanism this consumes.

set -uo pipefail

DIAGRAM_ID="${1:?usage: phase2_bulk_add.sh <diagram_id> <state_dir>}"
STATE_DIR="${2:?usage: phase2_bulk_add.sh <diagram_id> <state_dir>}"

# Which attribute holds the cached SKU (and gets the writeback). The SKU is a
# property of the individual product, so it lives on "Products", not the
# "Preferred product" pointer.
SKU_ATTR="${SHOP_SKU_ATTR:-Products}"
# Process ticked-off (`- [x]`) lines too? Default: no (only un-ticked = to buy).
PROCESS_TICKED="${SHOP_PROCESS_TICKED:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/iris_attr_update.sh
source "$SCRIPT_DIR/lib/iris_attr_update.sh"

mkdir -p "$STATE_DIR"
ADDED_JSONL="$STATE_DIR/added.jsonl"
EXCEPTIONS_JSONL="$STATE_DIR/exceptions.jsonl"
: > "$ADDED_JSONL"
: > "$EXCEPTIONS_JSONL"

# Fetch the shopping list's markdown body. A smart_markdown diagram keeps its
# source in data.markdown_source (the `--format markdown` export only returns a
# metadata summary, NOT the list — that distinction matters).
MARKDOWN=$(iris --json export diagram "$DIAGRAM_ID" --format json 2>/dev/null \
    | jq -r '.diagram.data.markdown_source // empty')
if [ -z "$MARKDOWN" ]; then
    echo "phase2: could not read data.markdown_source for diagram $DIAGRAM_ID" >&2
    exit 1
fi

# Parse one markdown line. On a processable item line, echoes
#   <element_id>|<qty_num>|<unit_word>
# and returns 0. Returns 1 for headings, prose, blank lines, and (by default)
# ticked-off items.
#
# Item line shape (smart_markdown checklist):
#   - [x|optional] [<qty> [unit]] {{element:<uuid>:name}} [<qty>[ unit]] [_(notes)_]
parse_line() {
    local line="$1"
    [[ "$line" =~ ^-\  ]] || return 1
    local rest="${line#- }"

    # Checkbox state (ADR-239). Strip the marker; honour the ticked filter.
    local ticked=0
    if [[ "$rest" == "[x] "* ]]; then ticked=1; rest="${rest#\[x\] }"
    elif [[ "$rest" == "[ ] "* ]]; then rest="${rest#\[ \] }"
    fi
    [ "$ticked" = "1" ] && [ "$PROCESS_TICKED" != "true" ] && return 1

    # Must reference an element token.
    [[ "$rest" =~ \{\{element:([0-9a-fA-F-]+):[a-zA-Z_]+\}\} ]] || return 1
    local element_id="${BASH_REMATCH[1]}"
    local token="${BASH_REMATCH[0]}"
    local before="${rest%%"$token"*}"
    local after="${rest#*"$token"}"

    # Drop trailing italic notes "_(...)_" and surrounding whitespace.
    after="${after%%_(*}"
    before="$(printf '%s' "$before" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    after="$(printf '%s' "$after" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

    # Quantity: a leading qty in `before` wins, else a trailing qty in `after`.
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
    # Last resort: a weight anywhere in the after-text (e.g. "feijoas 600 g").
    # (bash ERE has no \b, so anchor the unit on a trailing space or end.)
    if [ -z "$qty_num" ] && [[ "$after" =~ ([0-9]+([.][0-9]+)?)[[:space:]]*(g|kg|ml|l)([[:space:]]|$) ]]; then
        qty_num="${BASH_REMATCH[1]}"; unit_word="${BASH_REMATCH[3]}"
    fi
    [ -z "$qty_num" ] && qty_num="1"

    printf '%s|%s|%s\n' "$element_id" "$qty_num" "$unit_word"
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
    IFS='|' read -r element_id qty_raw unit_raw <<< "$parse_output"

    mapped=$(map_unit "$qty_raw" "$unit_raw")
    qty=$(printf '%s' "$mapped" | head -1)
    unit=$(printf '%s' "$mapped" | tail -1)

    if ! element=$(iris --json elements get "$element_id" 2>/dev/null); then
        record_exception "element_fetch_failed" "$element_id" "$element_id" "$qty" "$unit" ""
        continue
    fi

    name=$(printf '%s' "$element" | jq -r '.name // "unknown"')

    # Search hint for phase 3: the chosen product name, then catalogue name, then
    # the element's own name.
    pref_type=$(printf '%s' "$element" | jq -r \
        '[.data.attributes[] | select(.name == "Preferred product")] | .[0].type // ""')
    prod_type=$(printf '%s' "$element" | jq -r \
        '[.data.attributes[] | select(.name == "Products")] | .[0].type // ""')
    search="$pref_type"; [ -z "$search" ] && search="$prod_type"; [ -z "$search" ] && search="$name"

    # Is there a SKU-bearing "Products" attribute, and does it hold a cached SKU?
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
done <<< "$MARKDOWN"

# Roll up jsonl files into final result manifests.
ADDED_COUNT=$(wc -l < "$ADDED_JSONL")
EXCEPTION_COUNT=$(wc -l < "$EXCEPTIONS_JSONL")

jq -s '{added: ., count: length}' "$ADDED_JSONL" > "$STATE_DIR/cart-result.json"
jq -s '{exceptions: ., count: length}' "$EXCEPTIONS_JSONL" > "$STATE_DIR/exceptions.json"

echo "phase 2: added $ADDED_COUNT items, $EXCEPTION_COUNT exceptions deferred to phase 3" >&2
exit 0
