#!/usr/bin/env python3
"""Structural tests for PR-26b repay Raquel and Vidas.

Run: python3 tests/unit/test_a2_repay_raquel.py
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

CHAPTER = "content/chapters/a2_repay_raquel"


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


class TestA2RepayRaquel(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/repay.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/lenders.gd",
            "data/honor_events/repay_raquel.json",
            "data/characters/raquel.json",
            "data/characters/vidas.json",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertTrue((ROOT / "content/chapters/a2_embassy3/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a2_tagus/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a2_bodas/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_leon/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_bucar/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_despedida/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_corpes/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_querella/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_toledo/world.tscn").is_file())

    def test_hall_greybox_and_separate_lenders(self) -> None:
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
        self.assertIn('[node name="Hall"', scene)
        self.assertIn('[node name="Raquel"', scene)
        self.assertIn('[node name="Vidas"', scene)
        self.assertIn('[node name="PayZone"', scene)
        self.assertIn('[node name="TagusExit"', scene)
        self.assertIn("AlvarFanez", scene)
        self.assertIn('character_id = &"raquel"', scene)
        self.assertIn('character_id = &"vidas"', scene)
        self.assertNotEqual(
            scene.find('character_id = &"raquel"'),
            scene.find('character_id = &"vidas"'),
        )
        self.assertNotIn("ChoiceUI", scene)
        self.assertNotIn("GPUParticles3D", scene)
        pay_at = scene.find('[node name="PayZone"')
        exit_at = scene.find('[node name="TagusExit"')
        self.assertGreaterEqual(pay_at, 0)
        self.assertGreaterEqual(exit_at, 0)
        self.assertIn("collision_mask = 130", scene[pay_at : pay_at + 280])
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
            ("PayZone", "Box_pay"),
            ("TagusExit", "Box_tagus"),
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

    def test_honor_event_clears_stain(self) -> None:
        payload = json.loads(_read("data/honor_events/repay_raquel.json"))
        self.assertEqual(payload["repay_marks"], 600)
        events = {row["id"]: row for row in payload["events"]}
        row = events["repay_raquel"]
        self.assertEqual(row["beat"], "a2_repay_raquel")
        self.assertEqual(row["deltas"]["honra"], 8)
        self.assertNotIn("honor", row["deltas"])
        self.assertNotIn("onores", row["deltas"])
        self.assertEqual(row.get("clear_stain"), "arcas_cheat")
        self.assertIn("repay_done", row["flags_set"])
        self.assertIn("kept_word", row["tags"])
        self.assertFalse(row.get("hard_fail", False))
        core = json.loads(_read("data/honor_events/core.json"))
        core_events = {item["id"]: item for item in core["events"]}
        core_row = core_events["repay_raquel"]
        self.assertEqual(core_row["deltas"]["honra"], 8)
        self.assertEqual(core_row.get("clear_stain"), "arcas_cheat")
        self.assertIn("repay_done", core_row["flags_set"])

    def test_world_script_pay_only(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        self.assertIn("func pay", source)
        self.assertIn("func run_pay", source)
        self.assertIn("func travel_to_tagus", source)
        self.assertIn("repay_raquel", source)
        self.assertIn("repay_done", source)
        self.assertIn("arcas_cheated", source)
        self.assertIn("repay_marks", source)
        self.assertIn("_tunable_int", source)
        self.assertNotIn("func choose_refuse", source)
        self.assertNotIn("func choose_cheat", source)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn("600", source)
        self.assertNotIn("a2_embassy3", source)
        dialogue = _read(f"{CHAPTER}/repay.dialogue")
        self.assertIn("Raquel:", dialogue)
        self.assertIn("Vidas:", dialogue)
        self.assertIn("Álvar:", dialogue)
        self.assertNotIn("~ refuse", dialogue)
        self.assertNotIn("Raquel y Vidas:", dialogue)

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "char.raquel",
            "char.vidas",
            "a2_repay_raquel.minaya",
            "a2_repay_raquel.raquel",
            "a2_repay_raquel.vidas",
            "a2_repay_raquel.pay",
            "a2_repay_raquel.paid",
            "a2_repay_raquel.arrive",
            "a2_repay_raquel.not_owed",
            "a2_repay_raquel.pay_first",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("pagad", rows["a2_repay_raquel.raquel"]["es"].lower())
        self.assertIn("arena", rows["a2_repay_raquel.vidas"]["es"].lower())
        self.assertIn("Raquel", rows["a2_repay_raquel.minaya"]["es"])
        self.assertIn("Vidas", rows["a2_repay_raquel.minaya"]["es"])
        self.assertIn("honra", rows["a2_repay_raquel.paid"]["es"].lower())
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a2_repay_raquel.place_name,Valencia,", poem)
        self.assertIn("a2_repay_raquel.horse_name,Babieca,", poem)

    def test_graph_and_join_and_validate(self) -> None:
        self.assertEqual(validate_main([]), 0)
        beats = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(beats["id"], "a2_repay_raquel")
        self.assertEqual(beats["repay_marks"], 600)
        types = [step.get("type") for step in beats["steps"] if isinstance(step, dict)]
        self.assertIn("dialogue", types)
        self.assertIn("honor_event", types)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a2_embassy3", "a2_repay_raquel"), pairs)
        self.assertIn(("a2_repay_raquel", "a2_tagus"), pairs)
        self.assertNotIn(("a2_yusuf", "a2_repay_raquel"), pairs)
        self.assertNotIn(("a2_embassy2", "a2_repay_raquel"), pairs)
        cheated = ["arcas_cheated", "embassy3_done"]
        self.assertTrue(can_travel(graph, "a2_embassy3", "a2_repay_raquel", cheated))
        self.assertFalse(can_travel(graph, "a2_embassy3", "a2_tagus", cheated))
        self.assertFalse(can_travel(graph, "a2_repay_raquel", "a2_tagus", cheated))
        repaid = cheated + ["repay_done"]
        self.assertTrue(can_travel(graph, "a2_repay_raquel", "a2_tagus", repaid))
        honest = ["embassy3_done"]
        self.assertFalse(can_travel(graph, "a2_embassy3", "a2_repay_raquel", honest))
        self.assertTrue(can_travel(graph, "a2_embassy3", "a2_tagus", honest))
        refuse = ["embassy3_done"]
        self.assertFalse(
            can_travel(graph, "a2_embassy3", "a2_repay_raquel", refuse),
            "refuse-branch cannot open a2_repay_raquel",
        )
        node = next(n for n in graph["nodes"] if n["id"] == "a2_repay_raquel")
        self.assertEqual(
            node["scene"], "res://content/chapters/a2_repay_raquel/world.tscn"
        )
        repay_edge = next(
            edge
            for edge in graph["edges"]
            if edge["from"] == "a2_embassy3" and edge["to"] == "a2_repay_raquel"
        )
        self.assertEqual(
            repay_edge.get("req_flags"), ["embassy3_done", "arcas_cheated"]
        )
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a2_repay_raquel/world.tscn", runner)
        self.assertIn('&"a2_repay_raquel"', runner)
        travel = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func travel_to_tagus", travel)
        self.assertIn("can_travel", travel)
        self.assertIn("goto", travel)

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/repay.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/lenders.gd",
            "data/honor_events/repay_raquel.json",
            "game/autoload/chapter_runner.gd",
        ):
            lowered = _read(rel).lower()
            for token in DENY:
                self.assertNotIn(token, lowered, f"{rel} has {token}")
        world = _read(f"{CHAPTER}/world.gd").lower()
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
                "res://tests/unit/test_a2_repay_raquel.gd",
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
