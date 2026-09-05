#!/usr/bin/env python3
"""Structural tests for PR-08b a1_burgos greybox.

Run: python3 tests/unit/test_a1_burgos.py
"""

from __future__ import annotations

import csv
import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
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
)

CHAPTER = "content/chapters/a1_burgos"


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestA1BurgosGreybox(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/burgos.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/townsfolk.gd",
            "game/ui/hall_whisper.tscn",
            "content/locales/poem_formulas.csv",
            "content/art/characters/cid/cid.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_scene_is_cheap_greybox(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("plazo_bar.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("type=\"DirectionalLight3D\"", scene)
        self.assertEqual(scene.count("type=\"DirectionalLight3D\""), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertIn("type=\"CSGBox3D\"", scene)
        self.assertIn("type=\"CSGCombiner3D\"", scene)
        self.assertGreaterEqual(scene.count("type=\"CSGBox3D\""), 8)
        self.assertIn("ShutterW1", scene)
        self.assertIn("Inn", scene)
        self.assertIn("River", scene)
        self.assertIn("RiverCamp", scene)
        self.assertIn("Child", scene)
        self.assertIn("Innkeeper", scene)
        self.assertIn("BurgalesA", scene)
        camp = scene.split('[node name="Camp"', 1)[1].split("[node name=", 1)[0]
        self.assertNotIn("townsfolk.gd", camp)
        self.assertNotIn("role = \"camp\"", camp)
        self.assertIn("collision_layer = 0", camp)
        world = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func _physics_process", world)
        self.assertIn("camp_on_river", world)
        self.assertIn("_try_camp_on_river", world)
        self.assertIn("burgos_child_heard", world)
        self.assertIn("a1_burgos.hear_child_first", world)
        self.assertIn('ChapterRunner.goto(&"a1_arcas")', world)
        self.assertIn("0, 0.05, 1.5", scene)
        self.assertNotIn("0, 0.05, 6.5", scene)
        phys = world.split("func _physics_process", 1)[1].split("func _travel_to_arcas", 1)[0]
        self.assertIn("if _camped:", phys)
        self.assertIn("_try_camp_on_river()", phys)
        self.assertNotIn("_travel_to_arcas()", phys)
        self.assertNotIn("ChapterRunner.goto", phys)
        self.assertIn("Río", scene)
        folk = _read(f"{CHAPTER}/townsfolk.gd")
        self.assertIn("add_to_group(\"interactable\")", folk)
        self.assertIn("func interact_prompt_key", folk)
        self.assertIn("hud.hear_verb", folk)
        self.assertIn("hud.lodge_verb", folk)
        self.assertIn("func _is_talk_role", folk)
        self.assertIn("return false", folk)
        self.assertNotIn("type=\"OmniLight3D\"", scene)
        self.assertNotIn("type=\"SpotLight3D\"", scene)

    def test_beats_json_sets_shutters_seen(self) -> None:
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a1_burgos")
        flags: list[str] = []
        for step in payload["steps"]:
            flags.extend(step.get("set_flags", []))
        self.assertIn("burgos_shutters_seen", flags)
        world = _read(f"{CHAPTER}/world.gd")
        self.assertIn("burgos_shutters_seen", world)
        self.assertIn("apply_beats", world)
        self.assertIn("beats.json", world)

    def test_dialogue_child_speaks_v20_only(self) -> None:
        text = _read(f"{CHAPTER}/burgos.dialogue")
        self.assertIn("~ child_v20", text)
        self.assertIn("~ innkeeper", text)
        self.assertIn("poem.v20", text)
        self.assertIn("a1_burgos.inn_refused", text)
        self.assertIn("a1_burgos.camp_river", text)
        self.assertNotIn("poem.v9", text)
        self.assertNotIn("{{", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)

    def test_poem_formulas_v20(self) -> None:
        with (ROOT / "content/locales/poem_formulas.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        self.assertIn("poem.v20", rows)
        es = rows["poem.v20"]["es"]
        self.assertIn("buen vassallo", es)
        self.assertIn("buen señor", es)
        self.assertEqual(rows["poem.v20"]["montaner_verse"].strip(), "20")
        self.assertNotIn("poem.v9", rows)

    def test_strings_csv_inn_refusal(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a1_burgos.inn_refused",
            "a1_burgos.camp_river",
            "a1_burgos.steel_drawn",
            "a1_burgos.hear_child_first",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("posada", rows["a1_burgos.inn_refused"]["es"].lower())
        self.assertIn("río", rows["a1_burgos.camp_river"]["es"])
        self.assertIn("Mesura", rows["a1_burgos.steel_drawn"]["es"])

    def test_world_script_mesura_gate(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("draw_steel_on_burgaleses", source)
        self.assertIn("burgos_draw_steel", source)
        self.assertIn("camp_on_river", source)
        self.assertIn("burgos_camp_river", source)
        self.assertIn("can_storm_inn", source)
        self.assertIn("poem.v20", source)
        self.assertIn("whisper_key", source)
        self.assertNotIn("camp_night(", source)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))

    def test_chapter_runner_loads_burgos(self) -> None:
        source = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a1_burgos/world.tscn", source)
        self.assertIn("&\"a1_burgos\"", source)
        vivar = _read("content/chapters/a1_vivar/world.gd")
        self.assertIn("_set_seen", vivar)
        self.assertIn("a1_burgos", vivar)
        self.assertIn("_travel_to_burgos", vivar)
        self.assertIn('ChapterRunner.goto(&"a1_burgos")', vivar)

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/burgos.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/townsfolk.gd",
            "game/autoload/chapter_runner.gd",
            "content/chapters/a1_vivar/world.gd",
        ):
            lowered = _read(rel).lower()
            for token in DENY:
                self.assertNotIn(token, lowered, f"{rel} has {token}")

    def test_godot_headless_if_available(self) -> None:
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
            local = Path("/home/lqborges/.local/bin/godot")
            if local.is_file():
                godot = str(local)
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
                "-s",
                "res://tests/unit/test_a1_burgos.gd",
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
