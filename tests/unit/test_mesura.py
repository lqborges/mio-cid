#!/usr/bin/env python3
"""Structural tests for PR-21 mesura component and ira dump.

Run: python3 tests/unit/test_mesura.py
"""

from __future__ import annotations

import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUY_DENY = ("puy", "babieca", "santa_gadea", "espadero", "stornetta", "flute")
BLIZZARD_DENY = (
    "warcraft",
    "frostmourne",
    "hellscream",
    "marca",
    "hunger",
    "fury",
)
DESIGNER_LITERALS = ("0.92", "1.15", "220", "-12", "0.45", "0.7")


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _load_json(rel: str) -> dict:
    return json.loads(_read(rel))


class TestMesura(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            "game/actors/player/mesura_component.gd",
            "game/ui/mesura_hud.gd",
            "game/ui/mesura_hud.tscn",
            "data/mesura_traits.json",
            "data/schema/mesura_traits.json",
            "content/locales/strings.csv",
            "tests/unit/test_mesura.gd",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_class_names_are_not_autoloads(self) -> None:
        self.assertRegex(
            _read("game/actors/player/mesura_component.gd"),
            re.compile(r"^class_name MesuraComponent$", re.MULTILINE),
        )
        self.assertRegex(
            _read("game/ui/mesura_hud.gd"),
            re.compile(r"^class_name MesuraHud$", re.MULTILINE),
        )
        project = _read("project.godot")
        self.assertNotIn("MesuraComponent=", project)
        self.assertNotIn("MesuraHud=", project)
        self.assertIn("HonorService=", project)
        self.assertIsNone(
            re.search(r"^class_name\s", _read("game/autoload/honor_service.gd"), re.MULTILINE)
        )
        self.assertIsNone(
            re.search(r"^class_name\s", _read("game/systems/honor/honor_service.gd"), re.MULTILINE)
        )

    def test_traits_json_owns_numbers(self) -> None:
        traits = _load_json("data/mesura_traits.json")
        schema = _load_json("data/schema/mesura_traits.json")
        for key in schema["required"]:
            self.assertIn(key, traits)
        self.assertEqual(traits["trait_cap"], 6)
        self.assertEqual(len(traits["traits"]), 6)
        ids = [row["id"] for row in traits["traits"]]
        self.assertEqual(
            ids,
            [
                "hablar_poco",
                "dejar_golpear",
                "mesa_para_el_conde",
                "querella_not_hueste",
                "gift_the_fifth",
                "keep_avengalvon",
            ],
        )
        self.assertLess(traits["dump_honra"], 0)
        self.assertNotIn("onores", traits)
        source = _read("game/actors/player/mesura_component.gd")
        for literal in DESIGNER_LITERALS:
            self.assertNotIn(literal, source, literal)
        self.assertIn("TRAITS_PATH", source)
        self.assertIn("mesura_traits.json", source)
        self.assertIn("dump_honra", source)

    def test_rage_dump_event_sinks_honra_only(self) -> None:
        payload = _load_json("data/honor_events/core.json")
        events = {row["id"]: row for row in payload["events"]}
        self.assertIn("rage_dump", events)
        dump = events["rage_dump"]
        self.assertEqual(dump["deltas"].get("honra"), _load_json("data/mesura_traits.json")["dump_honra"])
        self.assertNotIn("onores", dump["deltas"])
        self.assertNotIn("honor", dump["deltas"])
        self.assertIn("mesura_fail", dump["tags"])
        self.assertLess(dump["deltas"]["honra"], 0)

    def test_hud_is_simple_and_spanish(self) -> None:
        hud = _read("game/ui/mesura_hud.gd")
        scene = _read("game/ui/mesura_hud.tscn")
        self.assertIn("hud.mesura", hud)
        self.assertIn("hud.ira", hud)
        self.assertIn("extends Control", hud)
        self.assertEqual(scene.count("[node "), 1)
        self.assertNotIn("MarginContainer", scene)
        self.assertNotIn("VBoxContainer", scene)
        self.assertNotIn("ProgressBar", scene)
        strings = _read("content/locales/strings.csv")
        self.assertIn("hud.mesura,Mesura,Mesura", strings)
        self.assertIn("hud.ira,Ira,Ira", strings)
        loc = _read("game/autoload/loc.gd")
        self.assertIn("strings.csv", loc)
        self.assertIn("poem_formulas.csv", loc)
        hud_rows = "\n".join(
            line
            for line in strings.splitlines()
            if line.startswith("hud.mesura") or line.startswith("hud.ira")
        )
        lowered = (hud + hud_rows).lower()
        for token in BLIZZARD_DENY:
            self.assertNotIn(token, lowered, token)
        self.assertNotIn("Rage", hud)
        self.assertNotIn("Hunger", hud)

    def test_wired_into_controller_combat_camera_intact(self) -> None:
        controller = _read("game/actors/player/cid_controller.gd")
        combat = _read("game/actors/player/cid_combat.gd")
        mesura = _read("game/actors/player/mesura_component.gd")
        cid = _read("content/art/characters/cid/cid.tscn")
        self.assertIn("mesura_component.gd", cid)
        self.assertIn('name="Mesura"', cid)
        self.assertIn("try_dump", controller)
        self.assertIn("set_holding", controller)
        self.assertIn('is_action_pressed("mesura")', controller)
        self.assertIn("dump_strike", combat)
        self.assertIn("try_parry", combat)
        self.assertIn("stamina_regen_mult", combat)
        self.assertIn("func slam(", combat)
        self.assertIn("func lower_weapon(", combat)
        self.assertIn("Engine.time_scale", mesura)
        self.assertIn("dump_honra_min", mesura)
        self.assertIn("dump_honra_max", mesura)
        self.assertIn("rotate_in_cooldown_sec", mesura)
        self.assertIn('move.get("stamina"', combat)
        self.assertIn("_lock_isometric_camera", controller)
        self.assertNotIn("SpringArm3D", controller)
        self.assertNotIn("SpringArm3D", cid)
        project = _read("project.godot")
        self.assertIn("mesura={", project)
        self.assertIn("rage_dump={", project)
        arena = _read("content/chapters/_dev/arena.tscn")
        self.assertIn("mesura_hud.tscn", arena)
        self.assertIn('name="MesuraHud"', arena)

    def test_filenames_are_not_denylist(self) -> None:
        for rel in (
            "game/actors/player/mesura_component.gd",
            "game/ui/mesura_hud.gd",
            "data/mesura_traits.json",
        ):
            lowered = rel.lower()
            for token in PUY_DENY:
                self.assertNotIn(token, lowered, rel)

    def test_godot_headless_mesura_if_available(self) -> None:
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
        deps = Path("/tmp/grok-lqborges/deps/godot-unz/Godot_v4.7.2-stable_linux.x86_64")
        if godot is None and deps.is_file():
            godot = str(deps)
        if godot is None:
            self.skipTest("Godot binary not on PATH; gdUnit4 not vendored")
        result = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "--audio-driver",
                "Dummy",
                "-s",
                "res://tests/unit/test_mesura.gd",
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
