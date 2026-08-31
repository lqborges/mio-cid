#!/usr/bin/env python3
"""Structural tests for PR-05a Treasury / CampaignClock. Run: python3 tests/unit/test_feed.py

gdUnit4 is not vendored yet. This runner plus tests/unit/test_camp_night.gd
cover feed rules until gdUnit4 v6.2.1 is vendored.
"""

from __future__ import annotations

import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DENY = ("puy", "stornetta", "santa_gadea", "espadero", "flute")


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _advance_plazo_body(source: str) -> str:
    match = re.search(
        r"func advance_plazo\(days: int\) -> void:\n(?P<body>.*?)(?=\nfunc |\Z)",
        source,
        flags=re.DOTALL,
    )
    if match is None:
        return ""
    return match.group("body")


class TestFeedAndClock(unittest.TestCase):
    def test_economy_json_matches_design(self) -> None:
        data = json.loads(_read("data/economy.json"))
        self.assertEqual(data["feed_marks_per_mouth"], 8)
        self.assertEqual(data["horse_marks"], 10)
        self.assertEqual(data["quinto_fraction"], 0.2)
        self.assertEqual(data["mesnada_fraction"], 0.4)
        self.assertEqual(data["treasury_fraction"], 0.4)
        self.assertNotIn("camp_fed_onores", data)
        self.assertNotIn("camp_unfed_onores", data)
        self.assertEqual(data["unfed_streak_hard"], 3)
        self.assertEqual(data["named_captains_fail_below"], 4)
        self.assertTrue(data["horses_follow_fractions"])
        self.assertFalse(data["horses_all_to_treasury"])
        self.assertEqual(data["mouths"], "lanzas + living_named_captains")

    def test_autoloads_have_no_class_name(self) -> None:
        for rel in (
            "game/autoload/treasury_service.gd",
            "game/autoload/campaign_clock.gd",
        ):
            source = _read(rel)
            self.assertRegex(source, re.compile(r"^extends Node$", re.MULTILINE), rel)
            self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE), rel)
        treasury = _read("game/systems/economy/treasury.gd")
        self.assertRegex(treasury, re.compile(r"^class_name Treasury$", re.MULTILINE))
        self.assertIn("@export var marks: int = 0", treasury)
        self.assertIn("@export var horses: int = 2", treasury)
        self.assertIsNone(re.search(r"^(@export )?var unfed_streak\b", treasury, re.MULTILINE))

    def test_clock_owns_unfed_streak_and_feed_gate(self) -> None:
        source = _read("game/autoload/campaign_clock.gd")
        self.assertIn("@export var unfed_streak: int = 0", source)
        self.assertIn("func feeds_tonight() -> bool:", source)
        self.assertIn("Segment.CAMP_NIGHT", source)
        self.assertIn("Segment.REFUSE_48H", source)
        self.assertIn("TreasuryService.camp_night()", source)
        self.assertIn("func advance_plazo(days: int) -> void:", source)
        self.assertIn("func advance_calendar(days: int) -> void:", source)
        honor = _read("game/systems/honor/honor_state.gd")
        self.assertIsNone(re.search(r"^(@export )?var unfed_streak\b", honor, re.MULTILINE))
        service = _read("game/systems/honor/honor_service.gd")
        self.assertIn("CampaignClock.unfed_streak", service)
        self.assertIn("TreasuryService.tunable_int", service)
        self.assertNotIn("economy.json", service)

    def test_advance_plazo_never_calls_camp_night(self) -> None:
        source = _read("game/autoload/campaign_clock.gd")
        body = _advance_plazo_body(source)
        self.assertTrue(body, "advance_plazo missing")
        self.assertNotIn("TreasuryService.camp_night", body)
        self.assertNotIn("camp_night()", body)
        self.assertNotIn("tick_night(", body)
        calendar = re.search(
            r"func advance_calendar\(days: int\) -> void:\n(?P<body>.*?)(?=\nfunc |\Z)",
            source,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(calendar)
        self.assertNotIn("camp_night()", calendar.group("body"))
        self.assertNotIn("TreasuryService", calendar.group("body"))
        plazo_ui = _read("game/ui/plazo_bar.gd")
        self.assertNotIn("camp_night(", plazo_ui)

    def test_camp_night_reads_economy_not_literals(self) -> None:
        source = _read("game/autoload/treasury_service.gd")
        self.assertIn("data/economy.json", source)
        self.assertIn("feed_marks_per_mouth", source)
        self.assertIn("unfed_lanzas_base", source)
        self.assertIn("horses_follow_fractions", source)
        self.assertIn("apply_id(&\"camp_fed\")", source)
        self.assertIn("apply_id(&\"camp_unfed\")", source)
        self.assertIn("func divide_booty(", source)

    def test_menu_and_fail_copy(self) -> None:
        menu = _read("game/ui/main_menu.tscn") + _read("game/ui/main_menu.gd")
        self.assertIn("Nueva partida", menu)
        self.assertIn("Cargar", menu)
        self.assertIn("Salir", menu)
        self.assertIn("func _on_new_game", _read("game/ui/main_menu.gd"))
        fail = _read("game/ui/fail_copy.tscn") + _read("game/ui/fail_copy.gd")
        self.assertIn("the name is empty", fail)
        self.assertIn("you_fell", fail)
        self.assertIn("alfonso_host", fail)
        self.assertIn("name_empty", fail)
        project = _read("project.godot")
        self.assertIn('run/main_scene="res://game/ui/main_menu.tscn"', project)
        self.assertIn("viewport_width=1280", project)
        self.assertIn("viewport_height=720", project)

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            "game/ui/main_menu.gd",
            "game/ui/fail_copy.gd",
            "game/autoload/campaign_clock.gd",
            "game/autoload/treasury_service.gd",
            "data/economy.json",
        ):
            lowered = _read(rel).lower()
            for token in DENY:
                self.assertNotIn(token, lowered, rel)

    def test_event_bus_no_longer_treats_clock_and_treasury_as_stubs(self) -> None:
        source = _read("tests/unit/test_event_bus.py")
        stubs_block = source.split("STUBS = {", 1)[1].split("}", 1)[0]
        self.assertNotIn("CampaignClock", stubs_block)
        self.assertNotIn("TreasuryService", stubs_block)
        self.assertIn("ChapterRunner", stubs_block)

    def test_godot_headless_camp_night_if_available(self) -> None:
        godot = None
        for candidate in ("godot", "godot4"):
            found = subprocess.run(
                ["bash", "-lc", f"command -v {candidate}"],
                check=False,
                capture_output=True,
                text=True,
            )
            if found.returncode == 0 and found.stdout.strip():
                godot = found.stdout.strip()
                break
        if godot is None:
            self.skipTest("Godot binary not on PATH; gdUnit4 not vendored")
        result = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "-s",
                "res://tests/unit/test_camp_night.gd",
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
