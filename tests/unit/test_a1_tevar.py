#!/usr/bin/env python3
"""Structural tests for PR-19 a1_tevar battle / table / Colada.

Run: python3 tests/unit/test_a1_tevar.py
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

CHAPTER = "content/chapters/a1_tevar"


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


class TestA1TevarTableColada(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/tevar.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/table_choice.tscn",
            f"{CHAPTER}/table_choice.gd",
            "game/systems/inventory/sword_item.gd",
            "data/items/colada.json",
            "data/characters/ramon_berenguer.json",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
            "content/art/characters/dummy/dummy.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertTrue((ROOT / "content/chapters/a2_murviedro/world.tscn").is_file())

    def test_scene_is_cheap_greybox_pinewood(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("dummy.tscn", scene)
        self.assertIn("captain.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn("mesura_hud.tscn", scene)
        self.assertIn("table_choice.tscn", scene)
        self.assertEqual(scene.count('type="DirectionalLight3D"'), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertIn('type="CSGBox3D"', scene)
        self.assertIn('type="CSGCylinder3D"', scene)
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 8)
        self.assertGreaterEqual(scene.count("[node name=\"Pine"), 6)
        self.assertIn("cone = true", scene)
        self.assertIn("BattleZone", scene)
        self.assertIn("TableZone", scene)
        self.assertIn("TableCamp", scene)
        self.assertIn("Host", scene)
        self.assertIn("Ramon", scene)
        self.assertIn("Mesnada", scene)
        self.assertIn("Horse", scene)
        self.assertIn('character_id = &"ramon_berenguer"', scene)
        self.assertIn("CavalryCharge", _read("content/art/characters/horse/horse.tscn"))
        self.assertIn("NavigationRegion3D", scene)
        battle_at = scene.find('[node name="BattleZone"')
        table_at = scene.find('[node name="TableZone"')
        self.assertGreaterEqual(battle_at, 0)
        self.assertGreaterEqual(table_at, 0)
        self.assertIn("collision_mask = 130", scene[battle_at : battle_at + 280])
        self.assertIn("collision_mask = 130", scene[table_at : table_at + 280])
        self.assertNotIn("GPUParticles3D", scene)

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
        battle_min, battle_max = _zone_aabb(scene, "BattleZone", "Box_battle")
        table_min, table_max = _zone_aabb(scene, "TableZone", "Box_table")
        battle_size = _subresource_size(scene, "Box_battle")
        table_size = _subresource_size(scene, "Box_table")
        battle = _origin(scene, "BattleZone")
        table = _origin(scene, "TableZone")
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, battle_min, battle_max),
            f"BattleZone {battle} size {battle_size} overlaps Cid spawn {cid}",
        )
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, battle_min, battle_max),
            f"BattleZone overlaps Horse spawn {horse}",
        )
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, table_min, table_max),
            f"TableZone {table} size {table_size} overlaps Cid spawn {cid}",
        )
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, table_min, table_max),
            f"TableZone overlaps Horse spawn {horse}",
        )
        self.assertGreater(abs(cid[2] - battle[2]), battle_size[2] / 2.0 + cid_radius)
        self.assertGreater(abs(cid[2] - table[2]), table_size[2] / 2.0 + cid_radius)

    def test_world_script_battle_capture_eat(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func start_battle", source)
        self.assertIn("func run_battle", source)
        self.assertIn("func complete_capture", source)
        self.assertIn("func start_hunger", source)
        self.assertIn("func run_hunger", source)
        self.assertIn("func choose_eat", source)
        self.assertIn("tevar_feed_count", source)
        self.assertIn("SwordItem", source)
        self.assertIn("Phase.IN_HAND", source)
        self.assertIn("a2_murviedro", source)
        self.assertIn("hub_lock_cardena", source)
        self.assertIn("horse_companion", source)
        self.assertIn("can_travel", source)
        self.assertIn("ChapterRunner.travel", source)
        self.assertIn("autosave", source)
        self.assertIn("current_scene != self", source)
        self.assertIn("func _ready", source)
        self.assertIn("lanza_body_limit", source)
        self.assertIn("ramon_berenguer", source)
        self.assertIn("MesnadaMember.from_id", source)
        self.assertIn("goto", source)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn('apply_id(&"colada")', source)
        self.assertNotIn('apply_id("colada")', source)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a1_tevar/world.tscn", runner)
        self.assertIn('&"a1_tevar"', runner)
        dummy = _read("game/combat/dummy_enemy.gd")
        self.assertIn("character_id", dummy)
        self.assertIn("MesnadaMember.from_id", dummy)

    def test_sword_item_is_plot_not_loot(self) -> None:
        source = _read("game/systems/inventory/sword_item.gd")
        self.assertRegex(source, re.compile(r"^class_name SwordItem$", re.MULTILINE))
        self.assertIn("enum Phase { NOT_YET, IN_HAND, GIFTED_TO_INFANTES, IN_COURT, IN_CHAMPION_HAND }", source)
        self.assertIn("func lootable() -> bool:", source)
        self.assertIn("return false", source)
        self.assertIn("func can_player_wield() -> bool:", source)
        self.assertIn("phase == Phase.IN_HAND", source)
        colada = json.loads(_read("data/items/colada.json"))
        self.assertEqual(colada["id"], "colada")
        self.assertEqual(colada["kind"], "plot_sword")
        self.assertEqual(colada["acquired_beat"], "a1_tevar")
        self.assertFalse(colada["lootable"])
        self.assertFalse(colada["sellable"])
        self.assertEqual(colada["wielded_in_lists_by"], "martin_antolinez")
        core = json.loads(_read("data/honor_events/core.json"))
        events = {row["id"]: row for row in core["events"]}
        self.assertNotIn("colada", events)
        self.assertNotIn("tizona", events)
        feed = events["tevar_feed_count"]
        self.assertEqual(feed["deltas"]["honra"], 10)
        self.assertIn("table", feed["tags"])
        self.assertEqual(feed["beat"], "a1_tevar")
        self.assertFalse(feed.get("hard_fail", False))
        self.assertNotIn("colada", json.dumps(feed))

    def test_ramon_json_capturable_count(self) -> None:
        ramon = json.loads(_read("data/characters/ramon_berenguer.json"))
        self.assertEqual(ramon["id"], "ramon_berenguer")
        self.assertEqual(ramon["display_name_key"], "char.ramon_berenguer")
        self.assertEqual(ramon["role"], "count")
        self.assertFalse(ramon["unkillable"])
        self.assertGreater(ramon["combat"], 0)
        self.assertEqual(ramon["recruitable_beat"], "a1_tevar")
        alfonso = json.loads(_read("data/characters/alfonso.json"))
        self.assertTrue(alfonso["unkillable"])
        self.assertNotEqual(ramon["unkillable"], alfonso["unkillable"])

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a1_tevar.battle",
            "a1_tevar.capture",
            "a1_tevar.hunger",
            "a1_tevar.table_ask",
            "a1_tevar.choice_eat",
            "a1_tevar.eat_done",
            "a1_tevar.colada_kept",
            "char.ramon_berenguer",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("Tévar", rows["a1_tevar.battle"]["es"])
        self.assertIn("Remont", rows["a1_tevar.battle"]["es"])
        self.assertIn("mesa", rows["a1_tevar.hunger"]["es"].lower())
        self.assertIn("comer", rows["a1_tevar.choice_eat"]["es"].lower())
        self.assertIn("Colada", rows["a1_tevar.colada_kept"]["es"])
        self.assertIn("Remont", rows["char.ramon_berenguer"]["es"])
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a1_tevar.place_name,Pinar de Tévar,", poem)

    def test_dialogue_hunger_strike_separate_speaker(self) -> None:
        text = _read(f"{CHAPTER}/tevar.dialogue")
        self.assertIn("~ battle", text)
        self.assertIn("~ capture", text)
        self.assertIn("~ hunger", text)
        self.assertIn("~ eat", text)
        self.assertIn("Ramón:", text)
        self.assertIn("Cid:", text)
        self.assertIn("a1_tevar.hunger", text)
        self.assertIn("a1_tevar.table_ask", text)
        self.assertIn("a1_tevar.colada_kept", text)
        self.assertNotIn("{{", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)
        self.assertNotIn("honor_event=colada", text)

    def test_beats_then_murviedro(self) -> None:
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a1_tevar")
        nexts = [step.get("next") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("a2_murviedro", nexts)
        self.assertNotIn("a2_siege", nexts)
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("dialogue", types)
        self.assertIn("choice", types)
        self.assertIn("honor_event", types)
        self.assertIn("travel_spawn", types)
        ids = [step.get("id") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("tevar_feed_count", ids)
        self.assertNotIn("colada", ids)

    def test_graph_cannot_skip_tevar_or_return_to_cardena(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a1_poyo", "a1_tevar"), pairs)
        self.assertIn(("a1_tevar", "a2_murviedro"), pairs)
        self.assertNotIn(("a1_poyo", "a2_murviedro"), pairs)
        self.assertNotIn(("a1_embassy1", "a1_tevar"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertTrue(can_travel(graph, "a1_poyo", "a1_tevar", locked))
        self.assertFalse(can_travel(graph, "a1_poyo", "a2_murviedro", locked))
        self.assertFalse(can_travel(graph, "a1_embassy1", "a1_tevar", locked))
        self.assertFalse(can_travel(graph, "a1_tevar", "a1_cardena", locked))
        self.assertTrue(can_travel(graph, "a1_tevar", "a2_murviedro", locked))
        tevar_out = next(
            edge
            for edge in graph["edges"]
            if edge["from"] == "a1_tevar" and edge["to"] == "a2_murviedro"
        )
        self.assertEqual(tevar_out.get("set_flags"), ["colada_acquired"])
        raid = next(
            edge
            for edge in graph["edges"]
            if edge["from"] == "a1_poyo" and edge["to"] == "a1_poyo_raid"
        )
        self.assertEqual(raid.get("req_flags"), ["v1_extra_raids"])
        self.assertFalse(can_travel(graph, "a1_poyo", "a1_poyo_raid", locked))

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/tevar.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/table_choice.gd",
            "game/systems/inventory/sword_item.gd",
            "data/items/colada.json",
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
                "res://tests/unit/test_a1_tevar.gd",
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
