#!/usr/bin/env python3
"""Fetch NZ weather from MetService's public JSON endpoints.

Usage:
  python3 metservice.py forecast <town> [--days N] [--json]
  python3 metservice.py obs <town> [--json]
  python3 metservice.py hourly <town> [--json]
  python3 metservice.py compare <town1> <town2> ... [--days N]

Towns are given by name ("New Plymouth", "lower hutt", "Taupō").
The script normalises them to MetService slugs and probes variants.
"""
import argparse
import json
import sys
import unicodedata
import urllib.error
import urllib.request

BASE = "https://www.metservice.com/publicData"
# Public town page. Works with the plain slug: MetService 302-redirects it to
# the canonical /regions/<region>/locations/<slug> page (and maps legacy slugs,
# e.g. wanganui -> whanganui), so we don't need to know the region.
LOCATION_URL = "https://www.metservice.com/towns-cities/locations/{slug}"
UA = {"User-Agent": "Mozilla/5.0"}

# MetService uses some legacy/irregular slugs
ALIASES = {
    "whanganui": "wanganui",
    "mt-maunganui": "tauranga",
    "mount-maunganui": "tauranga",
}


def slugify(town: str) -> str:
    """lowercase, strip macrons, spaces to hyphens: 'New Plymouth' -> 'new-plymouth'."""
    s = unicodedata.normalize("NFKD", town).encode("ascii", "ignore").decode()
    s = s.strip().lower().replace("_", " ")
    s = "-".join(s.split())
    return ALIASES.get(s, s)


def location_url(slug: str) -> str:
    """Public MetService town page for a resolved slug (for citing sources)."""
    return LOCATION_URL.format(slug=slug)


def cell(value, suffix="") -> str:
    """Render a field for the text views, tolerating missing values.

    MetService returns most numbers as strings, but a field is occasionally
    absent for a given row (e.g. a forecast-only hour with no observed temp).
    Concatenating None with a suffix would raise TypeError and kill the whole
    command, so fall back to '?' and only append the unit when we have a value.
    """
    if value is None or value == "":
        return "?"
    return f"{value}{suffix}"


def fetch(url: str):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.load(r)


def get(endpoint_fmt: str, town: str):
    """Fetch an endpoint, probing slug variants on 404."""
    slug = slugify(town)
    candidates = list(dict.fromkeys([slug, slug.replace("-", "")]))
    for cand in candidates:
        try:
            return fetch(f"{BASE}/{endpoint_fmt.format(slug=cand)}"), cand
        except urllib.error.HTTPError as e:
            if e.code != 404:
                sys.exit(
                    f"MetService returned HTTP {e.code} for '{town}'. "
                    "The endpoint may be temporarily unavailable or have moved; "
                    "retry shortly or fall back to web search on metservice.com."
                )
        except urllib.error.URLError as e:
            sys.exit(
                f"Could not reach MetService ({e.reason}). "
                "Check network access, then retry."
            )
    sys.exit(
        f"No MetService location found for '{town}' (tried: {', '.join(candidates)}).\n"
        "Check spelling against the town list at metservice.com/towns-cities. "
        "Note: MetService uses 'wanganui' for Whanganui and has no page for some suburbs; "
        "try the nearest listed town."
    )


def cmd_forecast(args):
    data, slug = get("localForecast{slug}", args.town)
    days = data.get("days", [])[: args.days]
    if args.json:
        print(json.dumps(days, indent=1))
        return
    if not days:
        sys.exit(f"MetService returned no forecast days for '{slug}'.")
    print(f"MetService forecast: {slug} (issued {days[0].get('issuedAt', '?')})")
    for d in days:
        print(f"\n{d.get('dowTLA')} {d.get('date')}: {d.get('forecastWord')} "
              f"({cell(d.get('min'))}-{cell(d.get('max'), 'C')})")
        print(f"  {d.get('forecast')}")
        pd = d.get("partDayData") or {}
        parts = [f"{k}: {v.get('forecastWord')}" for k, v in
                 (("morning", pd.get("morning")), ("afternoon", pd.get("afternoon")),
                  ("evening", pd.get("evening")), ("overnight", pd.get("overnight")))
                 if v]
        if parts:
            print(f"  [{' | '.join(parts)}]")
    rs = days[0].get("riseSet") or {}
    if rs:
        print(f"\nSun today: rise {rs.get('sunRise')}, set {rs.get('sunSet')}")
    print(f"Page: {location_url(slug)}")


def cmd_obs(args):
    data, slug = get("localObs_{slug}", args.town)
    if args.json:
        print(json.dumps(data, indent=1))
        return
    th = data.get("threeHour") or {}
    tf = data.get("twentyFourHour") or {}
    print(f"Current observations: {data.get('location', slug)} at {th.get('dateTime')}")
    print(f"  Temp {cell(th.get('temp'), 'C')} (wind chill {cell(th.get('windChill'), 'C')}), "
          f"humidity {cell(th.get('humidity'), '%')}")
    print(f"  Wind {th.get('windDirection')} {cell(th.get('windSpeed'), ' km/h')}, "
          f"pressure {cell(th.get('pressure'), ' hPa')} ({th.get('pressureTrend')})")
    print(f"  Rain last 3h: {cell(th.get('rainfall'), ' mm')}")
    print(f"  Last 24h (from {tf.get('dateTime')}): "
          f"{cell(tf.get('minTemp'))}-{cell(tf.get('maxTemp'), 'C')}, "
          f"rain {cell(tf.get('rainfall'), ' mm')}")
    print(f"Page: {location_url(slug)}")


def cmd_hourly(args):
    data, slug = get("hourlyObsAndForecast_{slug}", args.town)
    rows = data.get("forecastData", [])
    if args.json:
        print(json.dumps(rows, indent=1))
        return
    print(f"Hourly forecast: {data.get('locationName', slug)}")
    print(f"{'time':<7}{'temp':<6}{'rain':<7}{'wind':<10}{'gust'}")
    for r in rows:
        wind = f"{r.get('windDir', '')} {cell(r.get('windSpeed'), 'km/h')}".strip()
        print(f"{cell(r.get('timeFrom')):<7}{cell(r.get('temperature'), 'C'):<6}"
              f"{cell(r.get('rainFall'), 'mm'):<7}"
              f"{wind:<10}"
              f"{cell(r.get('gustSpeed'), 'km/h')}")
    print(f"Forecast rain total: {cell(data.get('rainfallTotalForecast'), ' mm')}")
    print(f"Page: {location_url(slug)}")


def cmd_compare(args):
    results = {}
    slugs = {}
    for town in args.towns:
        data, slug = get("localForecast{slug}", town)
        results[town] = data.get("days", [])[: args.days]
        slugs[town] = slug
    # Use the town with the most days to build the header, so a short/empty
    # forecast for one town doesn't truncate the whole table.
    header_days = max(results.values(), key=len, default=[])
    if not header_days:
        sys.exit("MetService returned no forecast days for any of the given towns.")
    dates = [f"{d.get('dowTLA', '?')} {d.get('date', '?')}" for d in header_days]
    width = max(len(t) for t in results) + 2
    print(f"{'':<{width}}" + "".join(f"{dt:<24}" for dt in dates))
    for town, days in results.items():
        cells = [f"{d.get('forecastWord', '?')} {cell(d.get('min'))}-{cell(d.get('max'), 'C')}"
                 for d in days]
        print(f"{town:<{width}}" + "".join(f"{c:<24}" for c in cells))
    print("\nNote: 'Windy' and 'Wind rain' words flag gale conditions; "
          "read full forecasts before declaring a winner.")
    print("\nPages:")
    for town, slug in slugs.items():
        print(f"  {town}: {location_url(slug)}")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    f = sub.add_parser("forecast");  f.add_argument("town")
    f.add_argument("--days", type=int, default=5); f.add_argument("--json", action="store_true")
    f.set_defaults(func=cmd_forecast)

    o = sub.add_parser("obs"); o.add_argument("town")
    o.add_argument("--json", action="store_true"); o.set_defaults(func=cmd_obs)

    h = sub.add_parser("hourly"); h.add_argument("town")
    h.add_argument("--json", action="store_true"); h.set_defaults(func=cmd_hourly)

    c = sub.add_parser("compare"); c.add_argument("towns", nargs="+")
    c.add_argument("--days", type=int, default=5); c.set_defaults(func=cmd_compare)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
