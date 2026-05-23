# woolies-shopper

A Claude skill that drives the weekly Woolworths NZ online grocery shop. Reads an aggregated shopping list from your [Iris](https://github.com/cgbarlow/iris) knowledge base via the Iris MCP server, then populates a Woolworths NZ trolley using the local [`woolies` CLI](https://github.com/mcinteerj/woolies-nz-cli). You review and submit the order yourself in the browser — the skill stops at "trolley populated", deliberately.

Primary host: **Claude Cowork** (desktop, with `/schedule` for a weekly cadence). The same skill also runs in Claude Code if you prefer the terminal.

## What it does

1. **Preflight** — checks that `woolies-nz-cli` is installed and you're logged into Woolworths.
2. **Reads your shopping list** — fetches an aggregated meal-plan-derived shopping list from Iris (the output of `iris aggregate`).
3. **Searches + picks SKUs** — for each line, runs `woolies search` and picks the best in-stock match using a deterministic ruleset (size match → brand hint → loose-produce preference → unit-price tiebreak). Asks you when the choice is genuinely ambiguous; offers substitutions when something is out of stock.
4. **Adds to your trolley** — one `woolies cart add` per resolved line.
5. **Summarises** — shows you what was added, substituted, skipped, or out of stock, and tells you to open woolworths.co.nz to review and submit.

## First-time install

```sh
# From inside the skill directory:
./scripts/install.sh
```

The installer:

- Checks Python 3.11+ is on PATH.
- Installs `woolies-nz-cli==0.1.1` via `pipx` (pulls `click`, `httpx`, `camoufox` transitively).
- On Linux, detects missing GTK/NSS system libs Camoufox needs at runtime, and **prints** the exact `apt`/`dnf` command for you to run yourself (the installer never sudos).
- Runs `woolies doctor` at the end to confirm everything is wired up.

Then sign in to Woolworths once:

```sh
woolies login
```

That spawns the Camoufox browser (~25 s, plus a one-time ~300 MB browser download on first run), prompts for your email + password, and caches cookies for several weeks. After that, every cart operation is a ~1 s HTTPS call.

For unattended use (e.g. a Cowork scheduled task) set `WOOLWORTHS_USERNAME` and `WOOLWORTHS_PASSWORD` in your environment, or configure `password_command` per the upstream CLI's README.

## Iris MCP

The skill assumes you have the Iris MCP server configured in your client (Cowork, Claude Code, etc). Without it, the skill will tell you it can't find the shopping list and stop. See [Iris MCP setup](https://github.com/cgbarlow/iris/blob/main/docs/mcp.md).

## How it picks

The picker (`scripts/pick.py`) is small and deterministic. Given a `woolies search --json` payload and a desired (qty, unit, optional size hint, optional brand hint), it:

1. Drops out-of-stock candidates. If every candidate is out of stock it returns the top 2 OOS as substitutions for you to consider.
2. Applies your size and brand hints — but treats them as preferences, so a too-narrow hint doesn't wipe out the candidate pool.
3. For Kilogram requests, or fractional quantities, restricts to dual-priced (loose-produce) candidates only. For Each requests on items that have a loose form (e.g. "3 carrots"), prefers the loose SKU over a packaged bag — recipe-driven shopping is almost always asking for loose produce by count.
4. Sorts by cup price (per-unit-of-measure price), so different sizes compare fairly.
5. If the top two candidates are within 10 % of each other on cup price, returns `{"ambiguous": true, …}` and the skill asks you to choose. Override the threshold in the `--want` JSON via `tie_threshold`.

Tested against recorded fixtures in `tests/fixtures/` — run `python3 -m unittest discover -s tests` to verify.

## What it doesn't do

- **Doesn't place the order.** You eyeball the trolley and click Submit.
- **Doesn't handle delivery slots, payment, or address changes.** Those stay on woolworths.co.nz.
- **Doesn't apply boosts / loyalty specials.** The upstream CLI doesn't expose them as of v0.1.1.
- **Doesn't learn your preferences over time.** Brand and size hints come from your Iris `Ingredient` element-template stamps — refine them there, not here.

## Disclaimer

This skill drives an unofficial CLI against Woolworths' internal API. Use of automated access may violate Woolworths' Terms of Service. The upstream CLI's [README](https://github.com/mcinteerj/woolies-nz-cli) is explicit about this; consider using a dedicated Woolworths account for automated runs.

The skill author and the upstream CLI author accept no liability for account suspensions, rate limiting, or blocked access.

## License

CC-BY-SA-4.0 — same as the rest of the [cgbarlow/skills](https://github.com/cgbarlow/skills) marketplace.
