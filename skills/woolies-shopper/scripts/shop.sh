#!/usr/bin/env bash
# Master orchestrator for the weekly Woolworths NZ online shop.
#
# Three phases:
#   1. Shopping-list source — two paths:
#        (a) Photo: an interactive `claude` session where the user
#            uploads a photo of the meal plan; Claude OCRs it and
#            creates the meal plan + aggregated shopping list in Iris
#            via the Iris MCP, emitting the resulting diagram_id.
#        (b) GUID: the user already has an aggregated shopping-list
#            diagram in Iris and supplies its GUID directly, skipping
#            the photo/OCR step. Set non-interactively with
#            SHOP_DIAGRAM_ID, or chosen from the startup menu.
#      Either way the chosen diagram_id is written to
#      $STATE_DIR/diagram-id and handed to phase 2.
#   2. Pure bash (`phase2_bulk_add.sh`): walks the aggregated list,
#      uses cached SKUs from each Ingredient's Product attribute notes
#      to bulk-add to the user's Woolies trolley. Refreshes the
#      confirmed: date on each Product attribute on success. Anything
#      that can't be resolved gets pushed to $STATE_DIR/exceptions.json.
#   3. Conditional interactive `claude` session: only if
#      exceptions.json is non-empty. Invokes the woolies-shopper skill
#      (now scoped as the exception resolver in v0.2.0) to search,
#      ask the user about ambiguities, cart-add, and write any newly-
#      discovered SKUs back to Iris via `iris update element`.
#
# User then opens woolworths.co.nz in a browser to review the trolley
# and submit the order. shop.sh stops at trolley-populated.
#
# Usage:
#   ./shop.sh              # runs the full pipeline (prompts for source)
#   SHOP_STATE_DIR=...     # override the manifest directory
#   SHOP_DIAGRAM_ID=<guid> # skip the photo/OCR step and bulk-add
#                          # straight from an existing shopping-list diagram
#
# Requires: claude CLI, iris CLI (authenticated), woolies CLI
# (logged in), jq, bash 4+. Run scripts/install.sh and `iris login`
# once before first use.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

STATE_DIR="${SHOP_STATE_DIR:-/tmp/shop-$(date +%Y-%m-%d-%H%M%S)}"
mkdir -p "$STATE_DIR"

# iris-api backend the shopping-list diagram + ingredient elements live on.
# The shopping-list content is readable anonymously, so no login is needed for
# the core shop — we only need the CLI pointed at the right host. Override by
# exporting IRIS_URL, or by setting url in ~/.config/iris/config.toml; this
# default is used only when neither is set (i.e. the CLI would otherwise fall
# through to its http://localhost:8000 default, which has none of your data).
DEFAULT_IRIS_URL="${DEFAULT_IRIS_URL:-https://iris-api-gtb3.onrender.com}"

# Iris frontend (SvelteKit) base URL — used only to build a human review link
# to the shopping-list diagram. This is the frontend host, NOT the iris-api
# backend above. Override with IRIS_FRONTEND_URL.
IRIS_FRONTEND_URL="${IRIS_FRONTEND_URL:-https://iris-uat.chrisbarlow.nz}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
fail() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

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
# Probe + classify the iris session, then default the backend URL if needed.
#
# `iris --json whoami` returns DIFFERENT shapes:
#   • authenticated: {"id","username","role","is_active",…}   (NO "anonymous"/"url")
#   • anonymous:     {"anonymous": true, "url": "…"}
#   • rejected/error: non-JSON or empty (bad PAT → HTTP 500, server down, etc.)
# So we classify by the presence of `.username`, NOT by `.anonymous == false`.
#
# The CLI defaults to http://localhost:8000 when nothing configures a url — and
# that empty local backend 404s everything. If we land there (anonymous on
# localhost, no IRIS_URL set), repoint at DEFAULT_IRIS_URL and re-probe. We
# export IRIS_URL so phases 1–3 inherit it; an explicit IRIS_URL/config url is
# left untouched. Every `iris` call tolerates a non-zero exit (`|| true`) so a
# failing whoami can't abort shop.sh under `set -e`/`pipefail`.
_iris_probe() { IRIS_WHOAMI=$(iris --json whoami 2>/dev/null || true); }
_iris_field() { printf '%s' "$IRIS_WHOAMI" | jq -r "$1 // empty" 2>/dev/null || true; }

_iris_probe
if [ "$(_iris_field '.anonymous')" = "true" ] \
   && [ "$(_iris_field '.url')" = "http://localhost:8000" ] \
   && [ -z "${IRIS_URL:-}" ]; then
    export IRIS_URL="$DEFAULT_IRIS_URL"
    _iris_probe
fi

IRIS_USER=$(_iris_field '.username')
IRIS_ANON=$(_iris_field '.anonymous')
IRIS_URL_RESOLVED=$(_iris_field '.url')
[ -n "$IRIS_URL_RESOLVED" ] || IRIS_URL_RESOLVED="${IRIS_URL:-$DEFAULT_IRIS_URL}"

if [ -n "$IRIS_USER" ]; then
    echo "  iris:    ok ($IRIS_URL_RESOLVED, authenticated as $IRIS_USER)"
elif [ "$IRIS_ANON" = "true" ]; then
    echo "  iris:    ok ($IRIS_URL_RESOLVED, anonymous — read-only)"
    warn "  Note: anonymous session — the SKU cache writeback will be skipped."
    warn "  To enable writeback, run:  source scripts/iris-auth.sh"
else
    warn "iris \`whoami\` failed against $IRIS_URL_RESOLVED (empty/non-JSON response)."
    warn "  Likely a rejected token (a bad PAT in ~/.config/iris/config.toml 500s every"
    warn "  request) or the backend is unreachable. Fix EITHER by:"
    warn "    • authenticating cleanly:  source scripts/iris-auth.sh"
    warn "    • or removing the \`token = \"…\"\` line from ~/.config/iris/config.toml"
    warn "      (falls back to anonymous read-only — the shop still works)."
    fail "iris CLI session unusable. Resolve the above, then re-run shop.sh."
fi

if ! command -v claude >/dev/null 2>&1; then
    fail "claude CLI not found. Install Claude Code from https://claude.com/claude-code"
fi
echo "  claude:  ok"

for tool in jq awk; do
    command -v "$tool" >/dev/null 2>&1 || fail "$tool is required and not on PATH."
done
echo "  jq/awk:  ok"

# ── Phase 1 — shopping-list source: photo (OCR) or an existing GUID ───
#
# Two ways to get the aggregated shopping-list diagram_id that phase 2
# consumes:
#   (a) Photo path — spawn an interactive Claude session to OCR a meal
#       plan and aggregate it in Iris (the original behaviour).
#   (b) GUID path — the user already aggregated a shopping list in Iris
#       and just hands us its diagram GUID, skipping OCR entirely.
# The GUID is validated against Iris with `iris diagrams get` before we
# commit to it, so a typo'd or non-existent id fails here, not in phase 2.

# A diagram GUID is a standard UUID.
is_uuid() {
    [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

# Validate that a diagram GUID is well-formed and resolves in Iris.
# Exits (via fail) with a clear message if not.
validate_diagram_id() {
    local id="$1"
    is_uuid "$id" || fail "\"$id\" is not a valid diagram GUID (expected a UUID)."
    if ! iris diagrams get "$id" >/dev/null 2>&1; then
        fail "Iris has no diagram with GUID $id (check the id, or that you're logged into the right Iris)."
    fi
}

DIAGRAM_ID=""

# Non-interactive override: SHOP_DIAGRAM_ID short-circuits the whole
# source menu and the photo/OCR step.
if [ -n "${SHOP_DIAGRAM_ID:-}" ]; then
    bold ""
    bold "Phase 1 — Using shopping-list GUID from SHOP_DIAGRAM_ID (skipping photo OCR)"
    validate_diagram_id "$SHOP_DIAGRAM_ID"
    DIAGRAM_ID="$SHOP_DIAGRAM_ID"
    echo "  phase 1 → diagram_id: $DIAGRAM_ID (from SHOP_DIAGRAM_ID)"
else
    bold ""
    bold "Phase 1 — Shopping-list source"
    bold "  1) Photo — upload a meal-plan photo; Claude builds the combined"
    bold "     shopping list in Iris, then you review it (interactive)."
    bold "  2) GUID  — paste the GUID of a shopping-list diagram you already"
    bold "     have in Iris (skips photo + review — the GUID is your confirmation)."
    bold ""
    read -r -p "Choose source [1/2] (default 1): " SOURCE_CHOICE
    SOURCE_CHOICE="${SOURCE_CHOICE:-1}"

    case "$SOURCE_CHOICE" in
        2)
            # GUID path — prompt (and re-prompt) until we get a valid,
            # resolvable diagram GUID.
            while [ -z "$DIAGRAM_ID" ]; do
                read -r -p "Enter the Iris shopping-list diagram GUID: " ENTERED_ID
                ENTERED_ID="${ENTERED_ID// /}"
                [ -z "$ENTERED_ID" ] && { warn "No GUID entered."; continue; }
                if ! is_uuid "$ENTERED_ID"; then
                    warn "\"$ENTERED_ID\" is not a valid UUID — try again."
                    continue
                fi
                if ! iris diagrams get "$ENTERED_ID" >/dev/null 2>&1; then
                    warn "Iris has no diagram with GUID $ENTERED_ID — try again."
                    continue
                fi
                DIAGRAM_ID="$ENTERED_ID"
            done
            echo "  phase 1 → diagram_id: $DIAGRAM_ID (from GUID)"
            ;;
        1)
            # Photo path — interactive Claude session generates the combined
            # smart_markdown shopping list (meal plan + recurring list) and
            # prints its id on a DIAGRAM_ID= line.
            bold ""
            bold "  An interactive Claude Code session will start now. Upload your"
            bold "  weekly meal-plan photo when prompted. Claude will OCR it, build"
            bold "  the combined shopping list in Iris (merging your recurring list),"
            bold "  and print the resulting diagram id on a line beginning with"
            bold "  DIAGRAM_ID=  — then type /exit."
            bold ""
            read -r -p "Press Enter to start the Claude session…" _

            PHASE1_TRANSCRIPT="$STATE_DIR/phase1-transcript.txt"
            # Spawn claude interactively; the session uses the Iris MCP if configured.
            # We tee the session output so we can grep for DIAGRAM_ID= afterwards.
            claude 2>&1 | tee "$PHASE1_TRANSCRIPT" || true

            DIAGRAM_ID=$(grep -oE '^DIAGRAM_ID=[0-9a-fA-F-]+' "$PHASE1_TRANSCRIPT" | tail -1 | cut -d= -f2)
            if [ -z "$DIAGRAM_ID" ]; then
                fail "Phase 1 did not emit a DIAGRAM_ID= line. Check $PHASE1_TRANSCRIPT."
            fi
            echo "  phase 1 → diagram_id: $DIAGRAM_ID (from photo)"

            # Review gate: the freshly-generated list needs a human check before
            # we add anything to the trolley. The user opens the list, confirms
            # it's right, and ticks off (checklist mode) anything already on hand
            # — phase 2 then processes only the UN-ticked items. The GUID path
            # skips this: supplying a GUID is itself the confirmation.
            bold ""
            bold "  Review your shopping list before we add to the trolley:"
            bold "    ${IRIS_FRONTEND_URL}/views/${DIAGRAM_ID}"
            bold "  Check it's correct, and tick off (✓) anything you already have."
            bold "  Phase 2 will buy only the items left un-ticked."
            bold ""
            read -r -p "Press Enter when you've reviewed the list and are ready to continue…" _
            ;;
        *)
            fail "Unknown source choice \"$SOURCE_CHOICE\" — expected 1 (photo) or 2 (GUID)."
            ;;
    esac
fi

echo "$DIAGRAM_ID" > "$STATE_DIR/diagram-id"

# ── Phase 2 — pure bash bulk-add ─────────────────────────────────────
bold ""
bold "Phase 2 — Bulk-adding cached SKUs (no LLM)"
"$SCRIPT_DIR/phase2_bulk_add.sh" "$DIAGRAM_ID" "$STATE_DIR"

ADDED=$(jq '.count' "$STATE_DIR/cart-result.json")
DEFERRED=$(jq '.count' "$STATE_DIR/exceptions.json")
echo "  phase 2 → added $ADDED items, $DEFERRED exceptions deferred"

# ── Phase 3 — conditional Claude session for exception resolution ────
# This MUST be an interactive Claude session (NOT `claude -p`): the skill asks
# you about ambiguous picks / out-of-stock substitutions via AskUserQuestion,
# which needs a TTY. `claude -p` is headless — it would run invisibly and be
# unable to ask anything. `claude "<prompt>"` (no -p) starts an interactive
# session seeded with the prompt, inheriting this terminal so you see + answer.
if [ "$DEFERRED" -gt 0 ]; then
    bold ""
    bold "Phase 3 — Resolving $DEFERRED exception(s) with Claude + the skill"
    bold "  An interactive Claude session will start now. The woolies-shopper"
    bold "  skill will search Woolworths, ask you about ambiguous or out-of-stock"
    bold "  picks, cart-add, and cache the resolved SKUs back to Iris."
    bold "  Type /exit when it's finished."
    bold ""
    read -r -p "Press Enter to start the Claude session…" _

    PHASE3_PROMPT="Resolve these Woolworths shopping exceptions from a phased shop pipeline. The state dir is $STATE_DIR; the exceptions are in $STATE_DIR/exceptions.json. Use the woolies-shopper skill. For each exception: search Woolworths using the exception's \"search\" hint (fall back to its name), pick a SKU (use scripts/pick.py if helpful), ask me about ambiguous picks or out-of-stock substitutions, cart-add the chosen SKU, and write the newly-discovered SKU back to the element's \"Preferred product\" attribute notes via the iris CLI (scripts/lib/iris_attr_update.sh). Element ids, quantities, units and search hints are all in the exceptions.json file. When done, append the resolution log to $STATE_DIR/phase3-result.json and print a summary."

    claude "$PHASE3_PROMPT" || warn "Phase 3 Claude session exited non-zero — check $STATE_DIR for partial state."
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
