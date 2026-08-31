#!/usr/bin/env python3
"""Structural tests for PR-16b booty division UI.

Run: python3 tests/unit/test_booty_divide.py
"""

from __future__ import annotations

import csv
import json
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from validate_graph import can_travel, load_graph, main as validate_main  # noqa: E402

DENY = (
    "puy",
    "stornetta",
    "santa gadea",
    "santa_gadea",
    "espadero",
    "flute",
    "babieca",
    "jura",
    "heston",
    "corpse",
    "reconquista",
    "holy-war",
    "holy_war",
)


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _godot_bin() -> str | None:
    local = Path("/home/lqborges/.local/bin/godot")
    if local.is_file():
        return str(local)
    home = Path.home() / ".local/bin/godot"
    if home.is_file():
        return str(home)
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


class TestBootyDivide(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            "game/ui/booty_divide.tscn",
            "game/ui/booty_divide.gd",
            "game/systems/economy/booty_split.gd",
            "game/autoload/treasury_service.gd",
            "data/economy.json",
            "content/chapters/a1_alcocer/world.tscn",
            "content/chapters/a1_castejon/world.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_ui_reads_fractions_via_treasury(self) -> None:
        ui = _read("game/ui/booty_divide.gd")
        self.assertRegex(ui, re.compile(r"^class_name BootyDivide$", re.MULTILINE))
        self.assertIn("preview_booty", ui)
        self.assertIn("divide_booty", ui)
        self.assertIn("ui.booty_divide.title", ui)
        self.assertIn("gift_alvar", ui)
        self.assertNotIn("economy.json", ui)
        self.assertNotIn("0.2", ui)
        self.assertNotIn("800", ui)
        self.assertNotIn("160", ui)
        self.assertNotIn("func _enter_tree", ui)
        split = _read("game/systems/economy/booty_split.gd")
        self.assertRegex(split, re.compile(r"^class_name BootySplit$", re.MULTILINE))
        self.assertIn("quinto_fraction", split)
        self.assertIn("horses_follow_fractions", split)
        self.assertNotIn("economy.json", split)
        treasury = _read("game/autoload/treasury_service.gd")
        self.assertIn("func preview_booty(", treasury)
        self.assertIn("func divide_booty(", treasury)
        self.assertIn("gift_to_alvar", treasury)
        self.assertIn("alvar_fanez", treasury)
        scene = _read("game/ui/booty_divide.tscn")
        self.assertIn("anchor_right = 1.0", scene)
        self.assertIn("anchor_bottom = 1.0", scene)
        self.assertIn("GiftAlvar", scene)
        self.assertIn("Confirm", scene)

    def test_economy_fractions_and_town_piles(self) -> None:
        data = json.loads(_read("data/economy.json"))
        self.assertEqual(data["quinto_fraction"], 0.2)
        self.assertEqual(data["mesnada_fraction"], 0.4)
        self.assertEqual(data["treasury_fraction"], 0.4)
        self.assertTrue(data["horses_follow_fractions"])
        castejon = json.loads(_read("data/towns/castejon.json"))
        self.assertEqual(castejon["booty"]["marks"], 800)
        self.assertEqual(castejon["booty"]["horses"], 40)
        alcocer = json.loads(_read("data/towns/alcocer.json"))
        self.assertFalse(alcocer["alfonso_protectorate"])
        self.assertEqual(alcocer["sell_deadline_days"], 3)
        self.assertEqual(alcocer["sell_event_id"], "alcocer_sell")
        towns = json.loads(_read("data/honor_events/towns.json"))
        events = {row["id"]: row for row in towns["events"]}
        self.assertEqual(events["alcocer_sell"]["deltas"]["onores"], 10)
        core = json.loads(_read("data/honor_events/core.json"))
        core_events = {row["id"]: row for row in core["events"]}
        self.assertEqual(core_events["gift_to_alvar"]["deltas"]["honra"], 3)

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "ui.booty_divide.title",
            "ui.booty_divide.quinto",
            "ui.booty_divide.mesnada",
            "ui.booty_divide.treasury",
            "ui.booty_divide.marks",
            "ui.booty_divide.horses",
            "ui.booty_divide.gift_alvar",
            "ui.booty_divide.confirm",
            "a1_alcocer.sell_done",
            "a1_alcocer.divide_done",
            "a1_alcocer.gift_alvar",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertEqual(rows["ui.booty_divide.title"]["es"], "Reparto del botín")
        self.assertEqual(rows["ui.booty_divide.confirm"]["es"], "Confirmar")
        self.assertEqual(rows["ui.booty_divide.marks"]["es"], "marcos")
        self.assertEqual(rows["ui.booty_divide.horses"]["es"], "caballos")
        self.assertIn("Álvar", rows["ui.booty_divide.gift_alvar"]["es"])
        self.assertIn("Alcocer", rows["a1_alcocer.sell_done"]["es"])

    def test_alcocer_and_castejon_wire_ui(self) -> None:
        alcocer_scene = _read("content/chapters/a1_alcocer/world.tscn")
        self.assertIn("keep_or_sell.tscn", alcocer_scene)
        self.assertIn("booty_divide.tscn", alcocer_scene)
        self.assertIn("KeepOrSell", alcocer_scene)
        self.assertIn("BootyDivide", alcocer_scene)
        alcocer = _read("content/chapters/a1_alcocer/world.gd")
        self.assertIn("alcocer_booty_divided", alcocer)
        self.assertIn("func confirm_divide", alcocer)
        self.assertIn("func run_divide", alcocer)
        self.assertIn("defer_split", alcocer)
        self.assertNotIn("func _enter_tree", alcocer)
        self.assertNotIn("800", alcocer)
        castejon_scene = _read("content/chapters/a1_castejon/world.tscn")
        self.assertIn("booty_divide.tscn", castejon_scene)
        castejon = _read("content/chapters/a1_castejon/world.gd")
        self.assertIn("func confirm_divide", castejon)
        self.assertIn("defer_split", castejon)
        beats = json.loads(_read("content/chapters/a1_alcocer/beats.json"))
        types = [step.get("type") for step in beats["steps"] if isinstance(step, dict)]
        self.assertIn("keep_or_sell", types)
        self.assertIn("booty_divide", types)
        flags = []
        for step in beats["steps"]:
            if isinstance(step, dict):
                flags.extend(step.get("set_flags", []))
        self.assertIn("alcocer_booty_divided", flags)

    def test_embassy_unlock_requires_divide_flag(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        locked = ["hub_lock_cardena"]
        self.assertFalse(can_travel(graph, "a1_alcocer", "a1_embassy1", locked))
        self.assertTrue(
            can_travel(
                graph,
                "a1_alcocer",
                "a1_embassy1",
                locked + ["alcocer_booty_divided"],
            )
        )
        self.assertFalse(
            can_travel(
                graph,
                "a1_alcocer",
                "a1_cardena",
                locked + ["alcocer_booty_divided"],
            )
        )

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            "game/ui/booty_divide.gd",
            "game/ui/booty_divide.tscn",
            "game/systems/economy/booty_split.gd",
            "tests/unit/test_booty_divide.gd",
            "content/chapters/a1_alcocer/world.gd",
            "content/locales/strings.csv",
        ):
            lowered = _read(rel).lower()
            for token in DENY:
                self.assertNotIn(token, lowered, f"{rel} has {token}")

    def test_godot_headless_if_available(self) -> None:
        godot = _godot_bin()
        if godot is None:
            self.skipTest("Godot binary not on PATH")
        if not (ROOT / ".godot").is_dir():
            self.skipTest("Godot import cache missing")
        result = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "--audio-driver",
                "Dummy",
                "-s",
                "res://tests/unit/test_booty_divide.gd",
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
