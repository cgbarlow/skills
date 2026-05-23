#!/usr/bin/env python3
"""Pick the best Woolworths SKU from a `woolies search --json` payload.

Reads the search JSON from stdin and a `--want` JSON describing the
desired quantity, unit, and optional size / brand hints. Emits one of
four shapes on stdout:

  {"sku": ..., "quantity": ..., "unit": ..., "name": ..., "size": ...}
  {"ambiguous": true, "candidates": [...]}
  {"out_of_stock": true, "candidates": [...]}
  {"no_matches": true}

The skill prompt calls this once per shopping-list line. Stdout-only —
all status/debug goes to stderr.

`--want` schema:
  qty            (number, required)   How many to add.
  unit           (string, required)   "Each" or "Kilogram".
  size_hint      (string, optional)   Case-insensitive substring to
                                      prefer in product["size"] (e.g.
                                      "1L", "500g"). Filters down to
                                      matching candidates if any match.
  brand_hint     (string, optional)   Prefer candidates whose `brand`
                                      or `name` contains this string.
  tie_threshold  (number, optional)   If the top-two candidates'
                                      effective unit prices are within
                                      this fraction of each other, the
                                      pick is reported as ambiguous so
                                      the user can choose. Default 0.10
                                      (i.e. 10 %).
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any


def effective_unit_price(product: dict[str, Any]) -> float:
    """Per-unit price used for comparing across sizes.

    Falls back to sale_price then price when cup_price isn't on the
    item (older API rows occasionally omit it).
    """
    cup = product.get("cup_price")
    if isinstance(cup, (int, float)) and cup > 0:
        return float(cup)
    sale = product.get("sale_price")
    if isinstance(sale, (int, float)) and sale > 0:
        return float(sale)
    price = product.get("price")
    return float(price) if isinstance(price, (int, float)) else float("inf")


def candidate_summary(product: dict[str, Any]) -> dict[str, Any]:
    """Trimmed candidate view used in `ambiguous` / `out_of_stock` results."""
    return {
        "sku": str(product.get("sku", "")),
        "name": product.get("name", ""),
        "brand": product.get("brand", ""),
        "size": product.get("size", ""),
        "price": product.get("sale_price") or product.get("price"),
        "cup_price": product.get("cup_price"),
        "in_stock": bool(product.get("in_stock")),
    }


def filter_by_hint(
    products: list[dict[str, Any]],
    field: str,
    hint: str,
) -> list[dict[str, Any]]:
    """Restrict to products whose `field` contains `hint`, but only if
    at least one matches. If none do, return the input unchanged so a
    weak hint doesn't wipe out the candidate pool."""
    hint_lower = hint.lower()
    matched = [p for p in products if hint_lower in str(p.get(field, "")).lower()]
    return matched if matched else products


def filter_by_brand_or_name(
    products: list[dict[str, Any]],
    hint: str,
) -> list[dict[str, Any]]:
    """Brand hint matches either the `brand` field (preferred) or, when
    the brand field is blank, the product name. This way a hint like
    `Watties` still works on items where the brand wasn't populated by
    the upstream feed."""
    hint_lower = hint.lower()
    matched = [
        p for p in products
        if hint_lower in str(p.get("brand", "")).lower()
        or hint_lower in str(p.get("name", "")).lower()
    ]
    return matched if matched else products


def pick(payload: dict[str, Any], want: dict[str, Any]) -> dict[str, Any]:
    products = payload.get("products") or []
    if not products:
        return {"no_matches": True}

    in_stock = [p for p in products if p.get("in_stock")]
    if not in_stock:
        # Sort OOS candidates by their effective unit price so the
        # cheapest alternatives come first, then cap at 2 — that's
        # enough for the skill to offer the user a substitution.
        ranked_oos = sorted(products, key=effective_unit_price)
        return {
            "out_of_stock": True,
            "candidates": [candidate_summary(p) for p in ranked_oos[:2]],
        }

    candidates = in_stock
    size_hint = want.get("size_hint")
    brand_hint = want.get("brand_hint")
    if size_hint:
        candidates = filter_by_hint(candidates, "size", str(size_hint))
    if brand_hint:
        candidates = filter_by_brand_or_name(candidates, str(brand_hint))

    # Dual-pricing preference. Two situations force the picker toward
    # dual-priced (loose-produce) candidates:
    #   1. The request is in kilograms — non-dual products can't be
    #      added by weight.
    #   2. The quantity is fractional — Woolies' API rejects fractional
    #      Each quantities on non-dual products.
    # And one situation makes it a soft preference: an Each request
    # with no size_hint, where at least one dual-priced candidate
    # exists. The signal is "I want 3 carrots", not "I want a 1.5kg
    # bag of carrots" — recipe-driven shopping lists almost always
    # mean loose when they say a count. Size/brand hints override this
    # because they're an explicit signal the user wants a packaged form.
    qty = want["qty"]
    unit = want["unit"]
    is_fractional = float(qty) != int(float(qty))
    has_dual = any(c.get("supports_dual_pricing") for c in candidates)

    if unit == "Kilogram" or is_fractional:
        dual_only = [c for c in candidates if c.get("supports_dual_pricing")]
        if dual_only:
            candidates = dual_only
    elif unit == "Each" and has_dual and not size_hint:
        candidates = [c for c in candidates if c.get("supports_dual_pricing")]

    candidates = sorted(candidates, key=effective_unit_price)
    best = candidates[0]

    tie_threshold = float(want.get("tie_threshold", 0.10))
    if len(candidates) >= 2:
        p1 = effective_unit_price(candidates[0])
        p2 = effective_unit_price(candidates[1])
        # Tie when the cheaper price is positive and the gap is within
        # the threshold. Threshold of 0 disables the ambiguity check.
        if tie_threshold > 0 and p1 > 0 and (p2 - p1) / p1 < tie_threshold:
            return {
                "ambiguous": True,
                "candidates": [candidate_summary(c) for c in candidates[:3]],
            }

    return {
        "sku": str(best.get("sku", "")),
        "name": best.get("name", ""),
        "brand": best.get("brand", ""),
        "size": best.get("size", ""),
        "quantity": want["qty"],
        "unit": want["unit"],
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--want",
        required=True,
        help="JSON object describing the requested item (see module doc).",
    )
    args = parser.parse_args(argv)
    try:
        want = json.loads(args.want)
    except json.JSONDecodeError as exc:
        print(f"ERROR: --want is not valid JSON: {exc}", file=sys.stderr)
        return 2

    raw_stdin = sys.stdin.read()
    if not raw_stdin.strip():
        print("ERROR: expected `woolies search --json` payload on stdin", file=sys.stderr)
        return 2
    try:
        payload = json.loads(raw_stdin)
    except json.JSONDecodeError as exc:
        print(f"ERROR: stdin is not valid JSON: {exc}", file=sys.stderr)
        return 2

    result = pick(payload, want)
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
