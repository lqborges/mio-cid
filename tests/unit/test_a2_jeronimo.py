#!/usr/bin/env python3
"""Structural tests for PR-25 Valencia hub / Jerónimo appointment.

Run: python3 tests/unit/test_a2_jeronimo.py
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

CHAPTER = "content/chapters/a2_jeronimo"
ROOMS = ("Hall", "Forge", "LionCage", "Bishopric", "WallWalk", "Solar", "Treasury")


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


class TestA2JeronimoValenciaHub(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/jeronimo.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/bishop.gd",
            "data/honor_events/jeronimo.json",
            "data/characters/jeronimo.json",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertTrue((ROOT / "content/chapters/a2_embassy2/world.tscn").is_file())
        self.assertFalse((ROOT / "content/chapters/a2_yusuf/world.tscn").is_file())
        self.assertFalse((ROOT / "content/chapters/a3_leon/world.tscn").is_file())
        self.assertFalse((ROOT / "content/chapters/a2_valencia_hub/world.tscn").is_file())

    def test_hub_rooms_and_greybox(self) -> None:
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
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 12)
        self.assertIn("CSGCombiner3D", scene)
        for room in ROOMS:
            self.assertIn(f'[node name="{room}"', scene, room)
        self.assertIn("CageGate", scene)
        self.assertIn("LionProp", scene)
        self.assertIn("Jeronimo", scene)
        self.assertIn("AppointZone", scene)
        self.assertIn("CageZone", scene)
        self.assertIn("EmbassyExit", scene)
        self.assertIn("ToEmbassy", scene)
        self.assertIn("Altar", scene)
        self.assertIn("Anvil", scene)
        self.assertIn("SolarBed", scene)
        self.assertIn("ChestA", scene)
        self.assertNotIn('[node name="Jimena"', scene)
        self.assertNotIn("GPUParticles3D", scene)
        appoint_at = scene.find('[node name="AppointZone"')
        cage_at = scene.find('[node name="CageZone"')
        exit_at = scene.find('[node name="EmbassyExit"')
        self.assertGreaterEqual(appoint_at, 0)
        self.assertGreaterEqual(cage_at, 0)
        self.assertGreaterEqual(exit_at, 0)
        self.assertIn("collision_mask = 130", scene[appoint_at : appoint_at + 280])
        self.assertIn("collision_mask = 130", scene[cage_at : cage_at + 280])
        self.assertIn("collision_mask = 130", scene[exit_at : exit_at + 280])

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
            ("AppointZone", "Box_appoint"),
            ("CageZone", "Box_cage"),
            ("EmbassyExit", "Box_embassy"),
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
        cage_min, cage_max = _zone_aabb(scene, "CageZone", "Box_cage")
        exit_min, exit_max = _zone_aabb(scene, "EmbassyExit", "Box_embassy")
        self.assertFalse(
            _aabb_overlap(cage_min, cage_max, exit_min, exit_max),
            "EmbassyExit must sit on a plaza edge, not the lion cage",
        )
        cage = _origin(scene, "CageZone")
        exit_pos = _origin(scene, "EmbassyExit")
        self.assertGreater(
            abs(exit_pos[0] - cage[0]) + abs(exit_pos[2] - cage[2]),
            12.0,
            f"EmbassyExit {exit_pos} too close to CageZone {cage}",
        )

    def test_honor_and_character_json(self) -> None:
        payload = json.loads(_read("data/honor_events/jeronimo.json"))
        self.assertEqual(payload["gift_marks"], 40)
        events = {row["id"]: row for row in payload["events"]}
        row = events["jeronimo_appointed"]
        self.assertEqual(row["beat"], "a2_jeronimo")
        self.assertIn("honor", row["deltas"])
        self.assertIn("honra", row["deltas"])
        self.assertIn("gift_down", row["tags"])
        self.assertIn("city", row["tags"])
        self.assertIn("jeronimo_appointed", row["flags_set"])
        self.assertFalse(row.get("hard_fail", False))
        person = json.loads(_read("data/characters/jeronimo.json"))
        self.assertEqual(person["id"], "jeronimo")
        self.assertEqual(person["role"], "bishop")
        self.assertEqual(person["recruitable_beat"], "a2_jeronimo")
        self.assertTrue(person["list_eligible"])
        self.assertEqual(person["gift_bias"], "chapel")

    def test_world_script_appointment_and_name(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        self.assertIn("func appoint_jeronimo", source)
        self.assertIn("func run_appoint", source)
        self.assertIn("func try_open_cage", source)
        self.assertIn("func is_cage_closed", source)
        self.assertIn("func travel_to_embassy2", source)
        self.assertIn("_restore_avengalvon_if_ready", source)
        self.assertIn("avengalvon_recruited", source)
        self.assertIn("apply_name", source)
        self.assertIn("babieca", source)
        self.assertIn("jeronimo_appointed", source)
        self.assertIn("gift_marks", source)
        self.assertIn("_tunable_int", source)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn("a3_leon", source)
        self.assertNotIn("flute", source.lower())
        horse = _read("game/actors/player/horse_companion.gd")
        self.assertIn("func apply_name(", horse)
        self.assertNotIn("babieca", horse.lower())
        tevar = _read("content/chapters/a1_tevar/world.gd").lower()
        self.assertNotIn("babieca", tevar)
        siege = _read("content/chapters/a2_siege/world.gd").lower()
        self.assertNotIn("babieca", siege)

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "char.jeronimo",
            "a2_jeronimo.appoint",
            "a2_jeronimo.wants_lance",
            "a2_jeronimo.give_lance",
            "a2_jeronimo.bishop_admin",
            "a2_jeronimo.appointed",
            "a2_jeronimo.gift",
            "a2_jeronimo.cage_locked",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("Jerónimo", rows["a2_jeronimo.appoint"]["es"])
        self.assertIn("obispado", rows["a2_jeronimo.appoint"]["es"].lower())
        self.assertIn("administra", rows["a2_jeronimo.bishop_admin"]["es"].lower())
        self.assertNotIn("cruzada", rows["a2_jeronimo.appoint"]["es"].lower())
        self.assertNotIn("reconquista", rows["a2_jeronimo.appoint"]["es"].lower())
        self.assertIn("jaula", rows["a2_jeronimo.cage_locked"]["es"].lower())
        loc_blob = _read("content/locales/strings.csv").lower()
        self.assertNotIn("babieca", loc_blob)
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a2_jeronimo.place_name,Valencia,", poem)
        self.assertIn("a2_jeronimo.horse_name,Babieca,", poem)
        self.assertIn("a2_jeronimo.arrive,", poem)
        self.assertIn("Babieca", poem)

    def test_beats_graph_and_validate(self) -> None:
        self.assertEqual(validate_main([]), 0)
        beats = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(beats["id"], "a2_jeronimo")
        types = [step.get("type") for step in beats["steps"] if isinstance(step, dict)]
        self.assertIn("dialogue", types)
        self.assertIn("honor_event", types)
        self.assertIn("blocking", types)
        flags = []
        for step in beats["steps"]:
            if isinstance(step, dict):
                flags.extend(step.get("set_flags", []))
        self.assertIn("babieca_named", flags)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a2_siege", "a2_jeronimo"), pairs)
        self.assertIn(("a2_jeronimo", "a2_embassy2"), pairs)
        self.assertNotIn(("a2_siege", "a2_embassy2"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertTrue(can_travel(graph, "a2_siege", "a2_jeronimo", locked))
        self.assertTrue(can_travel(graph, "a2_jeronimo", "a2_embassy2", locked))
        self.assertFalse(can_travel(graph, "a2_siege", "a2_embassy2", locked))
        node = next(n for n in graph["nodes"] if n["id"] == "a2_jeronimo")
        self.assertEqual(node["scene"], "res://content/chapters/a2_jeronimo/world.tscn")
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a2_jeronimo/world.tscn", runner)
        self.assertIn('&"a2_jeronimo"', runner)

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/jeronimo.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/bishop.gd",
            "data/honor_events/jeronimo.json",
            "game/autoload/chapter_runner.gd",
        ):
            lowered = _read(rel).lower()
            for token in DENY:
                self.assertNotIn(token, lowered, f"{rel} has {token}")
        world = _read(f"{CHAPTER}/world.gd").lower()
        self.assertIn("babieca", world)
        self.assertNotIn("flute", world)
        self.assertNotIn("corpse", world)

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
                "res://tests/unit/test_a2_jeronimo.gd",
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
