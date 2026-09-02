#!/usr/bin/env python3
"""Structural tests for PR-09 a1_arcas sand-chest encounter.

Run: python3 tests/unit/test_a1_arcas.py
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

CHAPTER = "content/chapters/a1_arcas"


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestA1ArcasSandChest(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/arcas.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/lenders.gd",
            f"{CHAPTER}/choice_ui.tscn",
            f"{CHAPTER}/choice_ui.gd",
            f"{CHAPTER}/desertion_ticker.tscn",
            f"{CHAPTER}/desertion_ticker.gd",
            "data/honor_events/arcas.json",
            "data/characters/raquel.json",
            "data/characters/vidas.json",
            "data/characters/martin_antolinez.json",
            "content/art/characters/cid/cid.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_scene_is_cheap_greybox(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("plazo_bar.tscn", scene)
        self.assertIn('type="DirectionalLight3D"', scene)
        self.assertEqual(scene.count('type="DirectionalLight3D"'), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertIn('type="CSGBox3D"', scene)
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 6)
        self.assertIn("SandChestA", scene)
        self.assertIn("SandChestB", scene)
        self.assertIn("River", scene)
        self.assertIn("Raquel", scene)
        self.assertIn("Vidas", scene)
        self.assertIn("Martin", scene)
        self.assertIn("ChoiceUI", scene)
        self.assertIn("DesertionTicker", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("HallWhisper", scene)
        self.assertIn('character_id = &"raquel"', scene)
        self.assertIn('character_id = &"vidas"', scene)
        self.assertIn('character_id = &"martin_antolinez"', scene)
        self.assertNotEqual(
            scene.find('character_id = &"raquel"'),
            scene.find('character_id = &"vidas"'),
        )

    def test_arcas_json_matches_design_tables(self) -> None:
        payload = json.loads(_read("data/honor_events/arcas.json"))
        self.assertEqual(payload["cheat_marks"], 600)
        self.assertAlmostEqual(float(payload["martin_loyalty_delta"]), 0.08)
        events = {row["id"]: row for row in payload["events"]}
        cheat = events["arcas_cheat"]
        self.assertEqual(cheat["deltas"]["onores"], 22)
        self.assertEqual(cheat["deltas"]["honra"], -6)
        self.assertNotIn("honor", cheat["deltas"])
        self.assertEqual(cheat.get("stain_id"), "arcas_cheat")
        self.assertIn("arcas_cheated", cheat.get("flags_set", []))
        self.assertIn("allowed_crime", cheat["tags"])
        self.assertEqual(cheat.get("beat"), "a1_arcas")
        refuse = events["arcas_refuse"]
        self.assertEqual(refuse["deltas"]["honra"], 3)
        self.assertNotIn("onores", refuse["deltas"])
        self.assertNotIn("stain_id", refuse)
        self.assertFalse(refuse.get("flags_set"))
        self.assertIn("kept_word", refuse["tags"])
        self.assertIn("poverty", refuse["tags"])
        self.assertEqual(refuse.get("beat"), "a1_arcas")

    def test_raquel_and_vidas_are_separate_ids(self) -> None:
        raquel = json.loads(_read("data/characters/raquel.json"))
        vidas = json.loads(_read("data/characters/vidas.json"))
        self.assertEqual(raquel["id"], "raquel")
        self.assertEqual(vidas["id"], "vidas")
        self.assertNotEqual(raquel["id"], vidas["id"])
        self.assertEqual(raquel["role"], "usurer")
        self.assertEqual(vidas["role"], "usurer")
        martin = json.loads(_read("data/characters/martin_antolinez.json"))
        self.assertEqual(martin["id"], "martin_antolinez")

    def test_world_script_is_a_real_branch(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func choose_cheat", source)
        self.assertIn("func choose_refuse", source)
        self.assertIn("arcas_cheat", source)
        self.assertIn("arcas_refuse", source)
        self.assertIn("run_refuse_48h", source)
        self.assertIn("cheat_marks", source)
        self.assertIn("arcas_cheated", source)
        self.assertIn("_confirm_choice", source)
        self.assertIn("_free_balloon", source)
        self.assertIn("_choice_visible", source)
        choice = _read(f"{CHAPTER}/choice_ui.gd")
        self.assertIn("modal_choice", choice)
        self.assertIn("hud_click_sink", choice)
        self.assertIn("a1_arcas.cheat_done", source)
        self.assertIn("a1_arcas.refuse_done", source)
        start = source.split("func start_offer", 1)[1].split("func run_offer", 1)[0]
        self.assertIn("_hide_choice()", start)
        self.assertIn("_choice_visible", start)
        self.assertIn("_try_balloon", start)
        cheat = source.split("func choose_cheat", 1)[1].split("func choose_refuse", 1)[0]
        self.assertIn("_confirm_choice", cheat)
        self.assertNotIn("_finish_beat()", cheat)
        self.assertNotIn("_travel_to_cardena()", cheat)
        refuse = source.split("func choose_refuse", 1)[1].split("func cheated", 1)[0]
        self.assertIn("_confirm_choice", refuse)
        self.assertNotIn("_finish_beat()", refuse)
        self.assertNotIn("_travel_to_cardena()", refuse)
        confirm = source.split("func _confirm_choice", 1)[1].split("func _whisper", 1)[0]
        self.assertIn("_try_balloon", confirm)
        self.assertIn("_travel_to_cardena", confirm)
        ended = source.split("func _on_dialogue_ended", 1)[1].split("func _try_balloon", 1)[0]
        self.assertIn("_show_choice()", ended)
        self.assertIn("_travel_to_cardena", ended)
        self.assertIn("_resolved", ended)
        self.assertNotIn("camp_night(", source)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        honor = _read("game/systems/honor/honor_service.gd")
        self.assertIn("arcas.json", honor)
        self.assertIn("core.json", honor)

    def test_strings_csv_spanish_choice(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a1_arcas.prompt",
            "a1_arcas.martin_offer",
            "a1_arcas.raquel_ask",
            "a1_arcas.vidas_ask",
            "a1_arcas.choice_cheat",
            "a1_arcas.choice_refuse",
            "a1_arcas.cheat_done",
            "a1_arcas.refuse_done",
            "a1_arcas.ticker_title",
            "char.raquel",
            "char.vidas",
            "char.martin_antolinez",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("arena", rows["a1_arcas.choice_cheat"]["es"].lower())
        self.assertIn("Rehusar", rows["a1_arcas.choice_refuse"]["es"])
        self.assertIn("Raquel", rows["char.raquel"]["es"])
        self.assertIn("Vidas", rows["char.vidas"]["es"])
        self.assertIn("Martín", rows["char.martin_antolinez"]["es"])
        self.assertIn("Deserción", rows["a1_arcas.ticker_title"]["es"])

    def test_dialogue_names_raquel_and_vidas_apart(self) -> None:
        text = _read(f"{CHAPTER}/arcas.dialogue")
        self.assertIn("~ offer", text)
        self.assertIn("~ cheat", text)
        self.assertIn("~ refuse", text)
        self.assertIn("Raquel:", text)
        self.assertIn("Vidas:", text)
        self.assertIn("Martín:", text)
        self.assertIn("a1_arcas.raquel_ask", text)
        self.assertIn("a1_arcas.vidas_ask", text)
        self.assertIn("a1_arcas.cheat_done", text)
        self.assertIn("a1_arcas.refuse_done", text)
        self.assertNotIn("Raquel y Vidas:", text)
        self.assertNotIn("{{", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)

    def test_chapter_runner_loads_arcas(self) -> None:
        source = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a1_arcas/world.tscn", source)
        self.assertIn('&"a1_arcas"', source)
        burgos = _read("content/chapters/a1_burgos/world.gd")
        self.assertIn("a1_arcas", burgos)
        self.assertIn("_travel_to_arcas", burgos)
        travel = burgos.split("func _travel_to_arcas", 1)[1].split("func draw_steel", 1)[0]
        self.assertIn("_set_flag", travel)
        self.assertIn('ChapterRunner.goto(&"a1_arcas")', travel)

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/arcas.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/lenders.gd",
            f"{CHAPTER}/choice_ui.gd",
            f"{CHAPTER}/desertion_ticker.gd",
            "data/honor_events/arcas.json",
            "game/autoload/chapter_runner.gd",
            "content/chapters/a1_burgos/world.gd",
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
                "res://tests/unit/test_a1_arcas.gd",
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
