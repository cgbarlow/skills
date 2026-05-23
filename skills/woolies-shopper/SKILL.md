---
name: woolies-shopper
description: Do the weekly Woolworths NZ online grocery shop. Reads an aggregated shopping list from the Iris MCP server, then drives the local `woolies` CLI (https://github.com/mcinteerj/woolies-nz-cli) to populate a Woolworths NZ trolley for the user to review and submit in the browser. Use this whenever the user asks to "do the shopping", "shop from a meal plan", "fill the Woolies cart", "build a Woolworths order", or refers to a Woolies / Woolworths NZ / Countdown-NZ online shop, even if they don't explicitly name this skill. Pairs with the Iris meal-plan + `aggregate` workflow; this skill is the cart-builder step that replaces the slow Chrome-extension approach.
---

# woolies-shopper

Drive the weekly grocery shop end-to-end: pull an aggregated shopping list out of Iris via the Iris MCP server, find the right Woolworths NZ SKUs for each line, add them to the user's trolley via the local `woolies` CLI, and hand the user back a populated trolley to review and submit in their browser.

This skill **does not place the order**. It stops at "trolley populated"; the user opens woolworths.co.nz and clicks the final Submit themselves. That boundary is deliberate — a human eyeballs the final cart before any money moves.

## Hosts

- **Claude Cowork** is the primary host. Cowork's desktop UX + `/schedule` for cadence-based runs is the natural fit for a weekly task.
- **Claude Code** runs the same skill unchanged. Use it when the user prefers the terminal.
- Claude Desktop (chat-only) is **not** a supported host — it can't shell out to the local CLI.

## Preflight (always run first)

1. Run `./scripts/doctor.sh`. It emits one JSON line; parse it.
2. If `ok: true` — continue to step "Locate the shopping list".
3. If `reason: "not_installed"` — walk the user through `./scripts/install.sh`. The script is idempotent and never sudos; if it needs system libraries it prints the exact apt/dnf command and exits 2 so the user can run it themselves.
4. If `reason: "not_logged_in"` — ask the user to run `woolies login` (interactive, ~25 s; spawns a Camoufox browser the first time and downloads a ~300 MB binary on first invocation). Then re-run doctor.
5. If `reason: "doctor_reported_problem"` — surface the `hint` to the user verbatim. Most common cause is a Woolworths-side selector change; the upstream CLI's README has the troubleshooting matrix.

## Locate the shopping list (Iris MCP)

The shopping list lives in Iris as the markdown body of an aggregated diagram produced by `iris aggregate` (or by the `aggregate` Iris MCP tool). Two ways to find it:

- **The user gave you a diagram id.** Call the Iris MCP `get_diagram` tool with that id.
- **The user said "use the current meal plan" or similar.** Ask which Iris set holds their meal plans (use `list_collections` / `list_sets` if needed), then `list_diagrams` filtered to that set, sorted by `updated_at`. The most recent aggregated shopping-list diagram (data shape `{"content": "<markdown>"}`) is the target.

Confirm the diagram name with the user before processing it, especially if you had to disambiguate.

## Parse the aggregated list

The aggregated markdown is a flat list of items. Each line has been deduplicated and summed by `iris aggregate`. Expect lines roughly like:

```
- Pork mince — 1kg
- Chilli beans (Watties Mild) — 2 × 420g
- Carrots — 3
- Milk (Anchor) — 2L
```

Extract `(name, qty, unit, optional brand, optional size)` tuples. The parser doesn't need to be exhaustive — if a line is ambiguous, leave it for the user to confirm at the picking step.

Map units sensibly to the picker's two-valued unit:

- `kg`, `g`, `l`, `ml` → `unit: "Kilogram"` (convert g → kg, ml → l if applicable); `qty` is the numeric magnitude in the larger unit.
- bare count, `each`, `× N`, `pcs` → `unit: "Each"`.

Anything you can't parse, ask the user.

## Search + pick (per line)

For each parsed item, run two commands:

```bash
woolies search "<name>" --json --limit 5
```

Pipe its stdout to:

```bash
python3 scripts/pick.py --want '{"qty": N, "unit": "Each|Kilogram", "size_hint": "...", "brand_hint": "..."}'
```

The picker handles the ranking rules (in-stock filter, size match, brand preference, dual-priced loose produce → loose, cup-price tiebreak with a 10 % ambiguity threshold). It returns one of four shapes:

- **`{"sku", "name", "size", "quantity", "unit"}`** — unambiguous winner. Add it directly.
- **`{"ambiguous": true, "candidates": [...]}`** — top candidates are close enough that the user should pick. Show them via `AskUserQuestion` (Cowork/Claude Code both support it) and proceed with their choice.
- **`{"out_of_stock": true, "candidates": [...]}`** — no in-stock match. Offer the user the top 2 candidates as a substitution, or skip.
- **`{"no_matches": true}`** — the search returned nothing. Tell the user and skip the line.

Default behaviour is to **ask on stock-out** rather than auto-substitute. The user can override this for a hands-off run.

## Cart add

For each successful pick:

```bash
woolies cart add <sku> <qty> --unit <Each|Kilogram>
```

`--unit Kilogram` is only valid for products that support dual pricing (loose produce). The picker only returns `unit: "Kilogram"` when that's actually the case, so trust it.

Group cart-add invocations and keep a running tally: `added`, `skipped`, `substituted`, `out_of_stock`, `ambiguous_resolved_by_user`.

## Summary

When the list is exhausted:

```bash
woolies cart list --json
```

Render a compact table for the user:

| Item | SKU | Size | Qty | Unit | Status |

with one row per shopping-list line. Items that were substituted carry both the original and the chosen SKU. Items that were skipped or out of stock are marked clearly.

End by telling the user to **open woolworths.co.nz in a browser to review the trolley and submit the order.** Do not attempt to drive checkout, payment, or delivery-slot selection — those stay with the human.

## Scheduling (Cowork only)

If the user wants to run this on a cadence ("every Saturday at 8 am"), point them at Cowork's `/schedule` command. The skill itself doesn't manage a schedule — that's a Cowork-level concern. A scheduled invocation should provide the meal-plan diagram id (or a "find the diagram tagged X" instruction) so the skill knows which list to consume without prompting.

## Failure modes worth knowing

- **Camoufox binary missing** — `woolies login` will download it (~300 MB, ~30–60 s). If it fails, the upstream CLI's `README.md` has a troubleshooting table. Surface the error verbatim.
- **Session expired** — appears as a 401 from the upstream API mid-run. `woolies login` again. Cookies persist for several weeks normally.
- **Akamai blocking** — sometimes the upstream CLI gets fingerprinted out. The user can route through a proxy via `WOOLIES_PROXY=http://...` env var. Surface this to them and stop.
- **Boosts / loyalty specials** — the upstream CLI doesn't expose these as of v0.1.1. The skill silently skips them with a note in the summary. The user can pick them up manually before submitting.
- **Disclaimer** — Woolworths' ToS may prohibit automated access. Restate this on first-run, and recommend using a dedicated Woolies account if the user runs this often.

## Notes for future iteration

- `tests/test_pick.py` is the behavioural spec for `pick.py`. Add new ranking rules there first, in red/green/refactor order.
- The Iris MCP server is the only external dependency for the upstream half of the workflow; if the Iris connector isn't configured, ask the user to add it before running this skill.
- The picker handles **only** the search → SKU mapping. Anything more (taste preference learning, allergen rules, household-size scaling) should live in the Iris element-template stamps (the `Ingredient` template, ADR-212), not in this skill.
