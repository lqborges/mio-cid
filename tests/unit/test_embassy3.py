#!/usr/bin/env python3
"""Structural tests for a2_embassy3 GiftToKing.

Run: python3 tests/unit/test_embassy3.py
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

CHAPTER = "content/chapters/a2_embassy3"


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


class TestEmbassy3GiftToKing(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/embassy3.dialogue",
            f"{CHAPTER}/beats.json",
            "data/gifts/embassy_3.json",
            "game/systems/gifts/gift_to_king.gd",
            "game/systems/gifts/gift_option.gd",
            "game/ui/embassy_ledger.tscn",
            "game/ui/embassy_ledger.gd",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
            "content/art/characters/captain/captain.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertFalse((ROOT / "content/chapters/a2_tagus/world.tscn").is_file())

    def test_gift_json_same_shape_higher_delta_escrow(self) -> None:
        payload = json.loads(_read("data/gifts/embassy_3.json"))
        first = json.loads(_read("data/gifts/embassy_1.json"))
        self.assertEqual(payload["id"], "embassy_3_valencia")
        self.assertEqual(payload["beat"], "a2_embassy3")
        self.assertEqual(payload["bearer"], "alvar_fanez")
        self.assertEqual(payload["alfonso_response"], "pardon_possible")
        self.assertTrue(payload["spend_escrow_first"])
        self.assertEqual(payload["event_id"], "embassy3_gift")
        options = {row["id"]: row for row in payload["player_options"]}
        first_opts = {row["id"]: row for row in first["player_options"]}
        self.assertIn("thirty_horses", options)
        thirty = options["thirty_horses"]
        self.assertEqual(thirty["horses"], 30)
        self.assertEqual(thirty["marks"], 0)
        self.assertEqual(thirty["blocked_if_horses_lt"], 30)
        self.assertGreater(thirty["honor_delta"], first_opts["thirty_horses"]["honor_delta"])
        self.assertNotEqual(thirty["horses"], thirty["marks"])
        swords = options["thirty_horses_and_swords"]
        self.assertEqual(swords["horses"], 30)
        self.assertEqual(swords["marks"], 200)
        self.assertEqual(swords["blocked_if_horses_lt"], 30)
        self.assertGreaterEqual(
            swords["honor_delta"], first_opts["thirty_horses_and_swords"]["honor_delta"]
        )
        ten = options["ten_horses"]
        self.assertEqual(ten["horses"], 10)
        self.assertEqual(ten["blocked_if_horses_lt"], 10)
        self.assertGreater(ten["honor_delta"], first_opts["ten_horses"]["honor_delta"])
        empty = options["empty_hands"]
        self.assertEqual(empty["horses"], 0)
        self.assertEqual(empty["marks"], 0)
        self.assertGreaterEqual(empty["honor_delta"], first_opts["empty_hands"]["honor_delta"])
        self.assertGreaterEqual(ten["honor_delta"], 10)
        self.assertLessEqual(swords["honor_delta"], 18)
        events = {
            row["id"]: row
            for row in json.loads(_read("data/honor_events/core.json"))["events"]
        }
        gift = events["embassy3_gift"]
        self.assertIn("honor", gift["deltas"])
        self.assertGreaterEqual(gift["deltas"]["honor"], 10)
        self.assertLessEqual(gift["deltas"]["honor"], 18)
        self.assertIn("gift_up", gift["tags"])
        self.assertEqual(gift["beat"], "a2_embassy3")
        self.assertNotIn("onores", gift["deltas"])

    def test_gift_classes_are_resources_not_autoloads(self) -> None:
        king = _read("game/systems/gifts/gift_to_king.gd")
        option = _read("game/systems/gifts/gift_option.gd")
        self.assertRegex(king, re.compile(r"^class_name GiftToKing$", re.MULTILINE))
        self.assertRegex(option, re.compile(r"^class_name GiftOption$", re.MULTILINE))
        self.assertIn("func resolve(", king)
        self.assertIn("spend_escrow_first", king)
        self.assertIn("embassy3_gift", king + _read("data/gifts/embassy_3.json"))
        self.assertIn("func affordable(", option)
        self.assertIn("func block_reason(", option)
        self.assertIn("blocked_if_horses_lt", option)
        self.assertIn("royal_escrow_horses", option)
        project = _read("project.godot")
        self.assertNotIn("GiftToKing=", project)
        self.assertNotIn("gift_to_king.gd", project.split("[autoload]", 1)[1][:800])
        world = _read(f"{CHAPTER}/world.gd")
        self.assertIn("GiftToKing.from_file", world)
        self.assertIn("func attempt_gift", world)
        self.assertIn("func run_gift", world)
        self.assertIn("_skip_cinematic", world)
        self.assertIn("embassy3_done", world)
        self.assertIn("a2_tagus", world)
        self.assertIn("a2_repay_raquel", world)
        self.assertIn("ResourceLoader.exists", world)
        self.assertIn("goto", world)
        self.assertNotIn("func _enter_tree", world)
        self.assertRegex(world, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", world, re.MULTILINE))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a2_embassy3/world.tscn", runner)
        self.assertIn('&"a2_embassy3"', runner)
        ledger = _read("game/ui/embassy_ledger.gd")
        self.assertIn("spend_escrow", ledger)

    def test_scene_is_cheap_greybox_valencia_courtyard(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("captain.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn("mesura_hud.tscn", scene)
        self.assertIn("embassy_ledger.tscn", scene)
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
        self.assertIn('[node name="GiftZone"', scene)
        self.assertIn('[node name="ExitZone"', scene)
        self.assertIn('[node name="AlvarFanez"', scene)
        self.assertIn('[node name="TentA"', scene)
        self.assertIn('[node name="LeaveCinematic"', scene)
        self.assertIn('member_id = &"alvar_fanez"', scene)
        self.assertIn("collision_mask = 130", scene)
        self.assertGreaterEqual(scene.count("collision_mask = 130"), 2)
        self.assertIn("EmbassyLedger", scene)
        self.assertIn("CavalryCharge", _read("content/art/characters/horse/horse.tscn"))

    def test_gift_and_exit_zones_do_not_overlap_spawns(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        cid = _origin(scene, "Cid")
        horse = _origin(scene, "Horse")
        cid_radius = 0.4
        cid_height = 1.8
        cid_min = (cid[0] - cid_radius, cid[1], cid[2] - cid_radius)
        cid_max = (cid[0] + cid_radius, cid[1] + cid_height, cid[2] + cid_radius)
        horse_min = (horse[0] - 0.5, horse[1], horse[2] - 0.8)
        horse_max = (horse[0] + 0.5, horse[1] + 1.4, horse[2] + 0.8)
        for node_name, shape_id in (("GiftZone", "Box_gift"), ("ExitZone", "Box_exit")):
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
            self.assertGreater(abs(cid[2] - origin[2]), (size[2] / 2.0) + cid_radius)

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "ui.gift.thirty_horses",
            "ui.gift.thirty_horses_and_swords",
            "ui.gift.ten_horses",
            "ui.gift.empty_hands",
            "a2_embassy3.prompt",
            "a2_embassy3.alvar_leave",
            "a2_embassy3.alvar_return",
            "a2_embassy3.pardon_possible",
            "a2_embassy3.tagus_wait",
            "a2_embassy3.repay_wait",
            "char.alvar_fanez",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        prompt = rows["a2_embassy3.prompt"]["es"].lower()
        self.assertIn("álvar", prompt)
        self.assertTrue("presente" in prompt or "perdón" in prompt)
        pardon = rows["a2_embassy3.pardon_possible"]["es"].lower()
        self.assertIn("perdón", pardon)
        self.assertIn("posible", pardon)
        with (ROOT / "content/locales/poem_formulas.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            formulas = {row["key"]: row for row in csv.DictReader(handle)}
        self.assertIn("a2_embassy3.place_name", formulas)
        self.assertIn("Valencia", formulas["a2_embassy3.place_name"]["es"])

    def test_dialogue_and_beats(self) -> None:
        text = _read(f"{CHAPTER}/embassy3.dialogue")
        self.assertIn("~ gift", text)
        self.assertIn("~ leave", text)
        self.assertIn("~ return", text)
        self.assertIn("Alvar:", text)
        self.assertIn("Cid:", text)
        self.assertIn("a2_embassy3.alvar_leave", text)
        self.assertIn("a2_embassy3.pardon_possible", text)
        self.assertNotIn("{{", text)
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a2_embassy3")
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("embassy_ledger", types)
        self.assertIn("cinematic", types)
        self.assertIn("travel_spawn", types)
        flags = []
        for step in payload["steps"]:
            if isinstance(step, dict):
                flags.extend(step.get("set_flags", []))
        self.assertIn("embassy3_done", flags)

    def test_tagus_and_join_edges(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a2_yusuf", "a2_embassy3"), pairs)
        self.assertIn(("a2_embassy3", "a2_tagus"), pairs)
        self.assertIn(("a2_embassy3", "a2_repay_raquel"), pairs)
        honest = ["embassy3_done"]
        self.assertTrue(can_travel(graph, "a2_embassy3", "a2_tagus", honest))
        self.assertFalse(can_travel(graph, "a2_embassy3", "a2_repay_raquel", honest))
        cheated = ["embassy3_done", "arcas_cheated"]
        self.assertFalse(can_travel(graph, "a2_embassy3", "a2_tagus", cheated))
        self.assertTrue(can_travel(graph, "a2_embassy3", "a2_repay_raquel", cheated))
        self.assertFalse(can_travel(graph, "a2_yusuf", "a2_tagus", honest))

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/embassy3.dialogue",
            f"{CHAPTER}/beats.json",
            "data/gifts/embassy_3.json",
            "game/systems/gifts/gift_to_king.gd",
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
                "res://tests/unit/test_embassy3.gd",
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
