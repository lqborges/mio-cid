#!/usr/bin/env python3
"""Structural tests for PR-15 a1_castejon dawn take + forced sell.

Run: python3 tests/unit/test_a1_castejon.py
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

CHAPTER = "content/chapters/a1_castejon"


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


class TestA1CastejonDawnTake(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/castejon.dialogue",
            f"{CHAPTER}/beats.json",
            "data/towns/castejon.json",
            "data/honor_events/towns.json",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
            "content/art/characters/dummy/dummy.tscn",
            "game/ui/keep_or_sell.tscn",
            "game/ui/booty_divide.tscn",
            "game/systems/travel/town_holding.gd",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_scene_is_cheap_greybox_dawn(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("dummy.tscn", scene)
        self.assertIn("captain.tscn", scene)
        self.assertIn("keep_or_sell.tscn", scene)
        self.assertIn("booty_divide.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn("mesura_hud.tscn", scene)
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
        self.assertIn("TakeZone", scene)
        self.assertIn("Garrison", scene)
        self.assertIn("Mesnada", scene)
        self.assertIn("Horse", scene)
        self.assertIn("AlvarReport", scene)
        self.assertIn("KeepOrSell", scene)
        self.assertIn("BootyDivide", scene)
        self.assertIn("River", scene)
        self.assertIn("Keep", scene)
        self.assertIn("LootPile", scene)
        self.assertIn("CavalryCharge", _read("content/art/characters/horse/horse.tscn"))
        self.assertNotIn("AlvarFanez", scene)
        self.assertNotIn('member_id = &"alvar_fanez"', scene)

    def test_take_zone_does_not_overlap_spawn(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        cid = _origin(scene, "Cid")
        zone = _origin(scene, "TakeZone")
        size = _subresource_size(scene, "Box_take")
        half = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
        zone_min = (zone[0] - half[0], zone[1] - half[1], zone[2] - half[2])
        zone_max = (zone[0] + half[0], zone[1] + half[1], zone[2] + half[2])
        cid_radius = 0.4
        cid_height = 1.8
        cid_min = (cid[0] - cid_radius, cid[1], cid[2] - cid_radius)
        cid_max = (cid[0] + cid_radius, cid[1] + cid_height, cid[2] + cid_radius)
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, zone_min, zone_max),
            f"TakeZone {zone} size {size} overlaps Cid spawn {cid}",
        )
        self.assertGreater(abs(cid[2] - zone[2]), half[2] + cid_radius)
        horse = _origin(scene, "Horse")
        horse_min = (horse[0] - 0.5, horse[1], horse[2] - 0.8)
        horse_max = (horse[0] + 0.5, horse[1] + 1.4, horse[2] + 0.8)
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, zone_min, zone_max),
            f"TakeZone overlaps Horse spawn {horse}",
        )

    def test_world_script_take_loot_sell_keep_fail(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func start_take", source)
        self.assertIn("func run_take", source)
        self.assertIn("func complete_take", source)
        self.assertIn("func choose_keep", source)
        self.assertIn("func choose_sell", source)
        self.assertIn("castejon_keep", source)
        self.assertIn("castejon_take", source)
        self.assertIn("castejon_sell", source)
        self.assertIn("a1_alcocer", source)
        self.assertIn("hub_lock_cardena", source)
        self.assertIn("horse_companion", source)
        self.assertIn("can_travel", source)
        self.assertIn("ChapterRunner.travel", source)
        self.assertIn("autosave", source)
        self.assertIn("current_scene != self", source)
        self.assertIn("func _ready", source)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn("camp_night(", source)
        self.assertNotIn("rest_camp(", source)
        self.assertNotIn("12", source)
        self.assertIn("lanza_body_limit", source)
        self.assertIn("AlvarReport", source)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a1_castejon/world.tscn", runner)
        self.assertIn('&"a1_castejon"', runner)
        self.assertIn("KEEP_EVENT", source)
        self.assertIn("apply_id", source)

    def test_keep_is_hard_fail_not_flavor(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("castejon_keep", source)
        self.assertIn("KEEP_KEY", source)
        self.assertIn("a1_castejon.keep_fail", source)
        towns = json.loads(_read("data/honor_events/towns.json"))
        events = {row["id"]: row for row in towns["events"]}
        keep = events["castejon_keep"]
        self.assertTrue(keep["hard_fail"])
        self.assertEqual(keep["hard_fail_reason"], "alfonso_wrath")
        self.assertEqual(keep["deltas"]["honor"], -40)
        self.assertIn("alfonso_wrath", keep["tags"])
        castejon = json.loads(_read("data/towns/castejon.json"))
        self.assertTrue(castejon["alfonso_protectorate"])
        self.assertTrue(castejon["keep_past_deadline_fail"])
        self.assertEqual(castejon["sell_deadline_days"], 0)
        fail = _read("game/ui/fail_copy.gd")
        self.assertIn('&"alfonso_wrath"', fail)

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a1_castejon.dawn",
            "a1_castejon.take",
            "a1_castejon.alvar_henares",
            "a1_castejon.sell_done",
            "a1_castejon.keep_fail",
            "location.castejon",
            "char.alvar_fanez",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("alba", rows["a1_castejon.dawn"]["es"].lower())
        self.assertIn("henares", rows["a1_castejon.alvar_henares"]["es"].lower())
        self.assertIn("alfonso", rows["a1_castejon.keep_fail"]["es"].lower())
        self.assertIn("Álvar", rows["char.alvar_fanez"]["es"])

    def test_dialogue_alvar_off_map(self) -> None:
        text = _read(f"{CHAPTER}/castejon.dialogue")
        self.assertIn("~ dawn", text)
        self.assertIn("~ alvar_report", text)
        self.assertIn("a1_castejon.alvar_henares", text)
        self.assertIn("Alvar:", text)
        self.assertIn("off-map", text.lower())
        self.assertNotIn("{{", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)

    def test_beats_sell_to_alcocer_keep_fail(self) -> None:
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a1_castejon")
        nexts = [step.get("next") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("a1_alcocer", nexts)
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("keep_or_sell", types)
        self.assertIn("booty_divide", types)
        self.assertIn("fail_copy", types)
        self.assertIn("travel_spawn", types)
        reasons = [
            step.get("reason") for step in payload["steps"] if isinstance(step, dict)
        ]
        self.assertIn("alfonso_wrath", reasons)

    def test_destierro_spine_and_hub_lock(self) -> None:
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a1_navapalos", "a1_castejon"), pairs)
        self.assertIn(("a1_castejon", "a1_alcocer"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertTrue(can_travel(graph, "a1_navapalos", "a1_castejon", locked))
        self.assertTrue(can_travel(graph, "a1_castejon", "a1_alcocer", locked))
        self.assertFalse(can_travel(graph, "a1_castejon", "a1_cardena", locked))
        self.assertFalse(can_travel(graph, "a1_castejon", "a1_navapalos", locked))
        self.assertFalse(can_travel(graph, "a1_castejon", "a1_vivar", locked))

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/castejon.dialogue",
            f"{CHAPTER}/beats.json",
            "data/towns/castejon.json",
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
                "res://tests/unit/test_a1_castejon.gd",
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
