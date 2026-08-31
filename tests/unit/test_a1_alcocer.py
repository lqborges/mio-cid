#!/usr/bin/env python3
"""Structural tests for PR-16 a1_alcocer occupy / wait / dawn sortie.

Run: python3 tests/unit/test_a1_alcocer.py
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
    "reconquista",
    "holy-war",
    "holy_war",
)

CHAPTER = "content/chapters/a1_alcocer"


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _origin(scene: str, node_name: str) -> tuple[float, float, float]:
    marker = f'[node name="{node_name}"'
    start = scene.find(marker)
    if start < 0:
        raise AssertionError(f"missing node {node_name}")
    block = scene[start : start + 500]
    match = re.search(
        r"transform = Transform3D\(([^)]+)\)",
        block,
    )
    if match is None:
        raise AssertionError(f"{node_name} missing transform")
    nums = [float(part.strip()) for part in match.group(1).split(",")]
    if len(nums) != 12:
        raise AssertionError(f"{node_name} transform want 12 floats, got {len(nums)}")
    return nums[9], nums[10], nums[11]


def _subresource_size(scene: str, resource_id: str) -> tuple[float, float, float]:
    marker = f'id="{resource_id}"'
    start = scene.find(marker)
    if start < 0:
        raise AssertionError(f"missing subresource {resource_id}")
    block = scene[start : start + 240]
    match = re.search(r"size = Vector3\(([^)]+)\)", block)
    if match is None:
        raise AssertionError(f"{resource_id} missing Vector3 size")
    nums = [float(part.strip()) for part in match.group(1).split(",")]
    if len(nums) != 3:
        raise AssertionError(f"{resource_id} size want 3 floats")
    return nums[0], nums[1], nums[2]


def _aabb_overlap(
    a_min: tuple[float, float, float],
    a_max: tuple[float, float, float],
    b_min: tuple[float, float, float],
    b_max: tuple[float, float, float],
) -> bool:
    return (
        a_min[0] <= b_max[0]
        and a_max[0] >= b_min[0]
        and a_min[1] <= b_max[1]
        and a_max[1] >= b_min[1]
        and a_min[2] <= b_max[2]
        and a_max[2] >= b_min[2]
    )


def _zone_aabb(
    scene: str, node_name: str, shape_id: str
) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    origin = _origin(scene, node_name)
    size = _subresource_size(scene, shape_id)
    half = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
    return (
        (origin[0] - half[0], origin[1] - half[1], origin[2] - half[2]),
        (origin[0] + half[0], origin[1] + half[1], origin[2] + half[2]),
    )


class TestA1AlcocerDawnSortie(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/alcocer.dialogue",
            f"{CHAPTER}/beats.json",
            "data/towns/alcocer.json",
            "data/honor_events/towns.json",
            "data/characters/fariz.json",
            "data/characters/galve.json",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
            "content/art/characters/dummy/dummy.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertFalse((ROOT / "content/chapters/a1_embassy1/world.tscn").is_file())
        self.assertFalse((ROOT / "game/ui/booty_divide.tscn").is_file())

    def test_scene_is_cheap_greybox_dawn(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("dummy.tscn", scene)
        self.assertIn("captain.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn("mesura_hud.tscn", scene)
        self.assertNotIn("keep_or_sell.tscn", scene)
        self.assertNotIn("booty_divide", scene)
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
        self.assertIn("OccupyZone", scene)
        self.assertIn("WaitZone", scene)
        occupy_at = scene.find('[node name="OccupyZone"')
        wait_at = scene.find('[node name="WaitZone"')
        self.assertGreaterEqual(occupy_at, 0)
        self.assertGreaterEqual(wait_at, 0)
        self.assertIn("collision_mask = 130", scene[occupy_at : occupy_at + 280])
        self.assertIn("collision_mask = 130", scene[wait_at : wait_at + 280])
        self.assertIn("WaitCamp", scene)
        self.assertIn("TentA", scene)
        self.assertIn("Garrison", scene)
        self.assertIn("Host", scene)
        self.assertIn("Fariz", scene)
        self.assertIn("Galve", scene)
        self.assertIn("Mesnada", scene)
        self.assertIn("Horse", scene)
        self.assertIn("Keep", scene)
        self.assertIn('character_id = &"fariz"', scene)
        self.assertIn('character_id = &"galve"', scene)
        self.assertIn("CavalryCharge", _read("content/art/characters/horse/horse.tscn"))
        self.assertNotIn("AlvarFanez", scene)
        self.assertNotIn("KeepOrSell", scene)

    def test_zones_do_not_overlap_spawn(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        cid = _origin(scene, "Cid")
        horse = _origin(scene, "Horse")
        cid_radius = 0.4
        cid_height = 1.8
        cid_min = (cid[0] - cid_radius, cid[1], cid[2] - cid_radius)
        cid_max = (cid[0] + cid_radius, cid[1] + cid_height, cid[2] + cid_radius)
        horse_min = (horse[0] - 0.5, horse[1], horse[2] - 0.8)
        horse_max = (horse[0] + 0.5, horse[1] + 1.4, horse[2] + 0.8)
        occupy_min, occupy_max = _zone_aabb(scene, "OccupyZone", "Box_occupy")
        wait_min, wait_max = _zone_aabb(scene, "WaitZone", "Box_wait")
        occupy_size = _subresource_size(scene, "Box_occupy")
        wait_size = _subresource_size(scene, "Box_wait")
        occupy = _origin(scene, "OccupyZone")
        wait = _origin(scene, "WaitZone")
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, occupy_min, occupy_max),
            f"OccupyZone {occupy} size {occupy_size} overlaps Cid spawn {cid}",
        )
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, occupy_min, occupy_max),
            f"OccupyZone overlaps Horse spawn {horse}",
        )
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, wait_min, wait_max),
            f"WaitZone {wait} size {wait_size} overlaps Cid spawn {cid}",
        )
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, wait_min, wait_max),
            f"WaitZone overlaps Horse spawn {horse}",
        )
        self.assertGreater(abs(cid[2] - occupy[2]), occupy_size[2] / 2.0 + cid_radius)
        self.assertGreater(abs(cid[2] - wait[2]), wait_size[2] / 2.0 + cid_radius)

    def test_world_script_occupy_wait_sortie(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func start_occupy", source)
        self.assertIn("func run_occupy", source)
        self.assertIn("func complete_occupy", source)
        self.assertIn("func start_wait", source)
        self.assertIn("func run_wait", source)
        self.assertIn("func complete_wait", source)
        self.assertIn("func start_sortie", source)
        self.assertIn("func run_sortie", source)
        self.assertIn("func complete_sortie", source)
        self.assertIn("alcocer_sortie_win", source)
        self.assertIn("a1_embassy1", source)
        self.assertIn("hub_lock_cardena", source)
        self.assertIn("horse_companion", source)
        self.assertIn("rest_camp", source)
        self.assertIn("can_travel", source)
        self.assertIn("ChapterRunner.travel", source)
        self.assertIn("autosave", source)
        self.assertIn("current_scene != self", source)
        self.assertIn("func _ready", source)
        self.assertIn("lanza_body_limit", source)
        self.assertIn("fariz", source)
        self.assertIn("galve", source)
        self.assertIn("MesnadaMember.from_id", source)
        self.assertIn("collision_layer", source)
        self.assertIn("monitorable", source)
        self.assertIn("_captains_left <= 0", source)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn("advance_plazo", source)
        self.assertNotIn("camp_night(", source)
        self.assertNotIn("keep_or_sell", source)
        self.assertNotIn("booty_divide", source)
        self.assertNotIn("alcocer_sell", source)
        self.assertNotIn("alcocer_keep", source)
        self.assertNotIn("12", source)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a1_alcocer/world.tscn", runner)
        self.assertIn('&"a1_alcocer"', runner)
        dummy = _read("game/combat/dummy_enemy.gd")
        self.assertIn("character_id", dummy)
        self.assertIn("MesnadaMember.from_id", dummy)

    def test_fariz_galve_json_killable_captains(self) -> None:
        fariz = json.loads(_read("data/characters/fariz.json"))
        galve = json.loads(_read("data/characters/galve.json"))
        self.assertEqual(fariz["id"], "fariz")
        self.assertEqual(galve["id"], "galve")
        self.assertEqual(fariz["display_name_key"], "char.fariz")
        self.assertEqual(galve["display_name_key"], "char.galve")
        self.assertEqual(fariz["role"], "taifa_captain")
        self.assertEqual(galve["role"], "taifa_captain")
        self.assertFalse(fariz["unkillable"])
        self.assertFalse(galve["unkillable"])
        self.assertGreater(fariz["combat"], 0)
        self.assertGreater(galve["combat"], 0)
        alfonso = json.loads(_read("data/characters/alfonso.json"))
        self.assertTrue(alfonso["unkillable"])
        self.assertNotEqual(fariz["unkillable"], alfonso["unkillable"])
        towns = json.loads(_read("data/honor_events/towns.json"))
        events = {row["id"]: row for row in towns["events"]}
        win = events["alcocer_sortie_win"]
        self.assertEqual(win["deltas"]["onores"], 18)
        self.assertIn("battle", win["tags"])
        self.assertEqual(win["beat"], "a1_alcocer")
        self.assertNotIn("alcocer_sell", _read(f"{CHAPTER}/world.gd"))

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a1_alcocer.occupy",
            "a1_alcocer.wait",
            "a1_alcocer.dawn",
            "a1_alcocer.sortie_win",
            "location.alcocer",
            "char.fariz",
            "char.galve",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("Alcocer", rows["a1_alcocer.occupy"]["es"])
        self.assertIn("alba", rows["a1_alcocer.dawn"]["es"].lower())
        self.assertIn("Fáriz", rows["a1_alcocer.dawn"]["es"])
        self.assertIn("Galve", rows["a1_alcocer.dawn"]["es"])
        self.assertIn("Fáriz", rows["char.fariz"]["es"])
        wait_es = rows["a1_alcocer.wait"]["es"].lower()
        self.assertTrue("reloj" in wait_es or "velamos" in wait_es or "real" in wait_es)

    def test_dialogue_occupy_wait_sortie(self) -> None:
        text = _read(f"{CHAPTER}/alcocer.dialogue")
        self.assertIn("~ occupy", text)
        self.assertIn("~ wait", text)
        self.assertIn("~ dawn", text)
        self.assertIn("~ win", text)
        self.assertIn("a1_alcocer.occupy", text)
        self.assertIn("a1_alcocer.wait", text)
        self.assertIn("a1_alcocer.dawn", text)
        self.assertIn("a1_alcocer.sortie_win", text)
        self.assertNotIn("{{", text)
        self.assertNotIn("booty", text.lower())
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)

    def test_beats_wait_clock_then_embassy(self) -> None:
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a1_alcocer")
        nexts = [step.get("next") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("a1_embassy1", nexts)
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("clock_segment", types)
        self.assertIn("honor_event", types)
        self.assertIn("travel_spawn", types)
        self.assertNotIn("keep_or_sell", types)
        segments = [
            step.get("segment") for step in payload["steps"] if isinstance(step, dict)
        ]
        self.assertIn("camp_night", segments)
        ids = [step.get("id") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("alcocer_sortie_win", ids)

    def test_destierro_spine_and_hub_lock(self) -> None:
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a1_castejon", "a1_alcocer"), pairs)
        self.assertIn(("a1_alcocer", "a1_embassy1"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertTrue(can_travel(graph, "a1_castejon", "a1_alcocer", locked))
        self.assertTrue(can_travel(graph, "a1_alcocer", "a1_embassy1", locked))
        self.assertFalse(can_travel(graph, "a1_alcocer", "a1_cardena", locked))
        self.assertFalse(can_travel(graph, "a1_alcocer", "a1_castejon", locked))
        self.assertFalse(can_travel(graph, "a1_alcocer", "a1_navapalos", locked))

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/alcocer.dialogue",
            f"{CHAPTER}/beats.json",
            "data/characters/fariz.json",
            "data/characters/galve.json",
            "game/autoload/chapter_runner.gd",
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
            for local in (
                Path("/home/lqborges/.local/bin/godot"),
                Path.home() / ".local/bin/godot",
            ):
                if local.is_file():
                    godot = str(local)
                    break
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
                "res://tests/unit/test_a1_alcocer.gd",
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
