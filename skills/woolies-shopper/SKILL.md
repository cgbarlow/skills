---
name: woolies-shopper
description: Resolve exceptions in a Woolworths NZ online grocery workflow — handle out-of-stock items, find SKUs for newly-added grocery items, and write resolved SKUs back to the Product attribute notes of Iris Ingredient elements so the next shop hits the cache. Triggered automatically by `shop.sh` phase 3 when the bash bulk-add can't resolve a line; also triggers directly when the user asks to "find a Woolies SKU for this ingredient", "deal with this out-of-stock item", "find a substitute for X at Woolworths", or "resolve these woolies shopping exceptions". For the full weekly shop, the user should run `./scripts/shop.sh` from the terminal — this skill is the exception resolver, not the orchestrator. If the user asks to "do the shopping" or similar generic phrasing in a bare Claude session, point them at `shop.sh` first; only invoke this skill directly when they're explicitly working on exceptions or a single SKU lookup.
---

# woolies-shopper (v0.3.0 — exception resolver)

The narrow job of this skill: take one or more Woolworths shopping exceptions — an item that couldn't be cart-added by the deterministic bash bulk-add phase — and resolve each one by searching, picking, asking the user when needed, cart-adding, and writing the resolved SKU back to the Iris element's `Products` attribute notes for next time.

**This skill is NOT the entry point for the full weekly shop.** That's `./scripts/shop.sh` in the same skill directory — a master bash orchestrator that runs three phases: (1) shopping-list source — either a Claude Code session that turns a meal-plan photo into a combined smart_markdown shopping list (then pauses for the user to review and tick off items they already have), or a GUID the user supplies for an existing list; (2) pure-bash bulk-add that reads the list's `data.markdown_source`, processes the un-ticked `{{element:UUID:name}}` items, and cart-adds those with a cached SKU; (3) this skill for exception resolution. If a user types "do my Woolies shop" into a bare Claude session, your first reply should point them at `shop.sh` from the terminal rather than running the whole workflow inside Claude — the orchestrator is faster and cheaper.

The exception payload `shop.sh` hands you (in phase 3) looks like:

```json
{
  "exceptions": [
    {"reason": "no_cached_sku",     "name": "Carrots",     "element_id": "33333333-...", "quantity": 0.7, "unit": "Kilogram", "search": "Carrot Loose"},
    {"reason": "cached_sku_failed", "name": "Pork mince",  "element_id": "22222222-...", "quantity": 3,   "unit": "Each",     "search": "Woolworths Pork Mince 500g"},
    {"reason": "no_product_attr",   "name": "Mystery item","element_id": "44444444-...", "quantity": 1,   "unit": "Each",     "search": "Mystery item"}
  ],
  "count": 3
}
```

Each exception carries a `search` hint — the element's `Preferred product` type, else its `Products` type, else its name — which is the best string to search Woolworths with. The reason codes are:

- **`no_cached_sku`** — the element has a `Products` attribute but its notes hold no `woolies:NNN`. The common first-run case. Search, pick, cart-add, then cache the SKU (below).
- **`cached_sku_failed`** — a cached SKU existed but Woolworths rejected it (out of stock / discontinued). Find a replacement, cart-add, and overwrite the cached SKU.
- **`no_product_attr`** — the element has no `Products` attribute at all. Resolve the SKU, then add a `Products` attribute (with the SKU in its notes) via `iris update element`.
- **`element_fetch_failed`** — `iris elements get` failed for that element_id. Surface to the user; usually transient.

## Hosts

This skill runs in **Claude Code** when invoked by `shop.sh` phase 3 (the master script spawns an interactive `claude "…"` session — not `claude -p`, because the skill needs a TTY to ask you about ambiguous/out-of-stock picks). It can also run in **Claude Cowork** if the user invokes it manually for a one-off SKU lookup. Claude Desktop (chat-only) is not supported — the skill shells out to the local `iris` and `woolies` CLIs.

## Preflight

Run `./scripts/doctor.sh` first if you haven't been invoked by `shop.sh` (which has already done its own preflight). The doctor emits one JSON line:

- `{"ok": true, ...}` — continue.
- `{"reason": "not_installed", ...}` — instruct the user to run `./scripts/install.sh`.
- `{"reason": "not_logged_in", ...}` — instruct the user to run `woolies login` (interactive, ~25 s).
- `{"reason": "doctor_reported_problem", ...}` — surface the `hint` verbatim.

The `iris` CLI just needs to be pointed at the **right backend** — no login required. The shopping-list diagram and ingredient elements are readable anonymously, so the core shop works with the CLI unauthenticated; it only needs the correct `url`.

The trap is the default: with no `--url` flag, no `IRIS_URL` env, and no `url` in `~/.config/iris/config.toml`, the CLI falls through to `http://localhost:8000`, which has none of the user's data (so every lookup 404s). `shop.sh`'s preflight handles this automatically — if the CLI would resolve to that localhost default, it exports `IRIS_URL=$DEFAULT_IRIS_URL` (default `https://iris-api-gtb3.onrender.com` — the iris-api host, **not** the SvelteKit frontend `iris-uat.chrisbarlow.nz`, whose `/api` path serves HTML). Override by exporting `IRIS_URL` or setting `url` in config.toml.

**Auth is optional and only affects the writeback step.** Anonymous sessions can read everything but cannot write, so the SKU cache writeback (refreshing `confirmed:` dates / persisting new SKUs) is silently skipped (`iris_attr_update … || true`). To enable writeback, put a token in `IRIS_TOKEN` (it overrides any token in `~/.config/iris/config.toml`). This deployment runs in **Supabase mode**, where auth is awkward: password `iris login` is disabled (`/api/auth/login` → 404), and the PAT path currently **500s server-side** (a backend bug — it should 401 on a bad token, not crash). The working path is a **Supabase session JWT**: run `source scripts/iris-auth.sh` (password once, then refresh-token reuse) to fetch one and export `IRIS_TOKEN`. Verify a writeback end-to-end with `./scripts/test-writeback.sh <element_id>` (snapshots → writes a test SKU → verifies → restores).

## Resolving each exception

For each entry in the exceptions payload:

### 1. Search Woolworths

Use the exception's `search` hint (the `Preferred product` type → `Products` type → name), not just the bare name — it's usually the exact product:

```bash
woolies search "<exception.search>" --json --limit 5
```

### 2. Pick the best SKU

Pipe the search output to `scripts/pick.py`:

```bash
woolies search "<exception.search>" --json --limit 5 | \
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

### 4. Write back to Iris

After a successful cart-add, write the SKU back so the next shop hits the cache. The SKU is a property of the individual product, so the cache lives in the element's **`Products`** attribute notes. The **`Preferred product`** attribute is a name-only pointer (its `type` names the chosen product, used for the search hint) and must **not** carry the SKU. The shared helper in `scripts/lib/iris_attr_update.sh` does the get-merge-put dance against the `iris` CLI:

```bash
source scripts/lib/iris_attr_update.sh

NEW_NOTES="woolies:${sku} | confirmed:$(date +%Y-%m-%d)"

# Write to the first "Products" attribute row (index 0).
iris_attr_update "$element_id" "Products" 0 "$NEW_NOTES"
```

The reasons require slightly different handling:

- **`no_cached_sku`** — a `Products` attribute exists with empty notes. Resolve the SKU and write it to that row (index 0). Steady-state first-run case.
- **`cached_sku_failed`** — the cached SKU was rejected (OOS / discontinued). Resolve a replacement and **overwrite** the `Products` notes with the new SKU (the old one is dead).
- **`no_product_attr`** — the element has no `Products` attribute. Add one carrying the resolved SKU: `iris elements get` the element, append `{"name":"Products","type":"<product name>","notes":"woolies:NNN | confirmed:DATE","scope":"Public","lower_bound":"","upper_bound":""}` to `data.attributes`, and `iris update element <id> --data-json <data>`.
- **`element_fetch_failed`** — surface to the user; you can still cart-add but can't write back until the element is reachable.

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
- `tests/test_phase2.sh` covers the bash phase 2 against the smart_markdown format: cache hit, `cached_sku_failed`, `no_cached_sku`, `no_product_attr`, ticked-line skip, and quantity parsing (`2 {{el}}` → 2 Each, `700 g` → 0.7 Kilogram). Fixtures live in `tests/fixtures/` (`diagram-export.json` + `element-*.json`); the mock CLIs are in `tests/mock-bin/`. Add new cases there in red→green order.
- The quantity parser is best-effort over free-text (`x N`, `N cans`, `N whole`, `N g`); the human reviews the trolley at woolworths.co.nz, so a mis-parsed qty is caught there, not silently shipped.
- Multi-retailer is out of scope today but the notes convention is forward-compatible: `woolies:NNN | paknsave:MMM | confirmed:YYYY-MM-DD` would be the natural extension.
