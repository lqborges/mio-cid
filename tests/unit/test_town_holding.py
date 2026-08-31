#!/usr/bin/env python3
"""Structural tests for PR-14 keep-or-sell. Run: python3 tests/unit/test_town_holding.py

gdUnit4 is not vendored yet. This runner plus tests/unit/test_town_holding.gd
(headless SceneTree) cover TownHolding until gdUnit4 v6.2.1 is vendored.
"""

from __future__ import annotations

import csv
import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path("/home/lqborges/.local/bin/godot")
DENY = (
    "puy",
    "stornetta",
    "santa_gadea",
    "espadero",
    "flute",
    "reconquista",
    "cruzada",
    "holy-war",
    "holy_war",
    "corpse",
)


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _godot_bin() -> str | None:
    if GODOT.is_file():
        return str(GODOT)
    for candidate in ("godot", "godot4"):
        found = subprocess.run(
            ["bash", "-lc", f"command -v {candidate}"],
            check=False,
            capture_output=True,
            text=True,
        )
        if found.returncode == 0 and found.stdout.strip():
            return found.stdout.strip()
    return None


class TestKeepOrSellTownModule(unittest.TestCase):
    def test_town_holding_resource_loads_json_numbers(self) -> None:
        source = _read("game/systems/travel/town_holding.gd")
        self.assertRegex(source, re.compile(r"^class_name TownHolding$", re.MULTILINE))
        self.assertIn("extends Resource", source)
        self.assertIn("func keep(", source)
        self.assertIn("func sell(", source)
        self.assertIn("func tick_day(", source)
        self.assertIn("divide_booty", source)
        self.assertIn("&\"alfonso_host\"", source)
        self.assertIn("alcocer_keep", _read("data/honor_events/towns.json"))
        self.assertNotIn("800", source)
        self.assertNotIn("sell_deadline_days: int = 3", source)
        self.assertIsNone(re.search(r"^class_name\s", _read("game/autoload/treasury_service.gd"), re.MULTILINE))

        castejon = json.loads(_read("data/towns/castejon.json"))
        self.assertTrue(castejon["alfonso_protectorate"])
        self.assertEqual(castejon["sell_deadline_days"], 0)
        self.assertEqual(castejon["booty"]["marks"], 800)
        self.assertEqual(castejon["booty"]["horses"], 40)
        self.assertEqual(castejon["keep_event_id"], "castejon_keep")
        self.assertEqual(castejon["sell_event_id"], "castejon_sell")

        alcocer = json.loads(_read("data/towns/alcocer.json"))
        self.assertFalse(alcocer["alfonso_protectorate"])
        self.assertEqual(alcocer["sell_deadline_days"], 3)
        self.assertTrue(alcocer["keep_past_deadline_fail"])
        self.assertEqual(alcocer["keep_event_id"], "alcocer_keep")
        self.assertEqual(alcocer["booty"]["marks"], 600)
        self.assertEqual(alcocer["booty"]["horses"], 30)

    def test_towns_honor_events_include_alcocer_keep(self) -> None:
        payload = json.loads(_read("data/honor_events/towns.json"))
        events = {row["id"]: row for row in payload["events"]}
        self.assertIn("alcocer_keep", events)
        keep = events["alcocer_keep"]
        self.assertEqual(keep["deltas"]["honor"], -25)
        self.assertIn("alfonso_wrath", keep["tags"])
        self.assertTrue(keep["hard_fail"])
        self.assertEqual(keep["hard_fail_reason"], "alfonso_host")
        self.assertNotIn("onores", keep["deltas"])
        sell = events["castejon_sell"]
        self.assertEqual(sell["deltas"]["onores"], 10)
        self.assertNotIn("marks", sell.get("deltas", {}))
        schema = json.loads(_read("data/schema/town.json"))
        self.assertEqual(schema["$id"], "mio-cid/town")
        for key in (
            "id",
            "alfonso_protectorate",
            "keep_or_sell",
            "keep_past_deadline_fail",
            "sell_deadline_days",
            "booty",
        ):
            self.assertIn(key, schema["required"])

    def test_ui_spanish_labels_english_keys_720p(self) -> None:
        ui = _read("game/ui/keep_or_sell.gd") + _read("game/ui/keep_or_sell.tscn")
        self.assertRegex(_read("game/ui/keep_or_sell.gd"), re.compile(r"^class_name KeepOrSell$", re.MULTILINE))
        self.assertIn("ui.keep_or_sell.title", ui)
        self.assertIn("ui.keep_or_sell.keep", ui)
        self.assertIn("ui.keep_or_sell.sell", ui)
        self.assertIn("func bind_holding(", _read("game/ui/keep_or_sell.gd"))
        self.assertIn("anchor_right = 1.0", _read("game/ui/keep_or_sell.tscn"))
        self.assertIn("anchor_bottom = 1.0", _read("game/ui/keep_or_sell.tscn"))
        project = _read("project.godot")
        self.assertIn("viewport_width=1280", project)
        self.assertIn("viewport_height=720", project)
        loc = _read("game/autoload/loc.gd")
        self.assertIn("strings.csv", loc)
        path = ROOT / "content/locales/strings.csv"
        with path.open(encoding="utf-8", newline="") as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        self.assertEqual(rows["ui.keep_or_sell.keep"]["es"], "Guardar")
        self.assertEqual(rows["ui.keep_or_sell.sell"]["es"], "Vender")
        self.assertEqual(rows["ui.keep_or_sell.title"]["es"], "¿Guardar o vender?")
        self.assertTrue(rows["ui.keep_or_sell.keep"]["en"])
        self.assertEqual(rows["location.castejon"]["es"], "Castejón")
        fail = _read("game/ui/fail_copy.gd")
        self.assertIn('&"alfonso_host": "the name is empty"', fail)

    def test_no_denylist_tokens(self) -> None:
        rels = [
            "game/systems/travel/town_holding.gd",
            "game/ui/keep_or_sell.gd",
            "game/ui/keep_or_sell.tscn",
            "data/honor_events/towns.json",
            "data/towns/castejon.json",
            "data/towns/alcocer.json",
            "content/locales/strings.csv",
            "tests/unit/test_town_holding.gd",
        ]
        for rel in rels:
            lowered = _read(rel).lower()
            for token in DENY:
                self.assertNotIn(token, lowered, rel)

    def test_godot_headless_town_holding_if_available(self) -> None:
        godot = _godot_bin()
        if godot is None:
            self.skipTest("Godot binary not on PATH; gdUnit4 not vendored")
        result = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "-s",
                "res://tests/unit/test_town_holding.gd",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            result.returncode,
            0,
            result.stdout + "\n" + result.stderr,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
