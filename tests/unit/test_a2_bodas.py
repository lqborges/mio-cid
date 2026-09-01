#!/usr/bin/env python3
"""Structural tests for Valencia marriages and Infantes.

Run: python3 tests/unit/test_a2_bodas.py
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

CHAPTER = "content/chapters/a2_bodas"
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


class TestA2BodasInfantes(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/bodas.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/infante.gd",
            "data/honor_events/bodas.json",
            "data/characters/ferran_gonzalez.json",
            "data/characters/diego_gonzalez.json",
            "content/chapters/a2_tagus/world.tscn",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertTrue((ROOT / "content/chapters/a3_leon/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_bucar/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_despedida/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_corpes/world.tscn").is_file())
        self.assertFalse((ROOT / "content/chapters/a3_querella/world.tscn").is_file())

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
        self.assertIn("FerranGonzalez", scene)
        self.assertIn("DiegoGonzalez", scene)
        self.assertIn("Elvira", scene)
        self.assertIn("Sol", scene)
        self.assertIn("TrainZone", scene)
        self.assertIn("GiftZone", scene)
        self.assertIn("CageZone", scene)
        self.assertIn("LeonExit", scene)
        self.assertIn('character_id = &"ferran_gonzalez"', scene)
        self.assertIn('character_id = &"diego_gonzalez"', scene)
        self.assertNotIn("ChoiceUI", scene)
        self.assertNotIn("GPUParticles3D", scene)
        for node_name in ("TrainZone", "GiftZone", "CageZone", "LeonExit"):
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
            ("TrainZone", "Box_train"),
            ("GiftZone", "Box_gift"),
            ("CageZone", "Box_cage"),
            ("LeonExit", "Box_leon"),
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

    def test_infantes_stats(self) -> None:
        ferran = json.loads(_read("data/characters/ferran_gonzalez.json"))
        diego = json.loads(_read("data/characters/diego_gonzalez.json"))
        self.assertEqual(ferran["role"], "infante")
        self.assertEqual(diego["role"], "infante")
        self.assertEqual(ferran["combat"], 22)
        self.assertEqual(diego["combat"], 20)
        self.assertEqual(ferran["birth"], 92)
        self.assertEqual(diego["birth"], 92)
        self.assertEqual(ferran["mesura_max"], 0)
        self.assertEqual(diego["mesura_max"], 0)
        self.assertEqual(ferran["recruitable_beat"], "a2_bodas")
        self.assertEqual(diego["recruitable_beat"], "a2_bodas")
        self.assertFalse(ferran["list_eligible"])
        self.assertFalse(diego["list_eligible"])
        payload = json.loads(_read("data/honor_events/bodas.json"))
        self.assertEqual(payload["gift_marks"], 40)
        self.assertEqual(payload["train_combat_cap"], 22)

    def test_world_script_train_and_leon_gate(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        self.assertIn("func join_infantes", source)
        self.assertIn("func train_infantes", source)
        self.assertIn("func gift_infantes", source)
        self.assertIn("func try_open_cage", source)
        self.assertIn("func travel_to_leon", source)
        self.assertIn("ResourceLoader.exists", source)
        self.assertIn("a3_leon", source)
        self.assertIn("train_combat_cap", source)
        self.assertIn("_tunable_int", source)
        self.assertIn("goto", source)
        self.assertIn("_pending_cue", source)
        start_gift = source.split("func start_gift", 1)[1].split("func run_gift", 1)[0]
        self.assertIn('_pending_cue = "gift"', start_gift)
        start_train = source.split("func start_train", 1)[1].split("func run_train", 1)[0]
        self.assertIn('_pending_cue = "train"', start_train)
        ended = source.split("func _on_dialogue_ended", 1)[1].split("func _try_balloon", 1)[0]
        self.assertIn('cue == "train"', ended)
        self.assertIn('cue == "gift"', ended)
        self.assertNotIn("if not _trained", ended)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn("22", source)
        self.assertNotIn("flute", source.lower())
        dialogue = _read(f"{CHAPTER}/bodas.dialogue")
        self.assertIn("~ arrive", dialogue)
        self.assertIn("~ train", dialogue)
        self.assertIn("Ferrán:", dialogue)
        self.assertIn("Diego:", dialogue)
        self.assertNotIn("~ refuse", dialogue)

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "char.ferran_gonzalez",
            "char.diego_gonzalez",
            "char.elvira",
            "char.sol",
            "a2_bodas.arrive",
            "a2_bodas.train",
            "a2_bodas.train_done",
            "a2_bodas.gift",
            "a2_bodas.watch",
            "a2_bodas.cage_locked",
            "a2_bodas.leon_wait",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("infantes", rows["a2_bodas.arrive"]["es"].lower())
        self.assertIn("mesura", rows["a2_bodas.gift"]["es"].lower())
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a2_bodas.place_name,Valencia,", poem)
        self.assertIn("a2_bodas.horse_name,Babieca,", poem)

    def test_graph_and_validate(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a2_tagus", "a2_bodas"), pairs)
        self.assertIn(("a2_bodas", "a3_leon"), pairs)
        self.assertTrue(can_travel(graph, "a2_tagus", "a2_bodas", []))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a2_bodas/world.tscn", runner)
        self.assertIn('&"a2_bodas"', runner)
        self.assertIn("BODAS_SCENE", runner)

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/bodas.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/infante.gd",
            "data/honor_events/bodas.json",
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
                "res://tests/unit/test_a2_bodas.gd",
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
