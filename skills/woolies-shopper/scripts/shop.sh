#!/usr/bin/env bash
# Master orchestrator for the weekly Woolworths NZ online shop.
#
# Three phases:
#   1. Produce the shopping list ($STATE_DIR/aggregate.md). Two choices,
#      asked at run time (v0.3.0):
#        a) WHAT — "Meal plan" (derive the list from a week's meals via
#           Iris aggregation) or "Shopping list" (use a list directly).
#        b) WHERE — "Photo" (newest *.jpg/*.jpeg/*.png in the current
#           directory, OCR'd headlessly by `claude -p`; HEIC unsupported)
#           or "Iris View GUID" (an existing diagram already in Iris).
#      Meal-plan photo input matches each meal to its EXISTING Iris recipe
#      and reports any it can't (they contribute nothing to the list);
#      every path ends with a confirm/gate before phase 2.
#   2. Pure bash (`phase2_bulk_add.sh --list-md`): walks the list, uses
#      cached SKUs from each Ingredient's Product attribute notes to
#      bulk-add to the Woolies trolley. Refreshes the confirmed: date on
#      success. Unresolved lines go to $STATE_DIR/exceptions.json. The
#      SKU cache only applies when the list carries element provenance
#      (aggregation profile output.include_provenance=true, ADR-217);
#      shopping-list-from-photo has none, so all lines fall to phase 3.
#   3. Conditional `claude -p` session: only if exceptions.json is
#      non-empty. Invokes the woolies-shopper skill (the exception
#      resolver) to search, ask about ambiguities, cart-add, and write
#      newly-discovered SKUs back to Iris via `iris update element`.
#
# User then opens woolworths.co.nz in a browser to review the trolley
# and submit the order. shop.sh stops at trolley-populated.
#
# Usage:
#   ./shop.sh                       # runs the full pipeline (prompts for mode)
#   SHOP_STATE_DIR=...              # override the manifest directory
#   IRIS_SHOPPING_PROFILE_ID=...    # skip the aggregation-profile picker
#
# Requires: claude CLI, iris CLI (authenticated), woolies CLI
# (logged in), jq, bash 4+. Run scripts/install.sh and `iris login`
# once before first use.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

STATE_DIR="${SHOP_STATE_DIR:-/tmp/shop-$(date +%Y-%m-%d-%H%M%S)}"
mkdir -p "$STATE_DIR"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
fail() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

# Echo the newest *.jpg/*.jpeg/*.png in the current directory (empty if none).
# GNU find (-printf) is fine on the Linux devcontainers this skill targets.
# HEIC is deliberately excluded — Claude's image reader doesn't accept it.
find_newest_image() {
    find . -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
        -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
}

# True if $1 looks like an Iris diagram/element GUID (hex + hyphens).
is_guid() { printf '%s' "$1" | grep -qiE '^[0-9a-f]{8}-[0-9a-f-]{20,}$'; }

# Print a file boxed and require a y/N confirmation; fail with $3 as the hint.
show_and_confirm() {
    local file="$1" question="$2" hint="$3" ans
    bold ""
    bold "$question"
    echo "────────────────────────────────────────────────────────────────"
    cat "$file"
    echo "────────────────────────────────────────────────────────────────"
    bold "  If anything is off, edit $file now, then answer y."
    read -r -p "$question [y/N] " ans
    case "$ans" in
        [yY] | [yY][eE][sS]) ;;
        *) fail "Aborted at confirmation. $hint, then re-run shop.sh." ;;
    esac
}

# Resolve the aggregation profile id (meal-plan modes). Honours
# IRIS_SHOPPING_PROFILE_ID; else lists profiles and auto-uses the only one,
# or presents a numbered picker. Echoes the id; returns non-zero if none.
# Menu + prompt go to stderr so the captured stdout is just the id.
resolve_profile_id() {
    if [ -n "${IRIS_SHOPPING_PROFILE_ID:-}" ]; then
        printf '%s' "$IRIS_SHOPPING_PROFILE_ID"; return 0
    fi
    local json arr count sel
    json="$(iris aggregation-profile list --json 2>/dev/null)" || return 1
    arr="$(printf '%s' "$json" | jq -c \
        'if type=="array" then . else (.items // .profiles // .results // []) end')"
    count="$(printf '%s' "$arr" | jq 'length')"
    if [ "$count" -eq 0 ]; then
        return 2
    elif [ "$count" -eq 1 ]; then
        printf '%s' "$arr" | jq -r '.[0].id'; return 0
    fi
    bold "Which aggregation profile?" >&2
    printf '%s' "$arr" | jq -r 'to_entries[] | "  \(.key+1)) \(.value.name)  [\(.value.id)]"' >&2
    read -r -p "Select [1-$count]: " sel
    printf '%s' "$arr" | jq -r --argjson i "$((sel - 1))" '.[$i].id // empty'
}

# Warn (don't fail) if a profile won't emit provenance, since that silently
# disables the SKU cache and the phase-3 writeback.
warn_if_no_provenance() {
    local pid="$1" inc
    inc="$(iris aggregation-profile get "$pid" --json 2>/dev/null \
        | jq -r '.profile_data.output.include_provenance // false')"
    if [ "$inc" != "true" ]; then
        warn ""
        warn "⚠ Aggregation profile $pid has output.include_provenance = false."
        warn "  The list will carry no element ids, so phase 2 can't use the SKU"
        warn "  cache (every line → manual phase 3) and resolved SKUs can't be"
        warn "  written back. Enable it with:"
        warn "    iris update aggregation-profile $pid --profile-data-file <json with output.include_provenance=true>"
        warn ""
    fi
}

bold "════════════════════════════════════════════════════════════════"
bold "  Weekly Woolworths shop — state dir: $STATE_DIR"
bold "════════════════════════════════════════════════════════════════"

# ── Preflight ────────────────────────────────────────────────────────
bold ""
bold "Preflight"
"$SCRIPT_DIR/doctor.sh" > "$STATE_DIR/doctor.json"
DOCTOR_OK=$(jq -r '.ok' "$STATE_DIR/doctor.json")
if [ "$DOCTOR_OK" != "true" ]; then
    REASON=$(jq -r '.reason' "$STATE_DIR/doctor.json")
    HINT=$(jq -r '.hint' "$STATE_DIR/doctor.json")
    warn "woolies doctor: $REASON"
    warn "  $HINT"
    fail "Resolve the woolies preflight problem above, then re-run shop.sh."
fi
echo "  woolies: ok"

if ! command -v iris >/dev/null 2>&1; then
    fail "iris CLI not found. Install + run \`iris login\` before shop.sh."
fi
if ! iris whoami >/dev/null 2>&1; then
    warn "iris CLI is installed but not authenticated."
    fail "Run \`iris login\` then re-run shop.sh."
fi
echo "  iris:    ok"

if ! command -v claude >/dev/null 2>&1; then
    fail "claude CLI not found. Install Claude Code from https://claude.com/claude-code"
fi
echo "  claude:  ok"

for tool in jq awk; do
    command -v "$tool" >/dev/null 2>&1 || fail "$tool is required and not on PATH."
done
echo "  jq/awk:  ok"

# ── Phase 1 — produce the shopping list ($STATE_DIR/aggregate.md) ─────
# Two run-time choices select one of four routes; each ends by writing the
# shopping list (ideally with element-provenance comments) to aggregate.md.
AGGREGATE_MD="$STATE_DIR/aggregate.md"

bold ""
bold "What are we shopping from?"
echo "  1) Meal plan     — derive the shopping list from a week's meals (Iris aggregation)"
echo "  2) Shopping list — use a shopping list directly"
read -r -p "Select [1-2]: " SHOP_MODE
case "$SHOP_MODE" in 1 | 2) ;; *) fail "Invalid selection '$SHOP_MODE'. Choose 1 or 2." ;; esac

bold ""
bold "Where's the input coming from?"
echo "  1) Photo in the current directory (newest *.jpg/*.jpeg/*.png, OCR'd)"
echo "  2) Iris View GUID (a diagram already in Iris)"
read -r -p "Select [1-2]: " INPUT_SRC
case "$INPUT_SRC" in 1 | 2) ;; *) fail "Invalid selection '$INPUT_SRC'. Choose 1 or 2." ;; esac

bold ""
bold "Phase 1 — Producing the shopping list"

if [ "$SHOP_MODE" = "1" ]; then
    # ── Meal plan → aggregate a source meal-plan diagram via a profile ──
    PROFILE_ID="$(resolve_profile_id)" || PROFILE_ID=""
    if [ -z "$PROFILE_ID" ]; then
        fail "No aggregation profile available. Create one in Iris, or set IRIS_SHOPPING_PROFILE_ID."
    fi
    echo "  aggregation profile: $PROFILE_ID"
    warn_if_no_provenance "$PROFILE_ID"

    if [ "$INPUT_SRC" = "1" ]; then
        # Route 1a: meal-plan photo → OCR → confirm → match recipes → aggregate.
        MEALPLAN_IMG="$(find_newest_image)"
        [ -n "$MEALPLAN_IMG" ] || fail "No .jpg/.jpeg/.png photo found in $(pwd). Drop this week's meal-plan photo here and re-run. (HEIC isn't supported — export as JPG.)"
        echo "  using newest image: $MEALPLAN_IMG"

        # OCR only — no Iris writes — so the parse can be sanity-checked first.
        MEALPLAN_MD="$STATE_DIR/mealplan.md"
        OCR_PROMPT="You are running headless as phase 1 of an automated weekly-shop pipeline. Read the meal-plan photo at the path '$MEALPLAN_IMG' with the Read tool and OCR it. Extract the planned meals/dishes and any ingredients and quantities written on it. Write the parsed meal plan as clean Markdown to the file '$MEALPLAN_MD' (meals as headings, ingredients as bullet lists). Do NOT create anything in Iris and do NOT run any iris commands in this step. Print a one-line confirmation when the file is written."
        claude -p "$OCR_PROMPT" || fail "Phase 1 OCR step failed. Check the photo and your Claude setup."
        [ -s "$MEALPLAN_MD" ] || fail "Phase 1 OCR produced no meal plan at $MEALPLAN_MD."
        show_and_confirm "$MEALPLAN_MD" "Does this meal plan look right?" "Fix the photo or edit $MEALPLAN_MD"

        # Commit: match each meal to its EXISTING Iris recipe, link them into a
        # new meal-plan diagram, report unmatched meals, hand off the diagram id.
        : > "$STATE_DIR/unmatched.md"
        COMMIT_PROMPT="You are running headless as the commit step of phase 1 of an automated weekly-shop pipeline. The user approved the parsed meal plan in '$MEALPLAN_MD'. Using the Iris MCP: (1) For each planned meal, find the EXISTING recipe diagram in Iris that represents it (search by name) — recipes are the sub-diagrams whose ingredients drive the shopping list. Do NOT invent ingredients or create new recipes. (2) Create a meal-plan diagram that references the matched recipe sub-diagrams so aggregation can roll up their ingredients. (3) Write any meals you could NOT match to an existing Iris recipe, one per line, to '$STATE_DIR/unmatched.md' (leave it empty if all matched). (4) Write ONLY the bare meal-plan diagram UUID (no other text) to '$STATE_DIR/diagram-id'. Print a one-line confirmation when done."
        claude -p "$COMMIT_PROMPT" || fail "Phase 1 commit step failed. Check $STATE_DIR for partial state."

        SOURCE_DIAGRAM_ID="$(tr -d '[:space:]' < "$STATE_DIR/diagram-id" 2>/dev/null || true)"
        is_guid "$SOURCE_DIAGRAM_ID" || fail "Phase 1 did not write a valid meal-plan diagram id to $STATE_DIR/diagram-id."

        # Gate: surface meals that matched no Iris recipe (they contribute
        # nothing to the shopping list) before spending the aggregate call.
        if [ -s "$STATE_DIR/unmatched.md" ]; then
            warn ""
            warn "These meals had no matching Iris recipe and won't appear in the list:"
            cat "$STATE_DIR/unmatched.md" >&2
            warn ""
            read -r -p "Proceed with the matched meals only? [y/N] " _ANS
            case "$_ANS" in
                [yY] | [yY][eE][sS]) ;;
                *) fail "Aborted. Add the missing recipes in Iris, then re-run shop.sh." ;;
            esac
        fi
    else
        # Route 1b: existing meal-plan View GUID → straight to aggregate.
        read -r -p "Enter the Iris meal-plan View GUID: " SOURCE_DIAGRAM_ID
        is_guid "$SOURCE_DIAGRAM_ID" || fail "'$SOURCE_DIAGRAM_ID' doesn't look like an Iris GUID."
    fi

    echo "  aggregating meal plan $SOURCE_DIAGRAM_ID via profile $PROFILE_ID…"
    if ! iris aggregate --profile "$PROFILE_ID" --source "$SOURCE_DIAGRAM_ID" --json 2>/dev/null \
            | jq -r '.markdown // empty' > "$AGGREGATE_MD"; then
        fail "iris aggregate failed for source $SOURCE_DIAGRAM_ID / profile $PROFILE_ID."
    fi

else
    # ── Shopping list → use a list directly ──
    if [ "$INPUT_SRC" = "1" ]; then
        # Route 2a: photo of a shopping list. No Iris elements behind it, so
        # there's no provenance — the SKU cache can't apply and every line
        # goes to manual phase 3. Supported, but the slow path.
        warn ""
        warn "⚠ Shopping-list-from-photo has no Iris element provenance: phase 2's"
        warn "  SKU cache can't apply, so every line goes to manual phase 3 and no"
        warn "  SKUs are written back. For the fast path, shop from a meal plan or a"
        warn "  shopping-list View GUID instead."
        warn ""
        LIST_IMG="$(find_newest_image)"
        [ -n "$LIST_IMG" ] || fail "No .jpg/.jpeg/.png photo found in $(pwd). Drop this week's shopping-list photo here and re-run. (HEIC isn't supported — export as JPG.)"
        echo "  using newest image: $LIST_IMG"
        LIST_OCR_PROMPT="You are running headless as phase 1 of an automated weekly-shop pipeline. Read the shopping-list photo at the path '$LIST_IMG' with the Read tool and OCR it. Write the items as a clean Markdown bullet list to the file '$AGGREGATE_MD', one item per line in the form '- <name>: <quantity> <unit>' (omit the unit if none is written). Do NOT create anything in Iris. Print a one-line confirmation when the file is written."
        claude -p "$LIST_OCR_PROMPT" || fail "Phase 1 OCR step failed. Check the photo and your Claude setup."
        [ -s "$AGGREGATE_MD" ] || fail "Phase 1 OCR produced no shopping list at $AGGREGATE_MD."
        show_and_confirm "$AGGREGATE_MD" "Does this shopping list look right?" "Edit $AGGREGATE_MD"
    else
        # Route 2b: existing shopping-list View GUID (an aggregation_list
        # diagram). Exporting it renders the rolled-up list with provenance.
        read -r -p "Enter the Iris shopping-list View GUID: " LIST_DIAGRAM_ID
        is_guid "$LIST_DIAGRAM_ID" || fail "'$LIST_DIAGRAM_ID' doesn't look like an Iris GUID."
        echo "  rendering shopping-list View $LIST_DIAGRAM_ID…"
        if ! iris export diagram "$LIST_DIAGRAM_ID" --format md > "$AGGREGATE_MD" 2>/dev/null; then
            fail "iris export diagram $LIST_DIAGRAM_ID failed."
        fi
    fi
fi

[ -s "$AGGREGATE_MD" ] || fail "Phase 1 produced an empty shopping list ($AGGREGATE_MD)."
echo "  phase 1 → shopping list ready: $AGGREGATE_MD"

# ── Phase 2 — pure bash bulk-add ─────────────────────────────────────
bold ""
bold "Phase 2 — Bulk-adding cached SKUs (no LLM)"
"$SCRIPT_DIR/phase2_bulk_add.sh" --list-md "$AGGREGATE_MD" "$STATE_DIR"

ADDED=$(jq '.count' "$STATE_DIR/cart-result.json")
DEFERRED=$(jq '.count' "$STATE_DIR/exceptions.json")
echo "  phase 2 → added $ADDED items, $DEFERRED exceptions deferred"

# ── Phase 3 — conditional Claude session for exception resolution ────
if [ "$DEFERRED" -gt 0 ]; then
    bold ""
    bold "Phase 3 — Resolving $DEFERRED exception(s) with Claude + the skill"
    bold "  Spawning a fresh Claude session. The woolies-shopper skill"
    bold "  will be invoked to search, ask you about ambiguities, cart-add,"
    bold "  and write back any newly-discovered SKUs to Iris."

    PHASE3_PROMPT="Resolve these Woolworths shopping exceptions from a phased shop pipeline. The state dir is $STATE_DIR; the exceptions are in $STATE_DIR/exceptions.json. Use the woolies-shopper skill (it has been re-scoped in v0.2.0 to handle exactly this case). For each exception: search woolies for the item, pick a SKU (use scripts/pick.py if helpful), ask me about ambiguous picks or out-of-stock substitutions, cart-add the chosen SKU, and write the newly-discovered SKU back to the corresponding Product attribute's notes on the Ingredient element via iris update element. Element ids and quantities are in the exceptions.json file. When done, append the resolution log to $STATE_DIR/phase3-result.json."

    claude -p "$PHASE3_PROMPT" || warn "Phase 3 Claude session exited non-zero — check $STATE_DIR for partial state."
else
    bold ""
    bold "Phase 3 — Skipped (no exceptions)."
fi

# ── Summary ──────────────────────────────────────────────────────────
bold ""
bold "════════════════════════════════════════════════════════════════"
bold "  Done. Your Woolworths trolley is populated."
bold "  → Open https://www.woolworths.co.nz to review and submit."
bold "  State + logs: $STATE_DIR"
bold "════════════════════════════════════════════════════════════════"
