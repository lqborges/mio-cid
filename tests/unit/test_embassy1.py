#!/usr/bin/env python3
"""Structural tests for PR-17 Embassy 1 / GiftToKing.

Run: python3 tests/unit/test_embassy1.py
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
    "babieca",
    "jura",
    "heston",
    "corpse",
    "reconquista",
    "holy-war",
    "holy_war",
)

CHAPTER = "content/chapters/a1_embassy1"


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


class TestEmbassy1GiftToKing(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/embassy1.dialogue",
            f"{CHAPTER}/beats.json",
            "data/gifts/embassy_1.json",
            "game/systems/gifts/gift_to_king.gd",
            "game/systems/gifts/gift_option.gd",
            "game/ui/embassy_ledger.tscn",
            "game/ui/embassy_ledger.gd",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
            "content/art/characters/captain/captain.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertFalse((ROOT / "content/chapters/a1_poyo/world.tscn").is_file())
        self.assertFalse((ROOT / "content/chapters/a1_tevar/world.tscn").is_file())

    def test_gift_json_horses_are_animals_not_marks(self) -> None:
        payload = json.loads(_read("data/gifts/embassy_1.json"))
        self.assertEqual(payload["id"], "embassy_1_minaya")
        self.assertEqual(payload["beat"], "a1_embassy1")
        self.assertEqual(payload["bearer"], "alvar_fanez")
        self.assertEqual(payload["alfonso_response"], "lands_to_minaya_not_pardon")
        options = {row["id"]: row for row in payload["player_options"]}
        thirty = options["thirty_horses"]
        self.assertEqual(thirty["horses"], 30)
        self.assertEqual(thirty["marks"], 0)
        self.assertEqual(thirty["honor_delta"], 12)
        self.assertEqual(thirty["blocked_if_horses_lt"], 30)
        self.assertNotEqual(thirty["horses"], thirty["marks"])
        swords = options["thirty_horses_and_swords"]
        self.assertEqual(swords["horses"], 30)
        self.assertEqual(swords["marks"], 200)
        self.assertEqual(swords["honor_delta"], 18)
        self.assertEqual(swords["blocked_if_horses_lt"], 30)
        ten = options["ten_horses"]
        self.assertEqual(ten["horses"], 10)
        self.assertEqual(ten["marks"], 0)
        self.assertEqual(ten["honor_delta"], 8)
        self.assertEqual(ten["blocked_if_horses_lt"], 10)
        empty = options["empty_hands"]
        self.assertEqual(empty["horses"], 0)
        self.assertEqual(empty["marks"], 0)
        self.assertEqual(empty["honor_delta"], -6)
        self.assertEqual(empty["blocked_if_onores_gt"], 20)
        events = {
            row["id"]: row
            for row in json.loads(_read("data/honor_events/core.json"))["events"]
        }
        gift = events["embassy1_gift"]
        self.assertIn("honor", gift["deltas"])
        self.assertIn("gift_up", gift["tags"])
        self.assertEqual(gift["beat"], "a1_embassy1")
        self.assertNotIn("onores", gift["deltas"])

    def test_gift_classes_are_resources_not_autoloads(self) -> None:
        king = _read("game/systems/gifts/gift_to_king.gd")
        option = _read("game/systems/gifts/gift_option.gd")
        self.assertRegex(king, re.compile(r"^class_name GiftToKing$", re.MULTILINE))
        self.assertRegex(option, re.compile(r"^class_name GiftOption$", re.MULTILINE))
        self.assertIn("func resolve(", king)
        self.assertIn("HonorService", king)
        self.assertIn("embassy1_gift", king)
        self.assertIn("func affordable(", option)
        self.assertIn("blocked_if_horses_lt", option)
        project = _read("project.godot")
        self.assertNotIn("GiftToKing=", project)
        self.assertNotIn("gift_to_king.gd", project.split("[autoload]", 1)[1][:800])
        world = _read(f"{CHAPTER}/world.gd")
        self.assertIn("GiftToKing.from_file", world)
        self.assertIn("func attempt_gift", world)
        self.assertIn("func run_gift", world)
        self.assertIn("minaya_lands_restored", world)
        self.assertIn("recruitment_flood", world)
        self.assertIn("a1_poyo", world)
        self.assertNotIn("func _enter_tree", world)
        self.assertRegex(world, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", world, re.MULTILINE))
        ledger = _read("game/ui/embassy_ledger.gd")
        self.assertRegex(ledger, re.compile(r"^class_name EmbassyLedger$", re.MULTILINE))
        self.assertIn("blocked", ledger)
        self.assertIn("disabled", ledger)
        scene = _read("game/ui/embassy_ledger.tscn")
        self.assertIn("anchor_right = 1.0", scene)
        self.assertIn("anchor_bottom = 1.0", scene)
        self.assertIn("Confirm", scene)
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a1_embassy1/world.tscn", runner)
        self.assertIn('&"a1_embassy1"', runner)

    def test_scene_is_cheap_greybox_road_camp(self) -> None:
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
        self.assertIn("GiftZone", scene)
        self.assertIn("AlvarFanez", scene)
        self.assertIn("TentA", scene)
        self.assertIn("LeaveCinematic", scene)
        self.assertIn('member_id = &"alvar_fanez"', scene)
        self.assertIn("collision_mask = 130", scene)
        self.assertIn("EmbassyLedger", scene)
        self.assertIn("CavalryCharge", _read("content/art/characters/horse/horse.tscn"))

    def test_gift_zone_does_not_overlap_spawn(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        cid = _origin(scene, "Cid")
        zone = _origin(scene, "GiftZone")
        size = _subresource_size(scene, "Box_gift")
        half = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
        zone_min = (zone[0] - half[0], zone[1] - half[1], zone[2] - half[2])
        zone_max = (zone[0] + half[0], zone[1] + half[1], zone[2] + half[2])
        cid_radius = 0.4
        cid_height = 1.8
        cid_min = (cid[0] - cid_radius, cid[1], cid[2] - cid_radius)
        cid_max = (cid[0] + cid_radius, cid[1] + cid_height, cid[2] + cid_radius)
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, zone_min, zone_max),
            f"GiftZone {zone} size {size} overlaps Cid spawn {cid}",
        )
        self.assertGreater(abs(cid[2] - zone[2]), half[2] + cid_radius)
        horse = _origin(scene, "Horse")
        horse_min = (horse[0] - 0.5, horse[1], horse[2] - 0.8)
        horse_max = (horse[0] + 0.5, horse[1] + 1.4, horse[2] + 0.8)
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, zone_min, zone_max),
            f"GiftZone overlaps Horse spawn {horse}",
        )

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "ui.embassy_ledger.title",
            "ui.embassy_ledger.confirm",
            "ui.embassy_ledger.blocked",
            "ui.embassy_ledger.horses",
            "ui.embassy_ledger.marks",
            "ui.gift.thirty_horses",
            "ui.gift.thirty_horses_and_swords",
            "ui.gift.ten_horses",
            "ui.gift.empty_hands",
            "a1_embassy1.prompt",
            "a1_embassy1.alvar_leave",
            "a1_embassy1.alvar_return",
            "a1_embassy1.lands_restored",
            "char.alvar_fanez",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("caballos", rows["ui.gift.thirty_horses"]["es"].lower())
        self.assertNotIn("marcos", rows["ui.gift.thirty_horses"]["es"].lower())
        self.assertEqual(rows["ui.embassy_ledger.horses"]["es"], "caballos")
        self.assertIn("Álvar", rows["ui.embassy_ledger.confirm"]["es"])
        lands = rows["a1_embassy1.lands_restored"]["es"].lower()
        self.assertIn("minaya", lands)
        self.assertTrue("tierra" in lands or "tierras" in lands)
        self.assertTrue("perdon" in lands or "perdona" in lands)

    def test_dialogue_and_beats(self) -> None:
        text = _read(f"{CHAPTER}/embassy1.dialogue")
        self.assertIn("~ gift", text)
        self.assertIn("~ leave", text)
        self.assertIn("~ return", text)
        self.assertIn("Alvar:", text)
        self.assertIn("Cid:", text)
        self.assertIn("a1_embassy1.alvar_leave", text)
        self.assertIn("a1_embassy1.lands_restored", text)
        self.assertNotIn("{{", text)
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a1_embassy1")
        nexts = [step.get("next") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("a1_poyo", nexts)
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("embassy_ledger", types)
        self.assertIn("cinematic", types)
        self.assertIn("travel_spawn", types)
        flags = []
        for step in payload["steps"]:
            if isinstance(step, dict):
                flags.extend(step.get("set_flags", []))
        self.assertIn("embassy1_done", flags)
        self.assertIn("minaya_lands_restored", flags)
        self.assertIn("recruitment_flood", flags)

    def test_destierro_spine_embassy_to_poyo(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a1_alcocer", "a1_embassy1"), pairs)
        self.assertIn(("a1_embassy1", "a1_poyo"), pairs)
        locked = ["hub_lock_cardena", "alcocer_booty_divided"]
        self.assertTrue(can_travel(graph, "a1_alcocer", "a1_embassy1", locked))
        self.assertTrue(can_travel(graph, "a1_embassy1", "a1_poyo", locked))
        self.assertFalse(can_travel(graph, "a1_embassy1", "a1_cardena", locked))
        self.assertFalse(can_travel(graph, "a1_embassy1", "a1_alcocer", locked))
        self.assertFalse(can_travel(graph, "a1_embassy1", "a1_tevar", locked))

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/embassy1.dialogue",
            f"{CHAPTER}/beats.json",
            "data/gifts/embassy_1.json",
            "game/systems/gifts/gift_to_king.gd",
            "game/systems/gifts/gift_option.gd",
            "game/ui/embassy_ledger.gd",
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
                "res://tests/unit/test_embassy1.gd",
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
