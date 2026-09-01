#!/usr/bin/env python3
"""Structural tests for Tagus pardon and forced-yes marriages.

Run: python3 tests/unit/test_a2_tagus.py
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

from validate_graph import can_travel, load_graph, main as validate_main  # noqa: E402

DENY = (
    "puy",
    "stornetta",
    "santa gadea",
    "santa_gadea",
    "espadero",
    "flute",
    "jura",
    "heston",
    "corpse",
    "reconquista",
    "holy-war",
    "holy_war",
)

CHAPTER = "content/chapters/a2_tagus"


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


class TestA2TagusPardon(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/tagus.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/courtier.gd",
            "data/honor_events/tagus.json",
            "data/characters/alfonso.json",
            "data/characters/ferran_gonzalez.json",
            "data/characters/diego_gonzalez.json",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
            "content/chapters/a2_embassy3/world.tscn",
            "content/chapters/a2_repay_raquel/world.tscn",
            "content/chapters/a2_bodas/world.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertFalse((ROOT / "content/chapters/a3_leon/world.tscn").is_file())

    def test_greybox_three_day_court(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("captain.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn("mesura_hud.tscn", scene)
        self.assertEqual(scene.count('type="DirectionalLight3D"'), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 8)
        self.assertIn("CSGCombiner3D", scene)
        self.assertIn("CSGCylinder3D", scene)
        self.assertIn('[node name="Alfonso"', scene)
        self.assertIn('[node name="FerranGonzalez"', scene)
        self.assertIn('[node name="DiegoGonzalez"', scene)
        self.assertIn('[node name="CourtZone"', scene)
        self.assertIn('[node name="RestZone"', scene)
        self.assertIn('[node name="BodasExit"', scene)
        self.assertIn('[node name="Pavilion"', scene)
        self.assertIn('[node name="River"', scene)
        self.assertIn('[node name="TentA"', scene)
        self.assertIn('character_id = &"alfonso"', scene)
        self.assertNotIn("ChoiceUI", scene)
        self.assertNotIn("GPUParticles3D", scene)
        for node_name in ("CourtZone", "RestZone", "BodasExit"):
            at = scene.find(f'[node name="{node_name}"')
            self.assertGreaterEqual(at, 0, node_name)
            self.assertIn("collision_mask = 130", scene[at : at + 280], node_name)

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
        for node_name, shape_id in (
            ("CourtZone", "Box_court"),
            ("RestZone", "Box_rest"),
            ("BodasExit", "Box_bodas"),
        ):
            zmin, zmax = _zone_aabb(scene, node_name, shape_id)
            size = _subresource_size(scene, shape_id)
            origin = _origin(scene, node_name)
            self.assertFalse(
                _aabb_overlap(cid_min, cid_max, zmin, zmax),
                f"{node_name} {origin} size {size} overlaps Cid spawn {cid}",
            )
            self.assertFalse(
                _aabb_overlap(horse_min, horse_max, zmin, zmax),
                f"{node_name} overlaps Horse spawn {horse}",
            )

    def test_honor_events_pardon_then_yes(self) -> None:
        payload = json.loads(_read("data/honor_events/tagus.json"))
        self.assertEqual(payload["court_days"], 3)
        events = {row["id"]: row for row in payload["events"]}
        pardon = events["pardon"]
        self.assertEqual(pardon["beat"], "a2_tagus")
        self.assertEqual(pardon["deltas"]["honor"], 30)
        self.assertNotIn("honra", pardon["deltas"])
        self.assertNotIn("onores", pardon["deltas"])
        self.assertIn("pardon", pardon["flags_set"])
        self.assertIn("king", pardon["tags"])
        self.assertFalse(pardon.get("hard_fail", False))
        marry = events["accept_marriages"]
        self.assertEqual(marry["beat"], "a2_tagus")
        self.assertEqual(marry["deltas"]["honor"], 5)
        self.assertEqual(marry["deltas"]["honra"], -4)
        self.assertIn("marriages_accepted", marry["flags_set"])
        self.assertIn("bitter", marry["tags"])
        core = json.loads(_read("data/honor_events/core.json"))
        core_events = {item["id"]: item for item in core["events"]}
        self.assertEqual(core_events["pardon"]["deltas"]["honor"], 30)
        self.assertEqual(core_events["accept_marriages"]["deltas"]["honor"], 5)
        self.assertEqual(core_events["accept_marriages"]["deltas"]["honra"], -4)

    def test_world_script_forced_yes(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        self.assertIn("func grant_pardon", source)
        self.assertIn("func run_pardon", source)
        self.assertIn("func run_ask", source)
        self.assertIn("func accept_marriages", source)
        self.assertIn("func refuse_marriages", source)
        self.assertIn("func travel_to_bodas", source)
        self.assertIn("court_day", source)
        self.assertIn("court_days", source)
        self.assertIn("_tunable_int", source)
        self.assertIn("advance_calendar", source)
        self.assertIn("ResourceLoader.exists", source)
        self.assertIn("goto", source)
        self.assertNotIn("func choose_refuse", source)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn("ChoiceUI", source)
        dialogue = _read(f"{CHAPTER}/tagus.dialogue")
        self.assertIn("~ pardon", dialogue)
        self.assertIn("~ ask", dialogue)
        self.assertIn("Alfonso:", dialogue)
        self.assertIn("Cid:", dialogue)
        self.assertNotIn("~ refuse", dialogue)
        beats = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(beats["id"], "a2_tagus")
        self.assertEqual(beats["court_days"], 3)
        types = [step.get("type") for step in beats["steps"] if isinstance(step, dict)]
        self.assertIn("honor_event", types)
        self.assertIn("dialogue", types)
        nexts = [step.get("next") for step in beats["steps"] if isinstance(step, dict)]
        self.assertNotIn("a2_bodas", nexts)

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "char.alfonso",
            "char.ferran_gonzalez",
            "char.diego_gonzalez",
            "a2_tagus.arrive",
            "a2_tagus.pardon",
            "a2_tagus.ask",
            "a2_tagus.yes",
            "a2_tagus.cannot_refuse",
            "a2_tagus.day2",
            "a2_tagus.day3",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("perdono", rows["a2_tagus.pardon"]["es"].lower())
        yes = rows["a2_tagus.yes"]["es"].lower()
        self.assertIn("rey", yes)
        self.assertTrue("sí" in yes or "si" in yes)
        self.assertIn("perdón", rows["a2_tagus.cannot_refuse"]["es"].lower())
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a2_tagus.place_name,Tajo,", poem)
        self.assertIn("a2_tagus.horse_name,Babieca,", poem)

    def test_graph_and_join_and_validate(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a2_embassy3", "a2_tagus"), pairs)
        self.assertIn(("a2_repay_raquel", "a2_tagus"), pairs)
        self.assertIn(("a2_tagus", "a2_bodas"), pairs)
        honest = ["embassy3_done"]
        self.assertTrue(can_travel(graph, "a2_embassy3", "a2_tagus", honest))
        cheated = ["arcas_cheated", "embassy3_done"]
        self.assertFalse(can_travel(graph, "a2_embassy3", "a2_tagus", cheated))
        self.assertFalse(can_travel(graph, "a2_repay_raquel", "a2_tagus", cheated))
        repaid = cheated + ["repay_done"]
        self.assertTrue(can_travel(graph, "a2_repay_raquel", "a2_tagus", repaid))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a2_tagus/world.tscn", runner)
        self.assertIn('&"a2_tagus"', runner)
        director = _read("game/chapters/beat_director.gd")
        self.assertIn('"honor_event"', director)
        self.assertIn('"whisper"', director)

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/tagus.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/courtier.gd",
            "data/honor_events/tagus.json",
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
                Path("/tmp/grok-lqborges/deps/godot-unz/Godot_v4.7.2-stable_linux.x86_64"),
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
                "res://tests/unit/test_a2_tagus.gd",
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
