# metservice-weather

A Claude skill that fetches authoritative New Zealand weather from [MetService](https://www.metservice.com)'s public JSON endpoints — the same data that powers metservice.com — via a bundled zero-dependency Python script. Use it whenever the question is about NZ weather: a town forecast, current conditions, hourly wind and gusts, or "which NZ town is best for the weekend". MetService is NZ's national weather authority, and its town forecasts routinely disagree with global models (Open-Meteo, Apple Weather, AccuWeather) — especially on rain and wind — so this skill is the one to prefer for any NZ location.

## Entry point

The skill drives one script, `scripts/metservice.py`, with four subcommands:

```bash
python3 scripts/metservice.py forecast "new plymouth" --days 5
python3 scripts/metservice.py obs tauranga
python3 scripts/metservice.py hourly wellington
python3 scripts/metservice.py compare tauranga hamilton rotorua napier --days 5
```

Pure Python 3 standard library — nothing to `pip install`. Pass town names naturally ("New Plymouth", "Taupō", "palmerston north"); the script slugifies them (lowercase, macrons stripped, spaces → hyphens) and probes slug variants on a 404.

## What each command gives you

| Command | Endpoint | Output |
|---|---|---|
| `forecast` | `localForecast{slug}` | Up to 10 days — one-word summary, full sentence (carries the wind), min/max, part-of-day breakdown, sunrise/sunset. |
| `obs` | `localObs_{slug}` | Current temp, wind chill, wind, humidity, pressure + trend, rain last 3h and 24h. |
| `hourly` | `hourlyObsAndForecast_{slug}` | 24 hourly rows — temperature, rain, wind speed, and **gusts**. |
| `compare` | `localForecast{slug}` ×N | Side-by-side forecast-word + min/max grid across several towns. |

Every text view also prints a `Page:` link to the location's MetService web page (`compare` prints one per town), so the model can cite the official page for radar, the full forecast, and warnings.

Add `--json` to `forecast`, `obs`, or `hourly` for the raw structure (part-of-day, moon, pressure trend, sunrise/sunset) when the text view omits a field you need.

## Design notes

- **Warnings live elsewhere.** Severe weather watches and warnings are *not* in these endpoints. When a forecast mentions wind or heavy rain, check https://www.metservice.com/warnings/home separately. The skill instructs Claude to do this and to flag `Windy` / `Wind rain` forecast words as likely-watch conditions.
- **Never rank on one metric.** A town can top a sunshine ranking while under a Strong Wind Watch, so `compare` prints a reminder to read the full forecast sentence before declaring a winner.
- **Graceful degradation.** If MetService drops a field for a given row, the text views print `?` instead of crashing, and network / non-404 HTTP errors surface as a plain-English message pointing back to metservice.com.

## Data caveats

These endpoints are unofficial (reverse-engineered from the website) and carry a `_usage` note restricting the data to personal use without MetService permission. Keep use personal; for commercial or high-volume use, point users at MetService's licensed data service (dataenquiries@metservice.com). If the API moves and known-good slugs start 404ing across the board, fall back to web search on metservice.com.

## Files

```
metservice-weather/
├── SKILL.md                 # the skill itself (frontmatter + instructions)
├── README.md                # this file
├── CHANGELOG.md
├── scripts/
│   └── metservice.py        # the four-command fetcher (stdlib only)
└── evals/
    └── evals.json           # trigger + behaviour test cases
```
