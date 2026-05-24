#!/usr/bin/env bash
# Master orchestrator for the weekly Woolworths NZ online shop.
#
# Three phases:
#   1. Interactive `claude` session: user uploads a photo of the meal
#      plan; Claude OCRs it and creates the meal plan + aggregated
#      shopping list in Iris via the Iris MCP. Session writes the
#      resulting diagram_id to $STATE_DIR/diagram-id and exits.
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
#   ./shop.sh              # runs the full pipeline
#   SHOP_STATE_DIR=...     # override the manifest directory
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

# ── Phase 1 — interactive Claude session for OCR + meal plan + aggregate ──
bold ""
bold "Phase 1 — Photo → meal plan → aggregated shopping list"
bold "  An interactive Claude Code session will start now. Upload your"
bold "  weekly meal plan photo when prompted. Claude will OCR it, create"
bold "  the meal plan in Iris, run \`iris aggregate\`, and print the"
bold "  resulting diagram id on a line beginning with DIAGRAM_ID="
bold "  Type /exit when Claude has finished."
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
echo "$DIAGRAM_ID" > "$STATE_DIR/diagram-id"
echo "  phase 1 → diagram_id: $DIAGRAM_ID"

# ── Phase 2 — pure bash bulk-add ─────────────────────────────────────
bold ""
bold "Phase 2 — Bulk-adding cached SKUs (no LLM)"
"$SCRIPT_DIR/phase2_bulk_add.sh" "$DIAGRAM_ID" "$STATE_DIR"

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
