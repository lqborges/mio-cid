#!/usr/bin/env python3
"""Structural tests for PR-10 a1_cardena farewell and hub-lock.

Run: python3 tests/unit/test_a1_cardena.py
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

from validate_graph import can_travel, load_graph  # noqa: E402

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

CHAPTER = "content/chapters/a1_cardena"


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestA1CardenaFarewell(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/cardena.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/family.gd",
            "data/honor_events/cardena.json",
            "data/characters/jimena.json",
            "data/characters/elvira.json",
            "data/characters/sol.json",
            "data/characters/sisebuto.json",
            "content/art/characters/cid/cid.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_scene_is_cheap_greybox(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("plazo_bar.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn('type="DirectionalLight3D"', scene)
        self.assertEqual(scene.count('type="DirectionalLight3D"'), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertIn('type="CSGBox3D"', scene)
        self.assertIn('type="CSGCombiner3D"', scene)
        self.assertIn('type="CSGCylinder3D"', scene)
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 8)
        self.assertIn("Chapel", scene)
        self.assertIn("CloisterNorthWest", scene)
        self.assertIn("CypressA", scene)
        self.assertIn("Candle", scene)
        self.assertIn("Jimena", scene)
        self.assertIn("Elvira", scene)
        self.assertIn("Sol", scene)
        self.assertIn("Sisebuto", scene)
        self.assertIn("FarewellZone", scene)
        self.assertIn("HallWhisper", scene)
        self.assertIn('character_id = &"jimena"', scene)
        self.assertIn('character_id = &"elvira"', scene)
        self.assertIn('character_id = &"sol"', scene)
        self.assertIn('character_id = &"sisebuto"', scene)
        self.assertNotEqual(
            scene.find('character_id = &"jimena"'),
            scene.find('character_id = &"elvira"'),
        )

    def test_cardena_json_gift_tunables(self) -> None:
        payload = json.loads(_read("data/honor_events/cardena.json"))
        self.assertEqual(payload["gift_marks"], 40)
        events = {row["id"]: row for row in payload["events"]}
        gift = events["cardena_gift_monastery"]
        self.assertEqual(gift["deltas"]["honra"], 4)
        self.assertNotIn("onores", gift["deltas"])
        self.assertNotIn("honor", gift["deltas"])
        self.assertIn("gift_down", gift["tags"])
        self.assertEqual(gift.get("beat"), "a1_cardena")
        self.assertNotIn("stain_id", gift)

    def test_family_are_separate_ids(self) -> None:
        jimena = json.loads(_read("data/characters/jimena.json"))
        elvira = json.loads(_read("data/characters/elvira.json"))
        sol = json.loads(_read("data/characters/sol.json"))
        sisebuto = json.loads(_read("data/characters/sisebuto.json"))
        self.assertEqual(jimena["id"], "jimena")
        self.assertEqual(elvira["id"], "elvira")
        self.assertEqual(sol["id"], "sol")
        self.assertEqual(sisebuto["id"], "sisebuto")
        self.assertTrue(sisebuto["unkillable"])
        self.assertFalse(sisebuto["desertion_capable"])
        self.assertFalse(sisebuto["list_eligible"])
        ids = {jimena["id"], elvira["id"], sol["id"], sisebuto["id"]}
        self.assertEqual(len(ids), 4)

    def test_world_script_gift_and_hub_lock(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func give_monastery_gift", source)
        self.assertIn("func complete_farewell", source)
        self.assertIn("cardena_gift_monastery", source)
        self.assertIn("gift_marks", source)
        self.assertIn("hub_lock_cardena", source)
        self.assertIn("a1_navapalos", source)
        self.assertIn("advance_plazo", source)
        self.assertIn("autosave", source)
        self.assertIn("current_scene != self", source)
        self.assertNotIn("camp_night(", source)
        self.assertNotIn("rest_camp(", source)
        self.assertNotRegex(source, re.compile(r"marks\s*[+\-]=?\s*40"))
        self.assertNotRegex(source, re.compile(r"honra\s*[+\-]=?\s*4"))
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        honor = _read("game/systems/honor/honor_service.gd")
        self.assertNotIn("CARDENA_PATH", honor)
        self.assertNotIn("honor_events/cardena.json", honor)
        self.assertIn("EVENTS_DIR", honor)

    def test_arcas_travels_to_cardena(self) -> None:
        arcas = _read("content/chapters/a1_arcas/world.gd")
        self.assertIn("_travel_to_cardena", arcas)
        self.assertIn("a1_cardena", arcas)
        travel = arcas.split("func _travel_to_cardena", 1)[1]
        self.assertIn("can_travel", travel)
        self.assertIn("ChapterRunner.travel", travel)
        self.assertIn("ChapterRunner.goto", travel)
        self.assertIn("current_scene != self", travel)
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a1_cardena/world.tscn", runner)
        self.assertIn('&"a1_cardena"', runner)

    def test_strings_csv_spanish_farewell(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a1_cardena.jimena_nail",
            "a1_cardena.elvira",
            "a1_cardena.sol",
            "a1_cardena.abbot",
            "a1_cardena.gift",
            "a1_cardena.leave",
            "char.jimena",
            "char.elvira",
            "char.sol",
            "char.sisebuto",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("uña", rows["a1_cardena.jimena_nail"]["es"])
        self.assertIn("Jimena", rows["char.jimena"]["es"])
        self.assertIn("Elvira", rows["char.elvira"]["es"])
        self.assertIn("Sol", rows["char.sol"]["es"])
        self.assertIn("Sisebuto", rows["char.sisebuto"]["es"])

    def test_poem_formula_nail(self) -> None:
        with (ROOT / "content/locales/poem_formulas.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        self.assertIn("poem.v264", rows)
        self.assertIn("uña", rows["poem.v264"]["es"])
        self.assertEqual(rows["poem.v264"]["montaner_verse"].strip(), "264")

    def test_dialogue_separate_speakers(self) -> None:
        text = _read(f"{CHAPTER}/cardena.dialogue")
        self.assertIn("~ farewell", text)
        self.assertIn("Jimena:", text)
        self.assertIn("Elvira:", text)
        self.assertIn("Sol:", text)
        self.assertIn("Sisebuto:", text)
        self.assertIn("Cid:", text)
        self.assertIn("a1_cardena.jimena_nail", text)
        self.assertIn("a1_cardena.elvira", text)
        self.assertIn("a1_cardena.sol", text)
        self.assertIn("a1_cardena.abbot", text)
        self.assertIn("a1_cardena.gift", text)
        self.assertIn("a1_cardena.leave", text)
        self.assertNotIn("Jimena y Elvira:", text)
        self.assertNotIn("{{", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)

    def test_hub_lock_cardena_edge_and_no_return(self) -> None:
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        cardena = next(
            edge
            for edge in graph["edges"]
            if edge["from"] == "a1_cardena" and edge["to"] == "a1_navapalos"
        )
        self.assertEqual(cardena.get("set_flags"), ["hub_lock_cardena"])
        self.assertTrue(can_travel(graph, "a1_arcas", "a1_cardena", []))
        self.assertTrue(can_travel(graph, "a1_cardena", "a1_navapalos", []))
        locked = ["hub_lock_cardena"]
        self.assertFalse(can_travel(graph, "a1_navapalos", "a1_cardena", locked))
        self.assertFalse(can_travel(graph, "a1_cardena", "a1_vivar", locked))
        self.assertFalse(can_travel(graph, "a1_cardena", "a1_burgos", locked))
        self.assertFalse(can_travel(graph, "a1_cardena", "a1_arcas", locked))
        self.assertFalse(can_travel(graph, "a1_vivar", "a1_navapalos", locked))
        self.assertFalse(
            (ROOT / "content/chapters/a1_navapalos/world.tscn").is_file()
        )

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/cardena.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/family.gd",
            "data/honor_events/cardena.json",
            "data/characters/sisebuto.json",
            "game/autoload/chapter_runner.gd",
            "content/chapters/a1_arcas/world.gd",
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
                "--audio-driver",
                "Dummy",
                "-s",
                "res://tests/unit/test_a1_cardena.gd",
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
