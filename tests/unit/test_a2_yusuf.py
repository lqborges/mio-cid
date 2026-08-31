#!/usr/bin/env python3
"""Structural tests for PR-27 Yusuf day 1 and PR-27b scripted day 2.

Run: python3 tests/unit/test_a2_yusuf.py
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

CHAPTER = "content/chapters/a2_yusuf"


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


class TestA2YusufDay1(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/day1.tscn",
            f"{CHAPTER}/day1.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/jimena_wall.gd",
            f"{CHAPTER}/yusuf.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/day2.tscn",
            f"{CHAPTER}/day2.gd",
            "data/honor_events/core.json",
            "data/characters/yusuf.json",
            "data/characters/jimena.json",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
            "content/art/characters/dummy/dummy.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertFalse((ROOT / "content/chapters/a2_embassy3/world.tscn").is_file())

    def test_scene_is_field_not_climb(self) -> None:
        scene = _read(f"{CHAPTER}/day1.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("dummy.tscn", scene)
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
        self.assertIn("CSGCylinder3D", scene)
        self.assertIn("FieldZone", scene)
        self.assertIn("ClimbZone", scene)
        self.assertIn("Host", scene)
        self.assertIn("Yusuf", scene)
        self.assertIn("Jimena", scene)
        self.assertIn("JimenaCamera", scene)
        self.assertIn("WallWalk", scene)
        self.assertIn("HuertaPatch", scene)
        self.assertIn("Mesnada", scene)
        self.assertIn("Horse", scene)
        self.assertIn('character_id = &"yusuf"', scene)
        self.assertIn('character_id = &"jimena"', scene)
        self.assertIn("collision_layer = 64", scene)
        self.assertIn("CavalryCharge", _read("content/art/characters/horse/horse.tscn"))
        self.assertNotIn("KeepOrSell", scene)
        self.assertNotIn("GPUParticles3D", scene)
        host_at = scene.find('[node name="Host"')
        self.assertGreaterEqual(host_at, 0)
        host_head = scene[host_at : host_at + 120]
        self.assertNotIn("visible = false", host_head)
        field_at = scene.find('[node name="FieldZone"')
        climb_at = scene.find('[node name="ClimbZone"')
        self.assertGreaterEqual(field_at, 0)
        self.assertGreaterEqual(climb_at, 0)
        self.assertIn("collision_mask = 130", scene[field_at : field_at + 280])
        self.assertIn("collision_mask = 130", scene[climb_at : climb_at + 280])
        source = _read(f"{CHAPTER}/day1.gd")
        self.assertIn("func run_field", source)
        self.assertIn("func complete_win", source)
        self.assertIn("func can_storm_wall", source)
        self.assertIn("return false", source)
        self.assertIn("yusuf_win", source)
        self.assertIn("yusuf_day1_done", source)
        self.assertIn("func jimena_on_wall", source)
        self.assertIn("func look_from_wall", source)
        self.assertIn("lanza_body_limit", source)
        self.assertNotIn("ChapterRunner.travel", source)
        self.assertNotIn("ChapterRunner.goto", source)
        self.assertNotIn("func _enter_tree", source)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        world_script = _read(f"{CHAPTER}/world.gd")
        self.assertIn("day1.gd", world_script)
        self.assertIn("day2.tscn", world_script)
        self.assertIn("create_timer", world_script)
        self.assertIn("DAY2_HOLD_SEC", world_script)
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a2_yusuf/world.tscn", runner)
        self.assertIn('&"a2_yusuf"', runner)

    def test_jimena_stands_on_wall(self) -> None:
        scene = _read(f"{CHAPTER}/day1.tscn")
        jimena = _origin(scene, "Jimena")
        walk = _origin(scene, "WallWalk")
        wall = _origin(scene, "Wall")
        cid = _origin(scene, "Cid")
        self.assertGreaterEqual(jimena[1], walk[1] - 0.2)
        self.assertGreater(jimena[1], 3.5)
        self.assertLess(abs(jimena[2] - walk[2]), 1.5)
        self.assertLess(abs(jimena[2] - wall[2]), 3.0)
        self.assertGreater(cid[1] + 1.8, 0.0)
        self.assertGreater(abs(cid[2] - jimena[2]), 8.0)
        cam_at = scene.find('[node name="JimenaCamera"')
        self.assertGreaterEqual(cam_at, 0)
        self.assertIn("parent=\"Jimena\"", scene[cam_at : cam_at + 80] + scene[max(0, cam_at - 40) : cam_at + 80])
        self.assertIn("current = false", scene[cam_at : cam_at + 280])
        spectator = _read(f"{CHAPTER}/jimena_wall.gd")
        self.assertIn("spectator", spectator)
        self.assertIn("LAYER_SPECTATOR", spectator)
        self.assertNotIn("func _physics_process", spectator)

    def test_zones_do_not_overlap_spawn(self) -> None:
        scene = _read(f"{CHAPTER}/day1.tscn")
        cid = _origin(scene, "Cid")
        horse = _origin(scene, "Horse")
        cid_radius = 0.4
        cid_height = 1.8
        cid_min = (cid[0] - cid_radius, cid[1], cid[2] - cid_radius)
        cid_max = (cid[0] + cid_radius, cid[1] + cid_height, cid[2] + cid_radius)
        horse_min = (horse[0] - 0.5, horse[1], horse[2] - 0.8)
        horse_max = (horse[0] + 0.5, horse[1] + 1.4, horse[2] + 0.8)
        for node_name, shape_id in (
            ("FieldZone", "Box_field"),
            ("ClimbZone", "Box_climb"),
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
        yusuf = _origin(scene, "Yusuf")
        self.assertGreater(abs(cid[2] - yusuf[2]), 4.0)
        self.assertGreater(abs(cid[0] - yusuf[0]) + abs(cid[2] - yusuf[2]), 4.0)

    def test_honor_event_from_json(self) -> None:
        payload = json.loads(_read("data/honor_events/core.json"))
        events = {row["id"]: row for row in payload["events"]}
        row = events["yusuf_win"]
        self.assertEqual(row["beat"], "a2_yusuf")
        self.assertEqual(row["deltas"]["honor"], 12)
        self.assertEqual(row["tags"], ["battle"])
        self.assertIn("yusuf_day1_done", row["flags_set"])
        self.assertTrue(row.get("once"))
        day2 = events["yusuf_day2"]
        self.assertEqual(day2["beat"], "a2_yusuf")
        self.assertEqual(day2["tags"], ["battle"])
        self.assertIn("yusuf_day2_done", day2["flags_set"])
        self.assertTrue(day2.get("once"))
        self.assertIn("honor", day2["deltas"])
        yusuf = json.loads(_read("data/characters/yusuf.json"))
        self.assertEqual(yusuf["id"], "yusuf")
        self.assertFalse(yusuf["unkillable"])
        jimena = json.loads(_read("data/characters/jimena.json"))
        self.assertTrue(jimena["unkillable"])
        self.assertTrue(jimena["essential"])

    def test_loc_keys_spanish_first(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(encoding="utf-8") as handle:
            strings = {row["key"]: row for row in csv.DictReader(handle)}
        with (ROOT / "content/locales/poem_formulas.csv").open(encoding="utf-8") as handle:
            formulas = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a2_yusuf.field",
            "a2_yusuf.win",
            "a2_yusuf.wall_refused",
            "a2_yusuf.jimena_watch",
            "a2_yusuf.day1_hold",
            "a2_yusuf.day2_watch",
            "a2_yusuf.day2_charge",
            "a2_yusuf.day2_win",
            "char.yusuf",
        ):
            self.assertIn(key, strings, key)
            self.assertTrue(strings[key]["es"].strip(), key)
            self.assertTrue(strings[key]["en"].strip(), key)
        self.assertIn("a2_yusuf.place_name", formulas)
        self.assertIn("Valencia", formulas["a2_yusuf.place_name"]["es"])
        self.assertIn("huerta", strings["a2_yusuf.field"]["es"].lower())
        self.assertIn("Jimena", strings["a2_yusuf.win"]["es"])
        self.assertIn("escala", strings["a2_yusuf.wall_refused"]["es"].lower())
        self.assertIn("Jimena", strings["a2_yusuf.day2_watch"]["es"])
        self.assertIn("carga", strings["a2_yusuf.day2_charge"]["es"].lower())
        self.assertIn("Jimena", strings["a2_yusuf.day2_win"]["es"])

    def test_beats_and_graph_spine(self) -> None:
        beats = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(beats["id"], "a2_yusuf")
        types = [step.get("type") for step in beats["steps"] if isinstance(step, dict)]
        self.assertIn("blocking", types)
        self.assertIn("honor_event", types)
        self.assertIn("cinematic", types)
        self.assertIn("travel_spawn", types)
        ids = [step.get("id") for step in beats["steps"] if isinstance(step, dict)]
        self.assertIn("field", ids)
        self.assertIn("yusuf_win", ids)
        self.assertIn("charge", ids)
        self.assertIn("yusuf_day2", ids)
        flags = []
        next_ids = []
        for step in beats["steps"]:
            if isinstance(step, dict):
                flags.extend(step.get("set_flags", []))
                if step.get("next"):
                    next_ids.append(step.get("next"))
        self.assertIn("yusuf_day1_done", flags)
        self.assertIn("yusuf_day2_done", flags)
        self.assertIn("a2_embassy3", next_ids)
        for step in beats["steps"]:
            if isinstance(step, dict) and step.get("id") in ("yusuf_day2", "leave"):
                self.assertIn(
                    "yusuf_day2_done",
                    step.get("skip_if", []),
                    step.get("id"),
                )
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a2_embassy2", "a2_yusuf"), pairs)
        self.assertIn(("a2_yusuf", "a2_embassy3"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertTrue(can_travel(graph, "a2_embassy2", "a2_yusuf", locked))
        self.assertTrue(can_travel(graph, "a2_yusuf", "a2_embassy3", locked))
        self.assertFalse(can_travel(graph, "a2_jeronimo", "a2_yusuf", locked))
        self.assertTrue(can_travel(graph, "a2_jeronimo", "a2_yusuf", locked + ["embassy2_done"]))
        node = next(n for n in graph["nodes"] if n["id"] == "a2_yusuf")
        self.assertEqual(node["scene"], "res://content/chapters/a2_yusuf/world.tscn")
        world_scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("day1.tscn", world_scene)
        self.assertIn("world.gd", world_scene)

    def test_graph_validator_ok(self) -> None:
        self.assertEqual(validate_main(["--graph", str(ROOT / "data/chapters/graph.json")]), 0)

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/day1.gd",
            f"{CHAPTER}/day1.tscn",
            f"{CHAPTER}/day2.gd",
            f"{CHAPTER}/day2.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/jimena_wall.gd",
            f"{CHAPTER}/yusuf.dialogue",
            f"{CHAPTER}/beats.json",
            "data/characters/yusuf.json",
            "game/autoload/chapter_runner.gd",
        ):
            lowered = _read(rel).lower()
            for token in DENY:
                self.assertNotIn(token, lowered, f"{rel} has {token}")
        world = _read(f"{CHAPTER}/day1.gd").lower()
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
                "res://tests/unit/test_a2_yusuf.gd",
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


class TestA2YusufDay2(unittest.TestCase):
    def test_day2_is_scripted_charge_not_encounter(self) -> None:
        scene = _read(f"{CHAPTER}/day2.tscn")
        source = _read(f"{CHAPTER}/day2.gd")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("dummy.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn("mesura_hud.tscn", scene)
        self.assertIn("ChargeZone", scene)
        self.assertIn("Day2Cinematic", scene)
        self.assertIn("JimenaCamera", scene)
        self.assertIn("CavalryCharge", _read("content/art/characters/horse/horse.tscn"))
        self.assertNotIn("FieldZone", scene)
        self.assertNotIn("Mesnada", scene)
        self.assertNotIn("Dummy1", scene)
        self.assertNotIn("captain.tscn", scene)
        self.assertNotIn("GPUParticles3D", scene)
        self.assertEqual(scene.count('type="DirectionalLight3D"'), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 8)
        self.assertIn("CSGCylinder3D", scene)
        charge_at = scene.find('[node name="ChargeZone"')
        self.assertGreaterEqual(charge_at, 0)
        self.assertIn("collision_mask = 130", scene[charge_at : charge_at + 280])
        self.assertIn("func run_charge", source)
        self.assertIn("func start_charge", source)
        self.assertIn("func complete_resolve", source)
        self.assertIn("func play_cinematic", source)
        self.assertIn("animation_finished", source)
        self.assertIn("return_to_cid_camera", source)
        self.assertIn("_on_yusuf_died", source)
        self.assertIn("yusuf_day2", source)
        self.assertIn("yusuf_day2_done", source)
        self.assertIn("func jimena_on_wall", source)
        self.assertNotIn("func run_field", source)
        self.assertNotIn("func _enter_tree", source)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))

    def test_jimena_stands_on_wall_day2(self) -> None:
        scene = _read(f"{CHAPTER}/day2.tscn")
        jimena = _origin(scene, "Jimena")
        walk = _origin(scene, "WallWalk")
        wall = _origin(scene, "Wall")
        cid = _origin(scene, "Cid")
        self.assertGreaterEqual(jimena[1], walk[1] - 0.2)
        self.assertGreater(jimena[1], 3.5)
        self.assertLess(abs(jimena[2] - walk[2]), 1.5)
        self.assertLess(abs(jimena[2] - wall[2]), 3.0)
        self.assertGreater(abs(cid[2] - jimena[2]), 8.0)
        cam_at = scene.find('[node name="JimenaCamera"')
        self.assertGreaterEqual(cam_at, 0)
        self.assertIn("current = false", scene[cam_at : cam_at + 280])
        self.assertIn('character_id = &"jimena"', scene)
        self.assertIn("collision_layer = 64", scene)

    def test_charge_zone_does_not_overlap_spawn(self) -> None:
        scene = _read(f"{CHAPTER}/day2.tscn")
        cid = _origin(scene, "Cid")
        horse = _origin(scene, "Horse")
        cid_radius = 0.4
        cid_height = 1.8
        cid_min = (cid[0] - cid_radius, cid[1], cid[2] - cid_radius)
        cid_max = (cid[0] + cid_radius, cid[1] + cid_height, cid[2] + cid_radius)
        horse_min = (horse[0] - 0.5, horse[1], horse[2] - 0.8)
        horse_max = (horse[0] + 0.5, horse[1] + 1.4, horse[2] + 0.8)
        for node_name, shape_id in (
            ("ChargeZone", "Box_charge"),
            ("ClimbZone", "Box_climb"),
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
        charge_size = _subresource_size(scene, "Box_charge")
        self.assertGreaterEqual(charge_size[0], 48.0)
        yusuf = _origin(scene, "Yusuf")
        self.assertGreater(abs(cid[2] - yusuf[2]), 4.0)

    def test_embassy3_not_shipped(self) -> None:
        self.assertFalse((ROOT / "content/chapters/a2_embassy3/world.tscn").is_file())
        source = _read(f"{CHAPTER}/day2.gd")
        self.assertIn("a2_embassy3", source)
        self.assertIn("EMBASSY3_SCENE", source)


if __name__ == "__main__":
    unittest.main()
