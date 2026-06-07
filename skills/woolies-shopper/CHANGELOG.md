# Changelog

All notable changes to the **woolies-shopper** skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this skill follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.4] — 2026-06-07

### Fixed

- **Meal-plan routes never worked: `shop.sh` passed `--json` as a trailing flag.** `--json` is a *global* `iris` flag and must precede the subcommand, so `iris aggregation-profile list --json`, `iris aggregation-profile get … --json`, and `iris aggregate … --json` all exited non-zero — surfacing as "No aggregation profile available" even when profiles existed (5 were present). Moved `--json` to the global position (`iris --json aggregation-profile list`, etc.) in `resolve_profile_id`, `warn_if_no_provenance`, and the aggregate call. (Same flag-position class as the phase-2 `iris elements get` fix.)

## [0.3.3] — 2026-06-07

Builds on 0.3.0's phase-1 input modes (below): keeps the four routes + the v0.2.1/v0.2.2 installer/headless fixes, makes phase 2 work on the **real** smart_markdown shopping list (the old parser produced "0 items added" on it), and adds Supabase auth + a no-login default backend.

### Added
- `scripts/iris-auth.sh` — sourceable Supabase auth helper. Fetches a Supabase session JWT via the password grant and exports it as `IRIS_TOKEN`, caching the refresh token (0600) for password-free reuse. Works around this deployment's Supabase mode, where `iris login` (password) is disabled and the PAT path 500s. Reads project id + publishable key from env / `$IRIS_ENV_FILE` / a gitignored `scripts/iris-auth.local.env`.
- `scripts/test-writeback.sh` — safe live round-trip test of the SKU cache writeback against a real Ingredient element: snapshots the element, runs `iris_attr_update`, reads back to confirm the SKU persisted (and round-trips through `extract_woolies_sku`), then restores the original data via an EXIT trap. Adds (and later removes) a temporary Product attribute for the `no_products` case.

### Fixed

- `scripts/phase2_bulk_add.sh` used `iris export diagram --format md`, which the iris-api rejects with HTTP 422 (`format` only accepts `json` or `markdown`) — every real phase-2 run aborted at the export step. Changed to `--format markdown`. (The phase2 mock/tests matched only on the subcommand, so they passed despite the bug; mock doc comment updated.)
- `scripts/shop.sh` preflight wrongly reported a successfully-authenticated session as a "rejected token" and aborted: `iris whoami` returns `{anonymous,url}` only when *anonymous*, and `{id,username,role,…}` (no `anonymous` field) when *authenticated*. Preflight now classifies by `.username` presence, not `.anonymous == false`. Same fix applied to `scripts/test-writeback.sh`.

### Changed

- **`scripts/phase2_bulk_add.sh` now handles the real smart_markdown shopping list.** `parse_line` auto-detects two line formats: the smart_markdown checklist `- [optional [x]] [qty] {{element:UUID:name}} [qty] [_(notes)_]` (the combined meal-plan + recurring list) **and** the original aggregation output `- name: qty <!-- iris:element=… -->` (meal-plan routes), so both phase-1 route families work. For smart_markdown it takes the element id from the `{{element:…}}` token, a best-effort quantity from the surrounding text, and **processes only un-ticked items** by default (ADR-239: `[x]` = ticked off; `SHOP_PROCESS_TICKED=true` for all). The SKU cache moved to the **`Products`** attribute notes (the SKU is a product property; `Preferred product` is a name-only pointer used for the search hint) — override with `SHOP_SKU_ATTR`. The diagram-id input now reads `data.markdown_source` (the `--format markdown` export returns only metadata — the cause of the earlier "0 items"), falling back to the markdown export. New exception reason codes — `no_cached_sku`, `cached_sku_failed`, `no_product_attr`, `element_fetch_failed`, plus `no_provenance` — each carrying a `search` hint. `tests/test_phase2.sh`, its fixtures, and the `iris` mock updated to match; `tests/test_phase2_listmd.sh` (the `--list-md` aggregate form) retained.
- **`scripts/shop.sh` route 2b (shopping-list View GUID)** now reads `data.markdown_source` (smart_markdown) instead of `iris export diagram --format md` (which 422'd / returned metadata-only). Supplying a GUID is the user's confirmation, so that route has no review gate — curate / tick off owned items in Iris beforehand.
- **`scripts/shop.sh` phase 3 is now an interactive `claude` session, not `claude -p`.** Headless `-p` can't surface the skill's AskUserQuestion prompts, so it ran invisibly and couldn't ask about ambiguous / out-of-stock picks.
- `scripts/shop.sh` no longer requires an iris login. Reads are anonymous, so the core shop only needs the CLI pointed at the right backend. Preflight now classifies the session by `iris --json whoami`'s `.username` (the old `iris whoami` exit-code check passed even for an anonymous localhost CLI) and, if the CLI would fall through to its `http://localhost:8000` default, exports `IRIS_URL=$DEFAULT_IRIS_URL` (`https://iris-api-gtb3.onrender.com`, overridable). Any explicit `IRIS_URL`/config.toml url is respected. Auth is **optional**: anonymous runs are read-only (writeback skipped, with a hint to `source scripts/iris-auth.sh`).

### Docs

- README + SKILL.md now document the no-login default-URL flow: the `iris` CLI only needs to point at the **iris-api backend** (e.g. `https://iris-api-gtb3.onrender.com`), not the SvelteKit frontend (`iris-uat.chrisbarlow.nz`, whose `/api` path serves HTML); `shop.sh` defaults this automatically. Auth (a PAT via `IRIS_TOKEN`) is only needed for the optional writeback, and this deployment's Supabase mode disables password `iris login` (mint a PAT via `POST /api/users/me/tokens`).

## [0.3.0] — 2026-05-30

### Added

- **Phase 1 input modes, asked at run time.** `shop.sh` now offers two choices and runs the matching one of four routes:
  - **What:** _Meal plan_ (derive the list from a week's meals via Iris aggregation) or _Shopping list_ (use a list directly).
  - **Where:** _Photo_ (newest `*.jpg/*.jpeg/*.png` in the current directory, OCR'd headlessly) or _Iris View GUID_ (an existing diagram already in Iris).
  - Routes: meal-plan+photo (OCR → confirm → match meals to existing recipes → `iris aggregate`), meal-plan+GUID (`iris aggregate` on the meal-plan View), shopping-list+GUID (`iris export diagram` of the shopping-list View), shopping-list+photo (OCR straight to markdown).
- **Recipe matching + gate for meal-plan-from-photo.** The commit step matches each OCR'd meal to its EXISTING Iris recipe (no invented ingredients/recipes), writes any it can't match to `$STATE_DIR/unmatched.md`, and `shop.sh` surfaces those and requires confirmation before aggregating — so a missing recipe can't silently shrink the shop.
- **Aggregation-profile resolution** for meal-plan modes: honours `IRIS_SHOPPING_PROFILE_ID`, else auto-uses the only profile, else presents a numbered picker.
- **Provenance preflight warning.** When a chosen profile has `output.include_provenance = false`, `shop.sh` warns loudly that the SKU cache and phase-3 writeback are disabled (with the exact enable command) instead of silently degrading.
- `phase2_bulk_add.sh --list-md <file> <state_dir>` — accepts a pre-rendered shopping-list markdown (the form `shop.sh` now uses). The `<diagram_id> <state_dir>` form is retained for standalone use.
- `tests/test_phase2_listmd.sh` — regression test for the `--list-md` form (same outcome as diagram mode; asserts no `iris export diagram` call).

### Changed

- `shop.sh` phase 1 no longer assumes a meal-plan photo. It produces `$STATE_DIR/aggregate.md` by whichever route the user selects, then hands phase 2 that file via `--list-md`. Phase 3's `claude` call is unchanged.

### Notes

- **Shopping-list-from-photo has no Iris provenance**, so phase 2's SKU cache can't apply (every line → manual phase 3) and no SKUs are written back. `shop.sh` warns at run time and recommends a meal plan or a shopping-list View GUID for the fast path.

## [0.2.2] — 2026-05-30

### Fixed

- Phase 1 of `scripts/shop.sh` no longer crashes with `Input must be provided either through stdin or as a prompt argument when using --print` (issue #15). The old code ran `claude 2>&1 | tee …` to capture the session; the pipe made stdout a non-TTY, so Claude Code flipped to headless `--print` mode but received no prompt. Phase 1 is now genuinely headless by design (see below), so the failure mode is gone.

### Changed

- **Phase 1 reworked from an interactive session to two headless `claude -p` calls, with the meal-plan photo picked up from the current directory** instead of uploaded interactively:
  - Selects the **newest** `*.jpg`/`*.jpeg`/`*.png` in the directory `shop.sh` is run from (`.heic` is intentionally unsupported — Claude's image reader doesn't accept it; export as JPG). Fails with a clear message if no image is present.
  - **Step 1a (OCR):** writes the parsed meal plan to `$STATE_DIR/mealplan.md` and performs no Iris writes, so the user can sanity-check the parse first.
  - **Confirmation gate:** prints the parsed plan and waits for a `y` before committing. The user can edit `$STATE_DIR/mealplan.md` before confirming.
  - **Step 1b (commit):** creates the meal plan in Iris, aggregates, and writes the diagram id to `$STATE_DIR/diagram-id`. The handoff is now a file Claude writes (authoritative) rather than a `DIAGRAM_ID=` line scraped from stdout — robust against TUI/formatting noise.



### Fixed

- `scripts/install.sh` no longer falsely reports the X11 libraries `libXcomposite.so.1`, `libXdamage.so.1`, and `libXrandr.so.2` as missing when they are in fact installed. The check listed these sonames in lowercase and matched them with a case-sensitive `grep`, so on disk (where X11 sonames are capitalised) they never matched — the installer kept nagging to install libraries that were already present, and would never exit cleanly. Detection is now case-insensitive and uses the real capitalised sonames.

### Added

- `scripts/install.sh --install-system-libs` flag (also `WOOLIES_INSTALL_SYSTEM_LIBS=1`) — opt-in auto-install of the missing Camoufox system libraries via `sudo apt`/`dnf`. **Off by default**, preserving the installer's no-sudo principle so non-interactive spawns (e.g. `shop.sh` phase 1) never trigger a sudo password prompt. Without the flag, behaviour is unchanged: the exact install command is printed for the user to run.
- `scripts/lib/system_libs.sh` — extracted, sourceable helper holding `detect_missing_libs` plus the per-distro package lists (`SYSTEM_LIBS_APT_PKGS` / `SYSTEM_LIBS_DNF_PKGS`) as a single source of truth shared by detection, the printed command, and the auto-installer (§13 DRY).
- `tests/test_system_libs.sh` — regression test for the detection helper: asserts capitalised X11 sonames in an `ldconfig -p` cache are found, that genuinely-missing libs are still reported, and that the package lists stay aligned with `REQUIRED_LIBS`.
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
