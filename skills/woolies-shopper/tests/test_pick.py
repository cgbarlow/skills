"""Tests for the woolies-shopper picker.

The picker takes a `woolies search --json` payload and a `--want` JSON
describing the desired quantity, unit, optional size hint and optional
brand hint. It returns one of:

  - success:    {"sku": ..., "quantity": ..., "unit": ..., "name": ...}
  - ambiguous:  {"ambiguous": true, "candidates": [...]}
  - oos:        {"out_of_stock": true, "candidates": [...]}
  - no_matches: {"no_matches": true}

These tests are the behavioural spec — implement `pick.py` until they
all pass.
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]
PICK = REPO / "scripts" / "pick.py"
FIXTURES = REPO / "tests" / "fixtures"


def run_pick(fixture_name: str, want: dict) -> dict:
    """Run pick.py with a fixture on stdin and a --want JSON. Return parsed stdout."""
    with open(FIXTURES / fixture_name, encoding="utf-8") as fh:
        stdin = fh.read()
    result = subprocess.run(
        [sys.executable, str(PICK), "--want", json.dumps(want)],
        input=stdin,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(
            f"pick.py exited {result.returncode}\nstderr:\n{result.stderr}"
        )
    return json.loads(result.stdout)


class TestPicker(unittest.TestCase):

    def test_picks_in_stock_by_size_match(self):
        # 1L Anchor (269671, on special $3.40), 1L Meadow Fresh,
        # 2L Anchor, 1L Pams (OOS). Without a brand hint, the cheapest
        # in-stock 1L wins on unit-price tiebreak → Anchor 269671.
        out = run_pick("search-milk.json", {"qty": 1, "unit": "Each", "size_hint": "1L"})
        self.assertEqual(out["sku"], "269671")
        self.assertEqual(out["unit"], "Each")
        self.assertEqual(out["quantity"], 1)

    def test_size_hint_excludes_other_sizes(self):
        # Asking for 2L specifically must pick the 2L SKU, even though
        # 1L options are cheaper per-unit.
        out = run_pick("search-milk.json", {"qty": 1, "unit": "Each", "size_hint": "2L"})
        self.assertEqual(out["sku"], "269675")

    def test_brand_hint_wins_over_price(self):
        # Without a hint, the cheapest 1L wins (Anchor 269671 at $3.40
        # special). With a Meadow Fresh hint, Meadow Fresh wins despite
        # being $0.80 more.
        out = run_pick(
            "search-milk.json",
            {"qty": 1, "unit": "Each", "size_hint": "1L", "brand_hint": "Meadow Fresh"},
        )
        self.assertEqual(out["sku"], "210888")

    def test_drops_out_of_stock(self):
        # Pams 1L is the cheapest 1L milk in the fixture but is OOS — it
        # must not be the winner.
        out = run_pick("search-milk.json", {"qty": 1, "unit": "Each", "size_hint": "1L"})
        self.assertNotEqual(out["sku"], "999111")

    def test_all_out_of_stock_reports_oos(self):
        out = run_pick("search-all-oos.json", {"qty": 1, "unit": "Each"})
        self.assertTrue(out.get("out_of_stock"))
        self.assertEqual(len(out["candidates"]), 2)
        # Candidates carry sku+name for the skill to offer alternatives.
        self.assertIn("sku", out["candidates"][0])
        self.assertIn("name", out["candidates"][0])

    def test_no_matches_reports_no_matches(self):
        out = run_pick("search-empty.json", {"qty": 1, "unit": "Each"})
        self.assertTrue(out.get("no_matches"))

    def test_dual_pricing_each_unit(self):
        # Loose carrots support dual pricing. Asking for 3 Each → picks
        # the loose SKU (135344) with unit=Each.
        out = run_pick("search-carrots.json", {"qty": 3, "unit": "Each"})
        self.assertEqual(out["sku"], "135344")
        self.assertEqual(out["unit"], "Each")
        self.assertEqual(out["quantity"], 3)

    def test_dual_pricing_kilogram_unit(self):
        # Asking for 0.45 Kilogram → loose carrots SKU with unit=Kilogram.
        # Fractional qty is only valid when the product supports dual
        # pricing or the unit is Kilogram.
        out = run_pick("search-carrots.json", {"qty": 0.45, "unit": "Kilogram"})
        self.assertEqual(out["sku"], "135344")
        self.assertEqual(out["unit"], "Kilogram")
        self.assertAlmostEqual(out["quantity"], 0.45, places=2)

    def test_ambiguous_when_top_two_close_without_hint(self):
        # 1L Anchor at $3.40 (cup_price) and 1L Meadow Fresh at $4.20.
        # Set tie_threshold to 0.30 (30%) so a $0.80 gap on a $3.40 base
        # is within the threshold → ambiguous.
        out = run_pick(
            "search-milk.json",
            {"qty": 1, "unit": "Each", "size_hint": "1L", "tie_threshold": 0.30},
        )
        self.assertTrue(out.get("ambiguous"))
        skus = {c["sku"] for c in out["candidates"]}
        self.assertIn("269671", skus)
        self.assertIn("210888", skus)

    def test_not_ambiguous_with_brand_hint_breaks_tie(self):
        # Same fixture, same tie threshold, but with a brand hint that
        # promotes Meadow Fresh out of the tie → unambiguous.
        out = run_pick(
            "search-milk.json",
            {
                "qty": 1,
                "unit": "Each",
                "size_hint": "1L",
                "brand_hint": "Meadow Fresh",
                "tie_threshold": 0.30,
            },
        )
        self.assertNotIn("ambiguous", out)
        self.assertEqual(out["sku"], "210888")


if __name__ == "__main__":
    unittest.main()
