# woolies-shopper

A Claude skill + bash orchestrator that runs your weekly Woolworths NZ online grocery shop. Reads an aggregated shopping list from your [Iris](https://github.com/cgbarlow/iris) knowledge base via the Iris MCP server, then populates a Woolworths NZ trolley using the local [`woolies` CLI](https://github.com/mcinteerj/woolies-nz-cli). You review and submit the order yourself in the browser — the workflow stops at "trolley populated", deliberately.

**v0.2.0 architecture (May 2026)**: the workflow is now a three-phase bash pipeline (`scripts/shop.sh`) where the bulk-add phase runs LLM-free against cached SKUs. Only the OCR (phase 1) and exception-resolution (phase 3) phases call Claude, and only when needed.

## Entry point

```sh
./scripts/shop.sh
```

That's it. The script walks you through the three phases. Run it from a regular terminal — no Claude Code session required (phase 1 spawns its own).

## What happens

1. **Preflight** — checks `woolies` is installed and logged in, `iris` CLI is authenticated, and `jq` / `claude` are on PATH.
2. **Phase 1 (shopping-list source)** — pick how to supply the shopping list (a `smart_markdown` diagram whose body lives in `data.markdown_source`, with each item written as a `{{element:UUID:name}}` token):
   - **Photo** (interactive Claude Code, ~1 min) — Claude prompts you to upload a photo of this week's meal plan and builds the combined shopping list in Iris (merging your recurring list). It then prints a **link to the list and pauses** so you can review it and tick off (✓, checklist mode) anything you already have. Phase 2 buys only the items left **un-ticked**.
   - **GUID** — you already have the list in Iris, so paste its diagram GUID. Supplying a GUID *is* your confirmation, so there's no review pause. The script validates it with `iris diagrams get`. Set `SHOP_DIAGRAM_ID=<guid>` to choose this non-interactively (e.g. re-runs / cron).
3. **Phase 2 (pure bash, ~30 s)** — reads `data.markdown_source`, parses each **un-ticked** `{{element:UUID:name}}` line (pulling the element id and a best-effort quantity), looks up the element via the `iris` CLI, and if its **`Products`** attribute notes carry a cached `woolies:NNN` SKU, calls `woolies cart add` and refreshes the `confirmed:` date. Anything else (no cached SKU, cached SKU rejected, no `Products` attribute) goes to `exceptions.json` for phase 3 with a search hint. Zero Claude tokens consumed. (`SHOP_PROCESS_TICKED=true` processes every item regardless of checkbox.)
4. **Phase 3 (interactive Claude Code, only if exceptions exist)** — spawns a fresh Claude session and invokes the woolies-shopper skill (the exception resolver). Claude searches Woolies using each exception's search hint, picks via `scripts/pick.py`, asks you about ambiguous picks or out-of-stock substitutions, cart-adds, and writes the resolved SKU back to the element's `Products` notes so next week's shop hits the cache.
5. **Summary** — tells you to open woolworths.co.nz to review and submit. State + logs live in `$SHOP_STATE_DIR` (default `/tmp/shop-<timestamp>/`).

## The cache

Each Iris shopping-list element has a **`Products`** attribute (the buyable product) and a **`Preferred product`** name-only pointer (its `type` names the chosen product, used as the search hint). The SKU belongs to the product, so the workflow caches the resolved Woolworths SKU in the **`Products`** attribute's `notes` field using a parseable convention:

```
woolies:269671 | confirmed:2026-06-07
```

Phase 2 reads this to skip search entirely. Phase 3 maintains it (writes new SKUs after resolving exceptions; refreshes the `confirmed:` date on successful re-use). Steady state: weekly shops where most items repeat run almost entirely in phase 2, with minimal phase 3 work. Override the cache attribute with `SHOP_SKU_ATTR` if your elements use a different name.

The provenance that links each list line to its element is the `{{element:UUID:name}}` token in the smart_markdown source itself — no aggregation profile or `include_provenance` flag is required (that HTML-comment mechanism, [ADR-217](https://github.com/cgbarlow/iris/blob/main/docs/adrs/ADR-217-Aggregate-Output-Provenance.md), is for `aggregation_list` outputs; this workflow consumes the smart_markdown list directly).

## First-time install

```sh
./scripts/install.sh
```

The installer:
- Checks Python 3.11+ is on PATH.
- Installs `woolies-nz-cli==0.1.1` via `pipx` (pulls `click`, `httpx`, `camoufox` transitively).
- On Linux, detects missing GTK/NSS system libs Camoufox needs at runtime, and **prints** the exact `apt`/`dnf` command for you to run yourself (the installer never sudos).
- Checks for `jq` (required by `shop.sh`) and the `iris` CLI (required for the cache lookup + writeback). Prints install commands if either is missing.
- Runs `woolies doctor` at the end to confirm everything is wired up.

Then sign in to Woolworths once:

```sh
woolies login   # interactive, spawns Camoufox; ~25 s + ~300 MB browser DL first run
```

**Iris needs no login.** The shopping-list diagram and ingredient elements are readable anonymously, so the core shop works with the `iris` CLI unauthenticated — it just has to point at the right iris-api backend. `shop.sh` defaults that for you (`https://iris-api-gtb3.onrender.com`) whenever the CLI would otherwise fall through to its `http://localhost:8000` default. Override by exporting `IRIS_URL` or setting `url` in `~/.config/iris/config.toml`. Use the **iris-api host**, not the SvelteKit frontend (`iris-uat.chrisbarlow.nz` is the frontend; its `/api` path serves HTML, not JSON).

The one thing anonymous access can't do is **write**, so the SKU cache writeback (saving resolved SKUs for next time) is skipped on anonymous runs — `shop.sh` warns when this happens.

### Enabling writeback (Supabase auth)

To enable writeback you need a token in `IRIS_TOKEN` (it overrides any token in `~/.config/iris/config.toml`). This deployment runs in **Supabase mode**, which makes the obvious paths awkward:

- `iris login` (username/password) is **disabled** — `/api/auth/login` returns 404.
- The PAT path (`POST /api/users/me/tokens` → `iris login --token`) currently **returns HTTP 500** server-side — a backend bug, tracked upstream (it should 401 on a bad token, not 500). So PATs don't work against this deployment yet.

The reliable path is the **Supabase session JWT** (the same token the web app uses). The skill ships a helper that fetches one and exports `IRIS_TOKEN` for you:

```sh
source scripts/iris-auth.sh        # email + password once → exports IRIS_TOKEN
```

`iris-auth.sh` uses Supabase's password grant, caches the **refresh token** (0600 in `~/.config/woolies-shopper/`), and reuses it on later runs so you don't re-type your password. Supabase access tokens are short-lived (~1 h); just `source scripts/iris-auth.sh` again to refresh (no password — it reuses the cached refresh token). It reads the project id + publishable key from the environment, from `$IRIS_ENV_FILE`, or from a gitignored `scripts/iris-auth.local.env`.

To check the writeback works end-to-end against a real element (safe — it snapshots, writes a test SKU, verifies, then restores the original data):

```sh
source scripts/iris-auth.sh
./scripts/test-writeback.sh <element_id>     # e.g. an Ingredient element id
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
- **Automate the photo upload.** Phase 1 is an interactive Claude session today; async photo ingestion (file watcher, email-in, Dropbox) is tracked at [#13](https://github.com/cgbarlow/skills/issues/13).

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
