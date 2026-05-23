# Changelog

All notable changes to the **woolies-shopper** skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this skill follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
