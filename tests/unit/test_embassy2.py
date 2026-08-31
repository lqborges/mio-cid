#!/usr/bin/env python3
"""Structural tests for PR-26 Avengalvón escort / embassy 2.

Run: python3 tests/unit/test_embassy2.py
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

CHAPTER = "content/chapters/a2_embassy2"


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


class TestEmbassy2EscortAndGift(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/embassy2.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/escort_npc.gd",
            "data/gifts/embassy_2.json",
            "data/gifts/embassy_1.json",
            "data/characters/avengalvon.json",
            "game/systems/gifts/gift_to_king.gd",
            "game/systems/gifts/gift_option.gd",
            "game/ui/embassy_ledger.tscn",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
            "content/art/characters/captain/captain.tscn",
            "content/chapters/a2_jeronimo/world.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertTrue((ROOT / "content/chapters/a2_yusuf/world.tscn").is_file())
        self.assertFalse((ROOT / "content/chapters/a2_embassy3/world.tscn").is_file())
        self.assertFalse((ROOT / "data/gifts/embassy_3.json").is_file())
        self.assertFalse((ROOT / "content/chapters/a3_leon/world.tscn").is_file())

    def test_gift_json_same_shape_higher_honor(self) -> None:
        first = json.loads(_read("data/gifts/embassy_1.json"))
        second = json.loads(_read("data/gifts/embassy_2.json"))
        self.assertEqual(second["id"], "embassy_2_minaya")
        self.assertEqual(second["beat"], "a2_embassy2")
        self.assertEqual(second["bearer"], "alvar_fanez")
        self.assertEqual(second["honor_event"], "embassy2_gift")
        self.assertEqual(second["alfonso_response"], "jimena_may_leave_cardena")
        first_opts = {row["id"]: row for row in first["player_options"]}
        second_opts = {row["id"]: row for row in second["player_options"]}
        self.assertEqual(set(first_opts), set(second_opts))
        for opt_id, row in second_opts.items():
            self.assertEqual(row["horses"], first_opts[opt_id]["horses"])
            self.assertEqual(row["marks"], first_opts[opt_id]["marks"])
        thirty = second_opts["thirty_horses"]
        self.assertEqual(thirty["horses"], 30)
        self.assertEqual(thirty["marks"], 0)
        self.assertEqual(thirty["honor_delta"], 14)
        self.assertEqual(thirty["blocked_if_horses_lt"], 30)
        self.assertGreater(thirty["honor_delta"], first_opts["thirty_horses"]["honor_delta"])
        self.assertGreaterEqual(thirty["honor_delta"], 10)
        self.assertLessEqual(thirty["honor_delta"], 16)
        swords = second_opts["thirty_horses_and_swords"]
        self.assertEqual(swords["honor_delta"], 16)
        self.assertGreaterEqual(swords["honor_delta"], 10)
        self.assertLessEqual(swords["honor_delta"], 16)
        ten = second_opts["ten_horses"]
        self.assertEqual(ten["honor_delta"], 10)
        self.assertEqual(ten["blocked_if_horses_lt"], 10)
        self.assertGreater(ten["honor_delta"], first_opts["ten_horses"]["honor_delta"])
        empty = second_opts["empty_hands"]
        self.assertEqual(empty["horses"], 0)
        self.assertEqual(empty["honor_delta"], -4)
        self.assertGreater(empty["honor_delta"], first_opts["empty_hands"]["honor_delta"])
        self.assertNotIn("blocked_if_onores_gt", empty)
        events = {
            row["id"]: row
            for row in json.loads(_read("data/honor_events/core.json"))["events"]
        }
        gift = events["embassy2_gift"]
        self.assertIn("honor", gift["deltas"])
        self.assertIn("gift_up", gift["tags"])
        self.assertEqual(gift["beat"], "a2_embassy2")
        self.assertNotIn("onores", gift["deltas"])
        self.assertIn("embassy2_done", gift["flags_set"])

    def test_gift_classes_reuse_ledger_not_autoload(self) -> None:
        king = _read("game/systems/gifts/gift_to_king.gd")
        self.assertIn("embassy2_gift", king)
        self.assertIn("_spend_escrow_first", king)
        self.assertIn("royal_escrow_horses", king)
        self.assertIn("func resolve(", king)
        option = _read("game/systems/gifts/gift_option.gd")
        self.assertIn("royal_escrow_horses", option)
        project = _read("project.godot")
        self.assertNotIn("GiftToKing=", project)
        self.assertNotIn("gift_to_king.gd", project.split("[autoload]", 1)[1][:800])
        world = _read(f"{CHAPTER}/world.gd")
        self.assertIn("GiftToKing.from_file", world)
        self.assertIn("res://data/gifts/embassy_2.json", world)
        self.assertIn("func attempt_gift", world)
        self.assertIn("func run_gift", world)
        self.assertIn("func recruit_avengalvon", world)
        self.assertIn("func complete_escort", world)
        self.assertIn("a2_jeronimo", world)
        self.assertIn("avengalvon", world)
        self.assertIn("must_survive_until", world)
        self.assertNotIn("func _enter_tree", world)
        self.assertRegex(world, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", world, re.MULTILINE))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a2_embassy2/world.tscn", runner)
        self.assertIn('&"a2_embassy2"', runner)
        hub = _read("content/chapters/a2_jeronimo/world.gd")
        self.assertIn("func join_family", hub)
        self.assertIn("func family_in_hub", hub)
        self.assertIn("embassy2_done", hub)
        self.assertIn("_restore_avengalvon_if_ready", hub)
        self.assertIn("avengalvon_recruited", hub)
        save = _read("game/autoload/save_service.gd")
        self.assertIn("add_member", save)
        self.assertIn("MesnadaMember.from_id", save)

    def test_scene_is_cheap_greybox_medinaceli_road(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("captain.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn("mesura_hud.tscn", scene)
        self.assertIn("embassy_ledger.tscn", scene)
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
        self.assertIn("RecruitZone", scene)
        self.assertIn("EscortEnd", scene)
        self.assertIn("Avengalvon", scene)
        self.assertIn("Jimena", scene)
        self.assertIn("Elvira", scene)
        self.assertIn("Sol", scene)
        self.assertIn("TentA", scene)
        self.assertIn("Keep", scene)
        self.assertIn("LeaveCinematic", scene)
        self.assertIn('member_id = &"avengalvon"', scene)
        self.assertIn('member_id = &"alvar_fanez"', scene)
        self.assertIn("collision_mask = 130", scene)
        self.assertIn("EmbassyLedger", scene)
        self.assertIn("CavalryCharge", _read("content/art/characters/horse/horse.tscn"))

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
            ("RecruitZone", "Box_recruit"),
            ("EscortEnd", "Box_escort"),
            ("GiftZone", "Box_gift"),
        ):
            origin = _origin(scene, node_name)
            size = _subresource_size(scene, shape_id)
            half = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
            zmin = (origin[0] - half[0], origin[1] - half[1], origin[2] - half[2])
            zmax = (origin[0] + half[0], origin[1] + half[1], origin[2] + half[2])
            self.assertFalse(
                _aabb_overlap(cid_min, cid_max, zmin, zmax),
                f"{node_name} {origin} size {size} overlaps Cid spawn {cid}",
            )
            self.assertFalse(
                _aabb_overlap(horse_min, horse_max, zmin, zmax),
                f"{node_name} overlaps Horse spawn {horse}",
            )
            self.assertGreater(abs(cid[2] - origin[2]), half[2] + cid_radius)

    def test_avengalvon_is_essential(self) -> None:
        person = json.loads(_read("data/characters/avengalvon.json"))
        self.assertEqual(person["id"], "avengalvon")
        self.assertEqual(person["role"], "ally_taifa")
        self.assertTrue(person["essential"])
        self.assertFalse(person["desertion_capable"])
        self.assertEqual(person["recruitable_beat"], "a2_embassy2")
        self.assertEqual(person["must_survive_until"], "a3_despedida")
        tres = _read("data/characters/avengalvon.tres")
        self.assertIn('must_survive_until = &"a3_despedida"', tres)
        self.assertIn("essential = true", tres)

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "char.avengalvon",
            "char.jimena",
            "char.elvira",
            "char.sol",
            "a2_embassy2.prompt",
            "a2_embassy2.avengalvon_kin",
            "a2_embassy2.keep_him",
            "a2_embassy2.recruit",
            "a2_embassy2.escort_prompt",
            "a2_embassy2.jimena_road",
            "a2_embassy2.family_arrives",
            "a2_embassy2.not_creed",
            "a2_embassy2.alvar_return",
            "location.medinaceli",
            "ui.gift.thirty_horses",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("Avengalvón", rows["char.avengalvon"]["es"])
        self.assertIn("Medinaceli", rows["a2_embassy2.escort_prompt"]["es"])
        self.assertIn("Jimena", rows["a2_embassy2.family_arrives"]["es"])
        creed = rows["a2_embassy2.not_creed"]["es"].lower()
        self.assertIn("avengalvón", creed)
        self.assertNotIn("cruzada", creed)
        self.assertNotIn("reconquista", creed)
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a2_embassy2.place_name,Medinaceli,", poem)

    def test_dialogue_and_beats(self) -> None:
        text = _read(f"{CHAPTER}/embassy2.dialogue")
        self.assertIn("~ recruit", text)
        self.assertIn("~ escort", text)
        self.assertIn("~ gift", text)
        self.assertIn("~ return", text)
        self.assertIn("Avengalvon:", text)
        self.assertIn("Jimena:", text)
        self.assertIn("Cid:", text)
        self.assertIn("a2_embassy2.keep_him", text)
        self.assertIn("a2_embassy2.family_arrives", text)
        self.assertNotIn("{{", text)
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a2_embassy2")
        nexts = [step.get("next") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("a2_jeronimo", nexts)
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("embassy_ledger", types)
        self.assertIn("cinematic", types)
        self.assertIn("travel_spawn", types)
        flags = []
        for step in payload["steps"]:
            if isinstance(step, dict):
                flags.extend(step.get("set_flags", []))
        self.assertIn("embassy2_done", flags)
        self.assertIn("avengalvon_recruited", flags)
        self.assertIn("family_in_valencia", flags)

    def test_graph_returns_to_hub(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a2_jeronimo", "a2_embassy2"), pairs)
        self.assertIn(("a2_embassy2", "a2_jeronimo"), pairs)
        self.assertIn(("a2_embassy2", "a2_yusuf"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertTrue(can_travel(graph, "a2_jeronimo", "a2_embassy2", locked))
        self.assertTrue(can_travel(graph, "a2_embassy2", "a2_jeronimo", locked))
        self.assertFalse(can_travel(graph, "a2_siege", "a2_embassy2", locked))
        self.assertFalse(can_travel(graph, "a2_jeronimo", "a2_yusuf", locked))
        after = ["hub_lock_cardena", "embassy2_done"]
        self.assertFalse(can_travel(graph, "a2_jeronimo", "a2_embassy2", after))
        self.assertTrue(can_travel(graph, "a2_jeronimo", "a2_yusuf", after))

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/embassy2.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/escort_npc.gd",
            "data/gifts/embassy_2.json",
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
                "res://tests/unit/test_embassy2.gd",
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
