# Changelog

All notable changes to the **metservice-weather** skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this skill follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] — 2026-07-08

### Added

- **Location page links.** Each text view now prints a `Page:` line with the MetService web page for the location (`forecast`, `obs`, `hourly`); `compare` prints one `Pages:` link per town. The URL uses the plain slug (`https://www.metservice.com/towns-cities/locations/<slug>`), which MetService redirects to the canonical region page and resolves legacy slugs (e.g. Whanganui → the `wanganui` page). SKILL.md now instructs the model to surface these as links when presenting weather, so users can open the official page for radar, the full forecast, and any active warnings. `--json` output is unchanged (raw structure only).

## [1.0.0] — 2026-07-08

Initial release into this marketplace. Reviewed against the skill-creator methodology (functional verification of all four commands against live endpoints, edge-case probing, description-triggering review) and hardened before inclusion.

### Added

- **`metservice-weather` skill** — fetches NZ weather from MetService's public JSON endpoints via `scripts/metservice.py`, a zero-dependency Python 3 script with four subcommands:
  - `forecast <town> [--days N] [--json]` — up to 10-day town forecast (word summary, full sentence, min/max, part-of-day, sunrise/sunset).
  - `obs <town> [--json]` — current observations (temp, wind chill, wind, humidity, pressure + trend, rain 3h/24h).
  - `hourly <town> [--json]` — 24 hourly rows with temperature, rain, wind, and gusts.
  - `compare <town...> [--days N]` — side-by-side forecast grid across towns.
- Town-name normalisation (macron stripping, spacing, hyphenation) with slug-variant probing on 404, plus known-alias handling (`whanganui` → `wanganui`, `mt-maunganui` → `tauranga`).
- `evals/evals.json` with trigger and behaviour test cases.

### Hardened (vs. the submitted draft)

- **Missing-field tolerance.** The text views previously concatenated raw endpoint values with unit suffixes (e.g. `r.get('temperature') + 'C'`), which raised `TypeError` and killed the whole command if MetService ever omitted a field for a row. A `cell()` helper now renders missing values as `?` and only appends the unit when a value is present. Applied across `forecast`, `obs`, `hourly`, and `compare`.
- **Empty-forecast guard.** `forecast` and `compare` no longer index `days[0]` blindly; an empty `days` array now exits with a clear message instead of an `IndexError` traceback. `compare` builds its date header from the town with the most days, so a short/empty forecast for one town can't truncate the table.
- **Clean network errors.** `URLError` and non-404 `HTTPError` responses now exit with a plain-English message pointing back to metservice.com, rather than surfacing a raw traceback.
