#!/usr/bin/env python3
"""Structural tests for PR-03 honor meters. Run: python3 tests/unit/test_honor_state.py

gdUnit4 is not vendored yet. This runner plus tests/unit/test_honor_state.gd
(headless SceneTree) cover HonorState until gdUnit4 v6.2.1 is vendored.
"""

from __future__ import annotations

import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SWORD_ITEM_IDS = ("colada", "tizona")
PUY_DENY = ("puy", "babieca", "santa_gadea", "espadero", "stornetta")


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestHonorMeters(unittest.TestCase):
    def test_honor_event_is_deltas_map_not_meter_field(self) -> None:
        source = _read("game/systems/honor/honor_event.gd")
        self.assertRegex(source, re.compile(r"^class_name HonorEvent$", re.MULTILINE))
        self.assertIn("@export var deltas: Dictionary", source)
        self.assertIsNone(re.search(r"^@export var meter\b", source, re.MULTILINE))
        self.assertIn("func delta_for(meter: StringName) -> float:", source)

        schema = json.loads(_read("data/schema/honor_event.json"))
        self.assertEqual(schema["required"], ["id", "deltas", "tags"])
        self.assertIn("onores", schema["properties"]["deltas"]["properties"])
        self.assertIn("honor", schema["properties"]["deltas"]["properties"])
        self.assertIn("honra", schema["properties"]["deltas"]["properties"])
        self.assertNotIn("meter", schema["properties"])
        self.assertNotIn("meter", schema["properties"]["deltas"]["properties"])

    def test_honor_state_starting_values_and_no_unfed_streak(self) -> None:
        source = _read("game/systems/honor/honor_state.gd")
        self.assertRegex(source, re.compile(r"^class_name HonorState$", re.MULTILINE))
        self.assertIn("@export var onores: float = 8.0", source)
        self.assertIn("@export var honor: float = 15.0", source)
        self.assertIn("@export var honra: float = 40.0", source)
        self.assertIn("func apply(event: HonorEvent) -> Dictionary:", source)
        self.assertIn("func reset() -> void:", source)
        self.assertIn("func has_stain(id: StringName) -> bool:", source)
        self.assertIsNone(re.search(r"^(@export )?var unfed_streak\b", source, re.MULTILINE))
        self.assertIn('result["soft_warn"]', source)
        self.assertIn('result["hard_fail"]', source)
        self.assertIn('result["soft_warn"] = &"honra_stolen"', source)
        self.assertIn("elif onores <= 0.0:", source)
        self.assertIn("elif honra < 10.0:", source)

    def test_honor_service_has_no_class_name_and_no_combat_treasury(self) -> None:
        autoload = _read("game/autoload/honor_service.gd")
        impl = _read("game/systems/honor/honor_service.gd")
        self.assertIsNone(re.search(r"^class_name\s", autoload, re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", impl, re.MULTILINE))
        self.assertIn('extends "res://game/systems/honor/honor_service.gd"', autoload)
        self.assertIn("core.json", impl)
        self.assertIn("EventBus.soft_warn", impl)
        self.assertIn("EventBus.hard_fail", impl)
        self.assertIn("state.reset()", impl)
        self.assertNotIn("_uncurable_honra", impl)
        self.assertNotIn("Treasury", impl)
        self.assertNotIn("CidCombat", impl)
        state_src = _read("game/systems/honor/honor_state.gd")
        self.assertIsNone(re.search(r"^(@export )?var unfed_streak\b", state_src, re.MULTILINE))

    def test_core_json_multi_meter_and_no_swords(self) -> None:
        payload = json.loads(_read("data/honor_events/core.json"))
        events = {row["id"]: row for row in payload["events"]}
        cheat = events["arcas_cheat"]
        self.assertEqual(cheat["deltas"]["onores"], 22)
        self.assertEqual(cheat["deltas"]["honra"], -6)
        self.assertNotIn("honor", cheat["deltas"])
        self.assertNotIn("meter", cheat)
        keep = events["castejon_keep"]
        self.assertTrue(keep["hard_fail"])
        self.assertEqual(keep["hard_fail_reason"], "alfonso_wrath")
        unfed = events["camp_unfed"]
        self.assertEqual(unfed["deltas"]["onores"], -8)
        self.assertFalse(unfed.get("hard_fail", False))
        corpes = events["corpes_news"]
        self.assertIn("uncurable_by_combat", corpes["tags"])
        self.assertEqual(corpes.get("stain_id"), "uncurable_by_combat")
        self.assertEqual(events["toledo_ask1_swords"].get("clear_stain"), "uncurable_by_combat")
        for forbidden in SWORD_ITEM_IDS:
            self.assertNotIn(forbidden, events)
        for event_id in events:
            lowered = event_id.lower()
            for token in PUY_DENY:
                self.assertNotIn(token, lowered, event_id)
        for row in payload["events"]:
            self.assertIn("id", row)
            self.assertIn("deltas", row)
            self.assertIn("tags", row)
            self.assertIsInstance(row["deltas"], dict)
            for key in row["deltas"]:
                self.assertIn(key, ("onores", "honor", "honra"))

    def test_hud_scenes_exist_and_are_colorblind(self) -> None:
        for rel in (
            "game/ui/honor_meters.tscn",
            "game/ui/hall_whisper.tscn",
            "game/ui/plazo_bar.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        meters = _read("game/ui/honor_meters.gd")
        self.assertIn("&\"hatch\"", meters)
        self.assertIn("&\"dots\"", meters)
        self.assertIn("&\"chevron\"", meters)
        self.assertIn("&\"chest\"", meters)
        self.assertIn("&\"seal\"", meters)
        self.assertIn("&\"beard\"", meters)
        plazo = _read("game/ui/plazo_bar.gd")
        self.assertNotIn("camp_night(", plazo)
        self.assertNotIn("Treasury", plazo)
        self.assertIn("MAX_DAYS := 9", plazo)

    def test_godot_headless_honor_state_if_available(self) -> None:
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
                "res://tests/unit/test_honor_state.gd",
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
