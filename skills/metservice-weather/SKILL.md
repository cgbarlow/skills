---
name: metservice-weather
description: Get authoritative New Zealand weather from MetService's public JSON endpoints — town forecasts (up to 10 days), current observations, hourly forecasts with wind gusts, and multi-town comparisons. Use this whenever the user asks about NZ weather in any form; a forecast for an NZ town or region; whether it will rain, be fine, windy, or frosty somewhere in NZ; which NZ location is sunniest, warmest, driest, or best for a trip; current conditions or temperature in an NZ town; or mentions MetService by name. Prefer this over web search or global weather models (Open-Meteo, Apple Weather, AccuWeather) for any New Zealand location — MetService is NZ's national weather authority and its town forecasts routinely disagree with global models, especially for rain and wind.
---

# MetService Weather

Fetch NZ weather from MetService's public JSON endpoints (the same data that powers metservice.com) using the bundled script. Pure Python 3 standard library — no dependencies to install.

## Quick start

```bash
python3 scripts/metservice.py forecast "new plymouth" --days 5
python3 scripts/metservice.py obs tauranga
python3 scripts/metservice.py hourly wellington
python3 scripts/metservice.py compare tauranga hamilton rotorua napier --days 5
```

Add `--json` to `forecast`, `obs`, or `hourly` for the raw structure when you need fields the text view omits (part-of-day breakdowns, sunrise/sunset, moon, pressure trend). The text views degrade gracefully if MetService drops a field for a given row — a missing value shows as `?` rather than crashing the command.

Each text view ends with a `Page:` line — the MetService web page for that location (`compare` prints one per town under `Pages:`). Surface these as links when you present the weather, so the user can open the official page for the full picture, radar, and any warnings. See [Citing location pages](#citing-location-pages).

## Location slugs

The script normalises town names itself (lowercase, macrons stripped, spaces to hyphens), so pass natural names: "New Plymouth", "Taupō", "palmerston north". Known quirks it already handles:

- Whanganui uses the legacy slug `wanganui`
- Mt Maunganui has no page of its own; it maps to `tauranga`

If a town still 404s, it is probably not a MetService forecast location. Suggest the nearest town from metservice.com/towns-cities rather than guessing further slugs.

## Endpoints (for reference)

All under `https://www.metservice.com/publicData/`, no auth, but send a browser User-Agent header (the script does):

- `localForecast{slug}` — days array with `forecastWord` (one-word summary), `forecast` (full sentence, includes wind), `min`/`max`, `partDayData` (morning/afternoon/evening/overnight), `riseSet` (sun and moon times)
- `localObs_{slug}` — current temp, wind, humidity, pressure and trend, rain last 3h and 24h
- `hourlyObsAndForecast_{slug}` — 24 hourly rows with temperature, rain, wind speed and gusts

Severe weather warnings and watches are NOT in these endpoints. When forecasts mention wind or heavy rain, or the user is planning travel, check https://www.metservice.com/warnings/home with web_fetch or web search for active watches and warnings, and say so if one covers the user's area.

## Interpreting and presenting

- `forecastWord` vocabulary runs roughly best to worst: Fine, Partly cloudy, Cloudy, Few showers, Showers, Rain, Wind rain, Windy, Snow, Thunder. "Windy" and "Wind rain" usually mean a watch or warning is likely — flag it.
- Never rank locations on a single metric. A town can top a sunshine-hours ranking while sitting under a Strong Wind Watch. Weigh the forecast word, the full forecast sentence (which carries the wind), and gusts from the hourly endpoint before recommending anywhere.
- Answer "where is best" questions with `compare`, then sanity-check the winner's full forecast text for wind or fog before declaring it.
- Forecasts run up to about 10 days but MetService's own confidence drops sharply after day 5; caveat anything beyond that.
- Temperatures are Celsius, wind km/h, rain mm. Quote the `issuedAt` time for currency when it matters.

## Citing location pages

The script resolves each town to its MetService slug and prints the public page URL (`https://www.metservice.com/towns-cities/locations/<slug>`). Include it as a link whenever you report weather for a location:

- Link every location you give conditions or a forecast for — for a single town, one link; for `compare`, link each town from its row.
- Use the exact URL the script prints. It handles the legacy-slug redirects (e.g. Whanganui resolves to `.../locations/wanganui`, which MetService redirects to the Whanganui page), so don't hand-build URLs from the town name.
- The page carries the live radar, the full forecast, and any active warnings that the JSON endpoints omit — so the link is where the user goes to confirm before travel. Pair it with the warnings check below.

## When to fall back to other sources

MetService town forecasts are qualitative (words, not sunshine hours or rain probabilities per day). If the user explicitly wants numeric sunshine hours, UV, or probability curves, supplement with Open-Meteo — but label it as a global model and let MetService win any conflict about NZ rain or wind.

## Data caveats

These endpoints are unofficial (reverse-engineered from the website), carry a `_usage` note that the data is restricted to personal use without MetService permission, and may change without notice. Keep use personal; for anything commercial or high-volume, point the user at MetService's licensed data service (dataenquiries@metservice.com). If an endpoint starts returning 404s across known-good slugs, the API has likely moved — the script says so, and you should fall back to web search on metservice.com.
