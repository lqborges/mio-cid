#!/usr/bin/env python3
"""Structural tests for PR-10a a1_navapalos Gabriel dream.

Run: python3 tests/unit/test_a1_navapalos.py
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

CHAPTER = "content/chapters/a1_navapalos"


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


class TestA1NavapalosGabriel(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/navapalos.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/sleep_bed.gd",
            f"{CHAPTER}/gabriel.gd",
            "data/characters/gabriel.json",
            "content/art/characters/cid/cid.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertFalse((ROOT / "content/chapters/a1_castejon/world.tscn").is_file())

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
        self.assertIn("TentA", scene)
        self.assertIn("CloakBed", scene)
        self.assertIn("SleepZone", scene)
        self.assertIn("Gabriel", scene)
        self.assertIn("FigTree", scene)
        self.assertIn("DreamCamera", scene)
        self.assertIn("SleepCinematic", scene)
        self.assertIn('type="AnimationPlayer"', scene)
        self.assertIn("HallWhisper", scene)
        self.assertIn('character_id = &"gabriel"', scene)
        self.assertNotIn("HurtBox", scene)
        self.assertNotIn("hurt_box", scene)
        self.assertNotIn("cid_combat", scene)
        self.assertNotIn("HitBox", scene)

    def test_sleep_zone_does_not_overlap_spawn(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        cid = _origin(scene, "Cid")
        zone = _origin(scene, "SleepZone")
        size = _subresource_size(scene, "Box_sleep")
        half = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
        zone_min = (zone[0] - half[0], zone[1] - half[1], zone[2] - half[2])
        zone_max = (zone[0] + half[0], zone[1] + half[1], zone[2] + half[2])
        cid_radius = 0.4
        cid_height = 1.8
        cid_min = (cid[0] - cid_radius, cid[1], cid[2] - cid_radius)
        cid_max = (cid[0] + cid_radius, cid[1] + cid_height, cid[2] + cid_radius)
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, zone_min, zone_max),
            f"SleepZone {zone} size {size} overlaps Cid spawn {cid}",
        )
        self.assertGreater(abs(cid[2] - zone[2]), half[2] + cid_radius)

    def test_gabriel_json_unkillable_not_combatant(self) -> None:
        person = json.loads(_read("data/characters/gabriel.json"))
        self.assertEqual(person["id"], "gabriel")
        self.assertEqual(person["display_name_key"], "char.gabriel")
        self.assertEqual(person["combat"], 0)
        self.assertFalse(person["essential"])
        self.assertFalse(person["desertion_capable"])
        self.assertTrue(person["unkillable"])
        self.assertFalse(person["list_eligible"])
        source = _read(f"{CHAPTER}/gabriel.gd")
        self.assertNotIn("HurtBox", source)
        self.assertNotIn("cid_combat", source)
        self.assertNotIn("hit_box", source.lower())

    def test_world_script_sleep_plazo_travel(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func start_sleep", source)
        self.assertIn("func run_sleep", source)
        self.assertIn("func complete_dream", source)
        self.assertIn("hub_lock_cardena", source)
        self.assertIn("a1_castejon", source)
        self.assertIn("advance_plazo", source)
        self.assertIn("can_travel", source)
        self.assertIn("ChapterRunner.travel", source)
        self.assertIn("autosave", source)
        self.assertIn("current_scene != self", source)
        self.assertIn("func _ready", source)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn("camp_night(", source)
        self.assertNotIn("rest_camp(", source)
        self.assertNotRegex(source, re.compile(r"advance_plazo\s*\(\s*\d+\s*\)"))
        self.assertNotRegex(source, re.compile(r"plazo_days_left\s*=\s*\d+"))
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a1_navapalos/world.tscn", runner)
        self.assertIn('&"a1_navapalos"', runner)

    def test_strings_csv_spanish_dream(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a1_navapalos.gabriel_dream",
            "a1_navapalos.sleep",
            "char.gabriel",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        dream_es = rows["a1_navapalos.gabriel_dream"]["es"]
        dream_en = rows["a1_navapalos.gabriel_dream"]["en"]
        self.assertIn("viv", dream_es.lower())
        self.assertIn("while you live", dream_en.lower())
        self.assertIn("Gabriel", rows["char.gabriel"]["es"])

    def test_poem_formula_gabriel(self) -> None:
        with (ROOT / "content/locales/poem_formulas.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        self.assertIn("poem.v406", rows)
        self.assertIn("visquiéredes", rows["poem.v406"]["es"])
        self.assertEqual(rows["poem.v406"]["montaner_verse"].strip(), "406")

    def test_dialogue_separate_speakers(self) -> None:
        text = _read(f"{CHAPTER}/navapalos.dialogue")
        self.assertIn("~ dream", text)
        self.assertIn("Gabriel:", text)
        self.assertIn("Cid:", text)
        self.assertIn("a1_navapalos.gabriel_dream", text)
        self.assertIn("a1_navapalos.sleep", text)
        gabriel_at = text.find("Gabriel:")
        cid_at = text.find("Cid:")
        self.assertGreaterEqual(gabriel_at, 0)
        self.assertGreater(cid_at, gabriel_at)
        self.assertNotIn("Gabriel y Cid:", text)
        self.assertNotIn("{{", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)

    def test_beats_travel_to_castejon(self) -> None:
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a1_navapalos")
        nexts = [step.get("next") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("a1_castejon", nexts)
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("cinematic", types)
        self.assertIn("dialogue", types)

    def test_destierro_spine_and_hub_lock(self) -> None:
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a1_vivar", "a1_burgos"), pairs)
        self.assertIn(("a1_burgos", "a1_arcas"), pairs)
        self.assertIn(("a1_arcas", "a1_cardena"), pairs)
        self.assertIn(("a1_cardena", "a1_navapalos"), pairs)
        self.assertIn(("a1_navapalos", "a1_castejon"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertTrue(can_travel(graph, "a1_cardena", "a1_navapalos", []))
        self.assertTrue(can_travel(graph, "a1_navapalos", "a1_castejon", locked))
        self.assertFalse(can_travel(graph, "a1_navapalos", "a1_cardena", locked))
        self.assertFalse(can_travel(graph, "a1_navapalos", "a1_vivar", locked))
        self.assertFalse(can_travel(graph, "a1_castejon", "a1_navapalos", locked))

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/navapalos.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/sleep_bed.gd",
            f"{CHAPTER}/gabriel.gd",
            "data/characters/gabriel.json",
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
                "res://tests/unit/test_a1_navapalos.gd",
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
