#!/usr/bin/env python3
"""Structural tests for PR-07 Dialogue Manager 4.x.

Run: python3 tests/unit/test_dialogue_bridge.py
"""

from __future__ import annotations

import csv
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLUGIN_CFG = ROOT / "addons/dialogue_manager/plugin.cfg"
BRIDGE = ROOT / "game/systems/speech/dialogue_bridge.gd"
STRINGS = ROOT / "content/locales/strings.csv"
SMOKE = ROOT / "content/chapters/_dev/smoke.dialogue"
PROJECT = ROOT / "project.godot"


class TestDialogueManagerVendor(unittest.TestCase):
    def test_plugin_pin_is_v4_0_3(self) -> None:
        self.assertTrue(PLUGIN_CFG.is_file(), PLUGIN_CFG)
        text = PLUGIN_CFG.read_text(encoding="utf-8")
        self.assertIn('name="Dialogue Manager"', text)
        self.assertIn('version="4.0.3"', text)
        self.assertIn('script="plugin.gd"', text)

    def test_plugin_enabled_in_project(self) -> None:
        text = PROJECT.read_text(encoding="utf-8")
        self.assertIn("[editor_plugins]", text)
        self.assertIn(
            'enabled=PackedStringArray("res://addons/dialogue_manager/plugin.cfg")',
            text,
        )
        self.assertIn(
            'DialogueManager="*res://addons/dialogue_manager/dialogue_manager.gd"',
            text,
        )


class TestStringsCsv(unittest.TestCase):
    def test_header_is_key_es_en(self) -> None:
        with STRINGS.open(encoding="utf-8", newline="") as handle:
            reader = csv.reader(handle)
            header = next(reader)
        self.assertEqual(header, ["key", "es", "en"])

    def test_smoke_keys_have_spanish_and_english(self) -> None:
        with STRINGS.open(encoding="utf-8", newline="") as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in ("_dev.smoke.child", "_dev.smoke.alvar", "_dev.smoke.cid"):
            self.assertIn(key, rows)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("Burgos", rows["_dev.smoke.child"]["es"])
        self.assertIn("mesnada", rows["_dev.smoke.alvar"]["es"])


class TestSmokeDialogue(unittest.TestCase):
    def test_uses_csv_keys_and_line_tags(self) -> None:
        text = SMOKE.read_text(encoding="utf-8")
        self.assertIn("~ start", text)
        self.assertIn("_dev.smoke.child", text)
        self.assertIn("_dev.smoke.alvar", text)
        self.assertIn("_dev.smoke.cid", text)
        self.assertIn("[#flag_set=smoke_seen]", text)
        self.assertIn("[#honor_event=burgos_camp_river]", text)
        denylist = (
            "Puy du Fou",
            "Santa Gadea",
            "Espadero",
            "flute",
            "Babieca",
            "Jura",
        )
        for banned in denylist:
            self.assertNotIn(banned, text)


class TestDialogueBridge(unittest.TestCase):
    def test_maps_tags_with_has_method_guards(self) -> None:
        source = BRIDGE.read_text(encoding="utf-8")
        self.assertRegex(source, re.compile(r"^class_name DialogueBridge", re.MULTILINE))
        self.assertIn("HonorService.has_method(\"apply\")", source)
        self.assertIn("HonorService.apply", source)
        self.assertIn("EventBus.honor_logged", source)
        self.assertIn("has_method(\"set_flag\")", source)
        self.assertIn("honor_event", source)
        self.assertIn("flag_set", source)
        self.assertNotIn("SpeechTrial", source)
        self.assertNotIn("loc_lint", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
