# Changelog

All notable changes to the **woolies-shopper** skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this skill follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
