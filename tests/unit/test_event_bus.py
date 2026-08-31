#!/usr/bin/env python3
"""Structural tests for PR-01 autoloads. Run: python3 tests/unit/test_event_bus.py

gdUnit4 is not vendored yet (addons/gdUnit4 is a placeholder). This runner plus
tests/unit/test_event_bus.gd (headless SceneTree) cover EventBus until gdUnit4
v6.2.1 is vendored.
"""

from __future__ import annotations

import csv
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AUTOLOAD_ORDER = [
    "EventBus",
    "HonorService",
    "SaveService",
    "ChapterRunner",
    "CampaignClock",
    "TreasuryService",
    "GameState",
    "Loc",
]
AUTOLOAD_SCRIPTS = {
    "EventBus": "game/autoload/event_bus.gd",
    "HonorService": "game/autoload/honor_service.gd",
    "SaveService": "game/autoload/save_service.gd",
    "ChapterRunner": "game/autoload/chapter_runner.gd",
    "CampaignClock": "game/autoload/campaign_clock.gd",
    "TreasuryService": "game/autoload/treasury_service.gd",
    "GameState": "game/autoload/game_state.gd",
    "Loc": "game/autoload/loc.gd",
}
STUBS = {
    "HonorService": "game/autoload/honor_service.gd",
    "SaveService": "game/autoload/save_service.gd",
    "ChapterRunner": "game/autoload/chapter_runner.gd",
    "CampaignClock": "game/autoload/campaign_clock.gd",
    "TreasuryService": "game/autoload/treasury_service.gd",
}


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestAutoloadsAndEventBus(unittest.TestCase):
    def test_autoload_order_and_paths(self) -> None:
        text = _read("project.godot")
        self.assertIn("[autoload]", text)
        section = text.split("[autoload]", 1)[1]
        next_section = re.search(r"\n\[", section)
        if next_section:
            section = section[: next_section.start()]
        names = re.findall(
            r'^([A-Za-z][A-Za-z0-9_]+)="\*res://([^"]+)"',
            section,
            flags=re.MULTILINE,
        )
        self.assertEqual([name for name, _path in names], AUTOLOAD_ORDER)
        for name, path in names:
            self.assertEqual(path, AUTOLOAD_SCRIPTS[name])
            self.assertTrue((ROOT / path).is_file(), path)

    def test_event_bus_has_soft_warn_and_hard_fail(self) -> None:
        source = _read("game/autoload/event_bus.gd")
        self.assertRegex(source, re.compile(r"^extends Node", re.MULTILINE))
        self.assertRegex(
            source,
            re.compile(r"^signal soft_warn\(reason: StringName\)$", re.MULTILINE),
        )
        self.assertRegex(
            source,
            re.compile(r"^signal hard_fail\(reason: StringName\)$", re.MULTILINE),
        )
        self.assertNotEqual(
            source.find("signal soft_warn"),
            source.find("signal hard_fail"),
        )

    def test_event_bus_gd_test_parses(self) -> None:
        source = _read("tests/unit/test_event_bus.gd")
        self.assertIn("extends SceneTree", source)
        self.assertIn("EventBus.soft_warn", source)
        self.assertIn("EventBus.hard_fail", source)
        self.assertIn("cannot_feed", source)
        self.assertIn("name_empty", source)
        self.assertNotIn("load(\"res://game/autoload/event_bus.gd\")", source)

    def test_service_stubs_are_empty_nodes(self) -> None:
        for _name, rel in STUBS.items():
            source = _read(rel)
            self.assertRegex(source, re.compile(r"^extends Node\s*$", re.MULTILINE), rel)
            self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE), rel)
            statements = [
                line.strip()
                for line in source.splitlines()
                if line.strip() and not line.strip().startswith("#")
            ]
            self.assertEqual(statements, ["extends Node"], rel)

    def test_autoload_scripts_do_not_reuse_singleton_class_name(self) -> None:
        for name, rel in AUTOLOAD_SCRIPTS.items():
            source = _read(rel)
            self.assertIsNone(
                re.search(rf"^class_name\s+{re.escape(name)}\b", source, re.MULTILINE),
                rel,
            )

    def test_game_state_is_facade_without_stored_state(self) -> None:
        source = _read("game/autoload/game_state.gd")
        self.assertRegex(source, re.compile(r"^extends Node", re.MULTILINE))
        for getter in (
            "func honor(",
            "func treasury(",
            "func roster(",
            "func clock(",
            "func chapter_id(",
            "func flags(",
        ):
            self.assertIn(getter, source)
        # Facade only: no exported/cached game fields.
        self.assertIsNone(re.search(r"^@export", source, re.MULTILINE))
        self.assertIsNone(re.search(r"^var ", source, re.MULTILINE))

    def test_poem_formulas_csv_has_montaner_v20(self) -> None:
        path = ROOT / "content/locales/poem_formulas.csv"
        with path.open(encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle))
        self.assertEqual(
            rows[0]["es"],
            "«Dios, qué buen vassallo, si oviesse buen señor»",
        )
        self.assertEqual(rows[0]["en"].strip(), "God, what a good vassal, if he had a good lord")
        self.assertEqual(rows[0]["montaner_verse"].strip(), "20")
        self.assertTrue(rows[0]["key"])

    def test_loc_defaults_to_spanish(self) -> None:
        source = _read("game/autoload/loc.gd")
        self.assertIn('DEFAULT_LOCALE := "es"', source)
        self.assertIn("poem_formulas.csv", source)
        self.assertIn("TranslationServer.set_locale(DEFAULT_LOCALE)", source)

    def test_godot_headless_event_bus_if_available(self) -> None:
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
                "res://tests/unit/test_event_bus.gd",
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
