#!/usr/bin/env bash
# Helper: update the `notes` field of a specific element attribute via the
# iris CLI's get-merge-put pattern. The CLI's `iris update element` takes
# the whole `data` blob; this wrapper handles fetching the current data,
# mutating only the targeted attribute row, and putting it back.
#
# Reused by phase2_bulk_add.sh (refresh confirmed: timestamp on success)
# and by the woolies-shopper skill in phase 3 (write back newly-discovered
# SKUs). Single source of truth per §13 DRY.
#
# Usage:
#   source lib/iris_attr_update.sh
#   iris_attr_update <element_id> <attribute_name> <index_among_named> <new_notes>
#
# Where <index_among_named> is the 0-based index among attribute rows whose
# `name` field matches <attribute_name>. So if an element has 3 "Product"
# attributes, index 0 is the first one (preferred), 1 is the second, etc.
#
# Returns 0 on success, non-zero if iris CLI rejects the update or the
# named attribute index doesn't exist.

iris_attr_update() {
    local element_id="$1"
    local attr_name="$2"
    local target_idx="$3"
    local new_notes="$4"

    if [ -z "$element_id" ] || [ -z "$attr_name" ] || [ -z "$target_idx" ]; then
        echo "iris_attr_update: element_id, attr_name, and target_idx are required" >&2
        return 2
    fi

    local current
    if ! current=$(iris elements get "$element_id" --json 2>&1); then
        echo "iris_attr_update: failed to GET element $element_id: $current" >&2
        return 1
    fi

    local updated_data
    updated_data=$(printf '%s' "$current" | jq \
        --arg name "$attr_name" \
        --argjson idx "$target_idx" \
        --arg notes "$new_notes" '
        .data as $d
        | [$d.attributes | to_entries[] | select(.value.name == $name) | .key] as $idxs
        | if ($idxs | length) > $idx
          then $d | .attributes[$idxs[$idx]].notes = $notes
          else error("attribute row not found")
          end
    ') || {
        echo "iris_attr_update: jq failed (likely missing attribute row $attr_name[$target_idx])" >&2
        return 1
    }

    if ! iris update element "$element_id" --data-json "$updated_data" >/dev/null 2>&1; then
        echo "iris_attr_update: iris update element failed for $element_id" >&2
        return 1
    fi
    return 0
}

# Helper: rewrite the `confirmed:YYYY-MM-DD` token inside a notes string
# (or append one if absent). Preserves the rest of the notes verbatim.
refresh_confirmed_date() {
    local notes="$1"
    local today="${2:-$(date +%Y-%m-%d)}"
    if printf '%s' "$notes" | grep -qE 'confirmed:[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
        printf '%s' "$notes" | sed -E "s/confirmed:[0-9]{4}-[0-9]{2}-[0-9]{2}/confirmed:$today/"
    elif [ -z "$notes" ]; then
        printf 'confirmed:%s' "$today"
    else
        printf '%s | confirmed:%s' "$notes" "$today"
    fi
}

# Helper: extract the first woolies:NNNN SKU from a notes string.
# Returns empty string if none found. Pure function, no CLI calls.
extract_woolies_sku() {
    local notes="$1"
    printf '%s' "$notes" | grep -oE 'woolies:[0-9A-Za-z]+' | head -1 | cut -d: -f2
}
