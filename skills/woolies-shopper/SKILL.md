---
name: woolies-shopper
description: Resolve exceptions in a Woolworths NZ online grocery workflow — handle out-of-stock items, find SKUs for newly-added grocery items, and write resolved SKUs back to the Product attribute notes of Iris Ingredient elements so the next shop hits the cache. Triggered automatically by `shop.sh` phase 3 when the bash bulk-add can't resolve a line; also triggers directly when the user asks to "find a Woolies SKU for this ingredient", "deal with this out-of-stock item", "find a substitute for X at Woolworths", or "resolve these woolies shopping exceptions". For the full weekly shop, the user should run `./scripts/shop.sh` from the terminal — this skill is the exception resolver, not the orchestrator. If the user asks to "do the shopping" or similar generic phrasing in a bare Claude session, point them at `shop.sh` first; only invoke this skill directly when they're explicitly working on exceptions or a single SKU lookup.
---

# woolies-shopper (v0.2.0 — exception resolver)

The narrow job of this skill: take one or more Woolworths shopping exceptions — a line that couldn't be cart-added by the deterministic bash bulk-add phase — and resolve each one by searching, picking, asking the user when needed, cart-adding, and writing the resolved SKU back to the Iris Ingredient element's Product attribute notes for next time.

**This skill is NOT the entry point for the full weekly shop.** That's `./scripts/shop.sh` in the same skill directory — a master bash orchestrator that runs three phases: (1) Claude Code session for OCR + meal plan + aggregation, (2) pure-bash bulk-add against cached SKUs, (3) this skill for exception resolution. If a user types "do my Woolies shop" into a bare Claude session, your first reply should point them at `shop.sh` from the terminal rather than running the whole workflow inside Claude — the orchestrator is faster and cheaper.

The exception payload `shop.sh` hands you (in phase 3) looks like:

```json
{
  "exceptions": [
    {"reason": "all_cached_skus_failed", "name": "Carrots", "element_id": "33333333-...", "quantity": 3, "unit": "Each"},
    {"reason": "no_products", "name": "Unknown thing", "element_id": "44444444-...", "quantity": 1, "unit": "Each"},
    {"reason": "no_provenance", "name": "Mystery item", "element_id": "", "quantity": 1, "unit": "Each"}
  ],
  "count": 3
}
```

## Hosts

This skill runs in **Claude Code** when invoked by `shop.sh` phase 3 (the master script spawns `claude -p "…"` with the exception payload). It can also run in **Claude Cowork** if the user invokes it manually for a one-off SKU lookup. Claude Desktop (chat-only) is not supported — the skill shells out to the local `iris` and `woolies` CLIs.

## Preflight

Run `./scripts/doctor.sh` first if you haven't been invoked by `shop.sh` (which has already done its own preflight). The doctor emits one JSON line:

- `{"ok": true, ...}` — continue.
- `{"reason": "not_installed", ...}` — instruct the user to run `./scripts/install.sh`.
- `{"reason": "not_logged_in", ...}` — instruct the user to run `woolies login` (interactive, ~25 s).
- `{"reason": "doctor_reported_problem", ...}` — surface the `hint` verbatim.

You also need the `iris` CLI authenticated for the SKU writeback step — `iris whoami` should succeed. If not, ask the user to run `iris login`.

## Resolving each exception

For each entry in the exceptions payload:

### 1. Search Woolworths

```bash
woolies search "<exception.name>" --json --limit 5
```

### 2. Pick the best SKU

Pipe the search output to `scripts/pick.py`:

```bash
woolies search "<name>" --json --limit 5 | \
  python3 scripts/pick.py --want '{"qty": <quantity>, "unit": "<unit>", "size_hint": "...", "brand_hint": "..."}'
```

The picker returns one of four shapes (unchanged from v0.1.0):

- `{"sku": ..., "name": ..., "size": ..., "quantity": ..., "unit": ...}` — unambiguous winner. Use it.
- `{"ambiguous": true, "candidates": [...]}` — ask the user via `AskUserQuestion`, present the top candidates with size + price.
- `{"out_of_stock": true, "candidates": [...]}` — offer the user the top 2 OOS alternatives as substitutes, or skip the line.
- `{"no_matches": true}` — surface to the user, skip.

### 3. Cart-add

```bash
woolies cart add <sku> <quantity> --unit <Each|Kilogram>
```

### 4. Write back to Iris (NEW in v0.2.0)

After a successful cart-add, write the SKU back so the next shop hits the cache. The shared helper in `scripts/lib/iris_attr_update.sh` does the get-merge-put dance against the `iris` CLI:

```bash
source scripts/lib/iris_attr_update.sh

# Append to the Product attribute notes: "woolies:NNN | confirmed:YYYY-MM-DD"
# If the exception has no element_id (reason=no_provenance) you cannot write
# back — surface that to the user as a known limitation.

NEW_NOTES="woolies:${sku} | confirmed:$(date +%Y-%m-%d)"

# product_idx is which Product attribute row to write to. For reason=no_products
# the user needs to add a Product attribute to the Ingredient element first
# (via the Iris UI or `iris update element`) before you can write the SKU.

iris_attr_update "$element_id" "Product" "$product_idx" "$NEW_NOTES"
```

Three reasons require different handling:

- **`all_cached_skus_failed`** — Product attribute rows exist but their cached SKUs all returned OOS/404. After resolving with a fresh SKU, decide with the user: replace the SKU on the preferred Product row (most common — old SKU was discontinued), or add a NEW Product row for the substitute (user wants both as alternates). Default to replace-preferred unless the user indicates otherwise.
- **`no_products`** — the Ingredient element has no Product attribute at all. Ask the user to add one with the resolved SKU in its notes. The skill can do this for them via `iris update element` (full element data with the new Product row appended).
- **`no_provenance`** — the aggregate line had no HTML-comment element_id (graceful-degradation path; the upstream aggregation profile didn't have `include_provenance: true`). You can resolve the cart-add but cannot write back, because you don't know which Ingredient element produced the line. Tell the user this is a known limitation and recommend flipping `include_provenance: true` on their shopping-list aggregation profile in Iris.

### 5. Append to phase 3 result log

When invoked by `shop.sh`, write each resolved exception (sku, name, quantity, unit, action taken — added / substituted / skipped) to `$STATE_DIR/phase3-result.json` so the master script can roll the summary up.

## Summary at the end

After all exceptions are resolved, run `woolies cart list --json` and render a compact table for the user showing the full final cart. End with: "**Open https://www.woolworths.co.nz in your browser to review and submit the order.**" The skill never attempts checkout — that's a human-eyeballs-then-clicks-Submit step.

## Failure modes worth knowing (unchanged from v0.1.0)

- Camoufox binary missing → `woolies login` downloads it on first run (~30–60 s).
- Session expired → 401 from Woolies API. Run `woolies login` again. Cookies normally persist for weeks.
- Akamai blocking → set `WOOLIES_PROXY=http://...` env var to route through a proxy.
- Boosts / loyalty specials → upstream CLI doesn't expose these yet; the skill silently skips them.
- Disclaimer: automated access may violate Woolworths' ToS. Use a dedicated Woolies account for frequent automated runs.

## Notes for future iteration

- `tests/test_pick.py` remains the behavioural spec for the picker (10 cases, unchanged).
- `tests/test_phase2.sh` covers the bash phase 2 (4 reason codes + cache-hit, fallback, no-cache, no-products, no-provenance paths). Add new cases there in red→green order.
- Multi-retailer is out of scope today but the notes convention is forward-compatible: `woolies:NNN | paknsave:MMM | confirmed:YYYY-MM-DD` would be the natural extension.
