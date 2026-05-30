# woolies-shopper

A Claude skill + bash orchestrator that runs your weekly Woolworths NZ online grocery shop. Reads an aggregated shopping list from your [Iris](https://github.com/cgbarlow/iris) knowledge base via the Iris MCP server, then populates a Woolworths NZ trolley using the local [`woolies` CLI](https://github.com/mcinteerj/woolies-nz-cli). You review and submit the order yourself in the browser — the workflow stops at "trolley populated", deliberately.

**v0.2.0 architecture (May 2026)**: the workflow is now a three-phase bash pipeline (`scripts/shop.sh`) where the bulk-add phase runs LLM-free against cached SKUs. Only the OCR (phase 1) and exception-resolution (phase 3) phases call Claude, and only when needed.

## Entry point

```sh
./scripts/shop.sh
```

That's it. The script walks you through the phases. Run it from a regular terminal — no Claude Code session required (it spawns its own when needed).

## What happens

1. **Preflight** — checks `woolies` is installed and logged in, `iris` CLI is authenticated, and `jq` / `claude` are on PATH.
2. **Phase 1 — choose your input, produce the shopping list.** Two questions at run time:
   - **What** are you shopping from? **(1) Meal plan** — derive the list from a week's meals via Iris aggregation; or **(2) Shopping list** — use a list directly.
   - **Where** does it come from? **(1) Photo** — the **newest** `*.jpg`/`*.jpeg`/`*.png` in the current directory, OCR'd headlessly by `claude -p` (HEIC unsupported — export as JPG); or **(2) Iris View GUID** — an existing diagram already in Iris.

   The four combinations:
   | | Photo | Iris View GUID |
   |---|---|---|
   | **Meal plan** | OCR → confirm → match each meal to its existing Iris recipe (unmatched meals are listed and gated) → `iris aggregate` | `iris aggregate` against the meal-plan View |
   | **Shopping list** | OCR the list straight to markdown (⚠ no provenance → all of phase 2 falls to phase 3) | `iris export diagram` of the shopping-list View |

   Every path ends by writing `$STATE_DIR/aggregate.md` and pausing for a confirm/gate before phase 2. For meal-plan modes the aggregation profile is taken from `IRIS_SHOPPING_PROFILE_ID`, or auto-selected if you have only one, or chosen from a picker.
3. **Phase 2 (pure bash, ~30 s for a 30-item shop)** — reads the list, looks up each Ingredient element via the `iris` CLI, walks its Product attribute rows in preferred order, and for each Product with a cached `woolies:NNN` SKU in its notes, calls `woolies cart add`. Refreshes the `confirmed:YYYY-MM-DD` date on each Product attribute on success. Anything that can't be resolved (no cached SKU, all cached SKUs OOS, no Product attributes, no provenance) goes to `exceptions.json` for phase 3. Zero Claude tokens consumed.
4. **Phase 3 (headless `claude -p`, only if exceptions exist)** — spawns a fresh Claude session and invokes the woolies-shopper skill (the exception resolver). Claude searches Woolies for each unresolved item, picks via `scripts/pick.py`, asks you about ambiguous picks or out-of-stock substitutions, cart-adds, and writes any newly-discovered SKU back to the relevant Product attribute's notes so the next shop hits the cache.
5. **Summary** — tells you to open woolworths.co.nz to review and submit. State + logs live in `$SHOP_STATE_DIR` (default `/tmp/shop-<timestamp>/`).

## The cache

Each Iris Ingredient element has one or more **Product** attributes — one per real-world buyable variant. The skill writes resolved Woolworths SKUs into each Product's `notes` field using a parseable convention:

```
woolies:269671 | confirmed:2026-05-24
```

Phase 2 reads this convention to skip search entirely. Phase 3 maintains it (writes new SKUs after resolving exceptions; refreshes the `confirmed:` date on successful re-use). Steady state: weekly shops where most items are repeats run almost entirely in phase 2, with minimal phase 3 work.

The cache-hit fast path requires:
- Iris ≥ **v6.31.0** ([ADR-217](https://github.com/cgbarlow/iris/blob/main/docs/adrs/ADR-217-Aggregate-Output-Provenance.md)) — the aggregation engine emits `<!-- iris:element=<uuid> -->` HTML comments on each line when `include_provenance: true` is set on the aggregation profile.
- Your shopping-list aggregation profile to have `include_provenance: true`. Flip it in the Iris UI or via `iris aggregation-profile update`.

Without those, the orchestrator falls back gracefully: every line is treated as an exception and phase 3 handles them all. Slower but still works.

## First-time install

```sh
./scripts/install.sh
```

The installer:
- Checks Python 3.11+ is on PATH.
- Installs `woolies-nz-cli==0.1.1` via `pipx` (pulls `click`, `httpx`, `camoufox` transitively).
- On Linux, detects missing GTK/NSS/X11 system libs Camoufox needs at runtime. By default it **prints** the exact `apt`/`dnf` command for you to run yourself (the installer never sudos unless you opt in). Pass `--install-system-libs` (or set `WOOLIES_INSTALL_SYSTEM_LIBS=1`) to have it run `sudo apt`/`dnf` for you — kept off by default so non-interactive runs (e.g. `shop.sh` phase 1) never hit a sudo prompt.
- Checks for `jq` (required by `shop.sh`) and the `iris` CLI (required for the cache lookup + writeback). Prints install commands if either is missing.
- Runs `woolies doctor` at the end to confirm everything is wired up.

Then sign in once (each):

```sh
woolies login   # interactive, spawns Camoufox; ~25 s + ~300 MB browser DL first run
iris login      # interactive, mints + saves a PAT
```

After that, every cart operation is ~1 s of HTTPS.

For unattended use (e.g. wrapping `shop.sh` in cron), set `WOOLWORTHS_USERNAME` + `WOOLWORTHS_PASSWORD` in your environment, or configure `password_command` per the upstream CLI's README.

## What the skill alone does

If you invoke the skill **without** `shop.sh` — for example, to find a Woolies SKU for one specific ingredient — it will resolve that single line and (optionally) write the SKU back to the relevant Iris Ingredient element. It will NOT walk a full shopping list. For the full weekly shop, use `shop.sh`.

## What this workflow doesn't do

- **Place the order.** You review the trolley on woolworths.co.nz and click Submit.
- **Handle delivery slots, payment, or address changes.** Those stay on woolworths.co.nz.
- **Apply boosts / loyalty specials.** The upstream CLI doesn't expose them.
- **Run scheduled / on a cron.** Out of scope; wrap `shop.sh` in your own cron line.
- **Fetch the photo for you.** Phase 1 picks up the newest image in the current directory — you still drop this week's photo there yourself. Fully async ingestion (file watcher, email-in, Dropbox) is tracked at [#13](https://github.com/cgbarlow/skills/issues/13).

## Disclaimer

This workflow drives an unofficial CLI against Woolworths' internal API. Use of automated access may violate Woolworths' Terms of Service. The upstream CLI's [README](https://github.com/mcinteerj/woolies-nz-cli) is explicit about this; consider using a dedicated Woolworths account for automated runs.

Neither the skill author nor the upstream CLI author accept any liability for account suspensions, rate limiting, or blocked access.

## Tests

```sh
cd skills/woolies-shopper
python3 -m unittest discover -s tests       # picker (10 cases, unchanged from v0.1.0)
bash tests/test_phase2.sh                   # phase 2 bash integration test
```

## License

CC-BY-SA-4.0 — same as the rest of the [cgbarlow/skills](https://github.com/cgbarlow/skills) marketplace.
