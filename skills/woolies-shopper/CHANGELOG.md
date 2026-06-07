# Changelog

All notable changes to the **woolies-shopper** skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this skill follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] — 2026-06-07

### Added

- `scripts/shop.sh` phase 1 now offers two shopping-list sources: the original **photo** path (interactive Claude OCR + aggregate) or a new **GUID** path where the user supplies the GUID of an aggregated shopping-list diagram they already have in Iris, skipping the photo/OCR step. The GUID is validated up front with `iris diagrams get` (well-formed UUID + resolves in Iris) before phase 2 runs. The new `SHOP_DIAGRAM_ID=<guid>` env var selects the GUID path non-interactively (e.g. re-runs / cron).
- `scripts/iris-auth.sh` — sourceable Supabase auth helper. Fetches a Supabase session JWT via the password grant and exports it as `IRIS_TOKEN`, caching the refresh token (0600) for password-free reuse. Works around this deployment's Supabase mode, where `iris login` (password) is disabled and the PAT path 500s. Reads project id + publishable key from env / `$IRIS_ENV_FILE` / a gitignored `scripts/iris-auth.local.env`.
- `scripts/test-writeback.sh` — safe live round-trip test of the SKU cache writeback against a real Ingredient element: snapshots the element, runs `iris_attr_update`, reads back to confirm the SKU persisted (and round-trips through `extract_woolies_sku`), then restores the original data via an EXIT trap. Adds (and later removes) a temporary Product attribute for the `no_products` case.

### Fixed

- `scripts/phase2_bulk_add.sh` used `iris export diagram --format md`, which the iris-api rejects with HTTP 422 (`format` only accepts `json` or `markdown`) — every real phase-2 run aborted at the export step. Changed to `--format markdown`. (The phase2 mock/tests matched only on the subcommand, so they passed despite the bug; mock doc comment updated.)
- `scripts/shop.sh` preflight wrongly reported a successfully-authenticated session as a "rejected token" and aborted: `iris whoami` returns `{anonymous,url}` only when *anonymous*, and `{id,username,role,…}` (no `anonymous` field) when *authenticated*. Preflight now classifies by `.username` presence, not `.anonymous == false`. Same fix applied to `scripts/test-writeback.sh`.

### Changed

- **`scripts/phase2_bulk_add.sh` rewritten for the real shopping-list format.** The list is a `smart_markdown` diagram (the meal-plan + recurring list already combined), not an `aggregation_list` output. Phase 2 now: reads the body from `data.markdown_source` via the JSON export (the `--format markdown` export returns only metadata); parses GFM checklist lines `- [optional [x]] [qty] {{element:UUID:name}} [qty] [_(notes)_]`, taking the element id from the `{{element:…}}` token (the provenance) and a best-effort quantity from the surrounding free text; **processes only un-ticked items** by default (ADR-239: `[x]` = ticked off; `SHOP_PROCESS_TICKED=true` to process all); and reads/writes the cached SKU in the **`Products`** attribute notes (override `SHOP_SKU_ATTR`), with `Preferred product` kept as a name-only pointer used for the search hint. New exception reason codes — `no_cached_sku`, `cached_sku_failed`, `no_product_attr`, `element_fetch_failed` — each carrying a `search` hint (`Preferred product` type → `Products` type → name). Replaces the old `<!-- iris:element -->` / singular-`Product`-attribute / multi-row-fallback model. `tests/test_phase2.sh`, its fixtures, and the `iris` mock rewritten to match.
- **`scripts/shop.sh` photo path now gates on human review.** After generating the combined list it prints a link (`$IRIS_FRONTEND_URL/views/<id>`, default `https://iris-uat.chrisbarlow.nz`) and pauses so the user can check the list and tick off items already on hand; phase 2 then processes only the un-ticked ones. The GUID path skips the pause — supplying a GUID is the confirmation.
- `scripts/shop.sh` no longer requires an iris login. The shopping-list diagram and ingredient elements are readable anonymously, so the core shop only needs the CLI pointed at the right backend. Preflight now inspects `iris --json whoami` and, if the CLI would fall through to its `http://localhost:8000` default (no `--url`/`IRIS_URL`/config.toml `url`), exports `IRIS_URL=$DEFAULT_IRIS_URL` (default `https://iris-api-gtb3.onrender.com`, overridable) so phases 1–3 hit the right host with zero setup. Any explicit `IRIS_URL`/config.toml url is respected and left untouched. Auth is now **optional**: anonymous sessions run read-only and the preflight echoes the resolved URL + whether the session is authenticated, warning that the SKU cache writeback will be skipped without a token. (Supersedes the brief "fail loudly if anonymous" behaviour from earlier in this Unreleased cycle.)

### Docs

- README + SKILL.md now document the no-login default-URL flow: the `iris` CLI only needs to point at the **iris-api backend** (e.g. `https://iris-api-gtb3.onrender.com`), not the SvelteKit frontend (`iris-uat.chrisbarlow.nz`, whose `/api` path serves HTML); `shop.sh` defaults this automatically. Auth (a PAT via `IRIS_TOKEN`) is only needed for the optional writeback, and this deployment's Supabase mode disables password `iris login` (mint a PAT via `POST /api/users/me/tokens`).

## [0.2.0] — 2026-05-24

### Added

- `scripts/shop.sh` — master bash orchestrator for the full weekly shop. Three phases: (1) interactive Claude Code session for photo OCR + meal-plan + aggregation; (2) pure-bash bulk-add against cached SKUs; (3) conditional Claude session that invokes this skill to resolve exceptions. Each phase runs in a fresh Claude session; state hands off through files in `$SHOP_STATE_DIR` (default `/tmp/shop-<timestamp>/`).
- `scripts/phase2_bulk_add.sh` — pure-bash bulk-add. Reads the aggregated shopping list, parses each line for the `<!-- iris:element=<uuid> -->` provenance comment (requires iris ≥ v6.31.0 / ADR-217 with `include_provenance: true` on the aggregation profile), looks up each Ingredient element, walks its Product attribute rows in preferred order, tries each cached `woolies:NNN` SKU in the row's notes, refreshes the `confirmed:` date on success, and pushes anything that can't be resolved to `exceptions.json` for phase 3. Zero LLM tokens consumed.
- `scripts/lib/iris_attr_update.sh` — shared bash helper for the iris CLI's get-merge-put attribute-notes update pattern. Reused by phase 2 (date refresh on success) and phase 3 (skill writeback of new SKUs).
- `tests/test_phase2.sh` + mock `iris` / `woolies` binaries under `tests/mock-bin/` + 5 fixture JSONs — end-to-end integration test for phase 2 covering cache hit, Product[0]→Product[1] fallback on stock-out, no-cached-SKU, no-Product-attributes, and no-provenance (graceful-degradation) paths.

### Changed

- **Skill re-scoped from "do the whole shop" to "resolve shopping exceptions".** The frontmatter `description` now steers Claude to point users at `shop.sh` for the full workflow and only triggers this skill directly for exception resolution or single-SKU lookups. SKILL.md body has been rewritten end-to-end against the exceptions-payload contract emitted by phase 2.
- `SKILL.md` body adds a writeback step (new): after a successful exception-resolution cart-add, the skill writes the resolved SKU back to the relevant Product attribute's notes via the `iris` CLI so the next shop hits the cache.
- `scripts/install.sh` now also checks for `jq` (required by `shop.sh` / `phase2_bulk_add.sh`) and `iris` CLI (required for the cache lookup and writeback). Both checks fail with an install hint rather than silently degrading.

### Notes

- The cache-hit fast path requires `iris ≥ v6.31.0` (ADR-217) AND the user's shopping-list aggregation profile to have `output.include_provenance: true`. Without those, every line falls through to phase 3 as a `no_provenance` exception — graceful degradation, whole workflow still completes, just slower.
- `scripts/pick.py` and its 10 unit tests are **unchanged** from v0.1.0. The picker stays exactly the same; only the orchestration around it moves.
- Closes follow-up plan documented at https://github.com/cgbarlow/iris/blob/research/issue-231-woolies-skill/docs/plans/issue-231-followup-cached-skus-plan.md.

## [0.1.0] — 2026-05-23

### Added
- Initial skill: drives the weekly Woolworths NZ online grocery shop by reading an aggregated shopping list from the Iris MCP server and populating a Woolworths trolley via the local `woolies-nz-cli`.
- `scripts/install.sh` — idempotent installer that pins `woolies-nz-cli==0.1.1`, detects missing Camoufox runtime libraries on Linux, and prints the exact apt/dnf command for the user to run themselves (no auto-sudo).
- `scripts/doctor.sh` — single-line JSON health check used by the skill's preflight step.
- `scripts/pick.py` — deterministic SKU picker (stdlib only). Ranks by in-stock filter → size hint → brand hint → loose-produce preference for dual-priced items → cup-price tiebreak, with a configurable ambiguity threshold.
- `tests/test_pick.py` + `tests/fixtures/*.json` — behavioural spec for the picker (10 cases, all green).

### Notes
- Primary host is **Claude Cowork**. The same skill runs unchanged in **Claude Code**.
- The skill stops at "trolley populated"; the user reviews and submits the order in the browser. This is intentional — no skill-driven checkout.
- Closes the slow Chrome-extension cart-building step from the Iris [issue #211](https://github.com/cgbarlow/iris/issues/211) workflow; addresses Iris [issue #231](https://github.com/cgbarlow/iris/issues/231).
