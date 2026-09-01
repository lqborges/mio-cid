#!/usr/bin/env python3
"""Structural tests for a3_despedida departure / swords gifted / Avengalvón road.

Run: python3 tests/unit/test_a3_despedida.py
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

CHAPTER = "content/chapters/a3_despedida"
GIFT_FLAGS = ("despedida_agreed", "swords_gifted", "daughters_left", "avengalvon_alive_despedida")


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


class TestA3DespedidaSwordsAndRoad(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/despedida.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/depart_npc.gd",
            "game/systems/inventory/sword_item.gd",
            "data/items/colada.json",
            "data/items/tizona.json",
            "data/characters/avengalvon.json",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
            "content/art/characters/dummy/dummy.tscn",
            "content/chapters/a3_bucar/world.tscn",
            "content/chapters/a3_leon/world.tscn",
            "content/chapters/a2_embassy2/world.tscn",
            "content/chapters/a3_corpes/world.tscn",
            "content/chapters/a3_querella/world.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertFalse((ROOT / "content/chapters/a3_toledo/world.tscn").is_file())

    def test_scene_is_cheap_greybox_hall_and_road(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
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
        self.assertIn('type="CSGBox3D"', scene)
        self.assertIn('type="CSGCylinder3D"', scene)
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 8)
        self.assertIn("cone = true", scene)
        for node in (
            "Hall",
            "GiftTable",
            "GiftZone",
            "AmbushZone",
            "Avengalvon",
            "Infantes",
            "Ferran",
            "Diego",
            "Jimena",
            "Elvira",
            "Sol",
            "Mesnada",
            "Cid",
            "Horse",
            "PlaceName",
        ):
            self.assertIn(f'[node name="{node}"', scene, node)
        self.assertIn('character_id = &"avengalvon"', scene)
        self.assertIn('character_id = &"ferran_gonzalez"', scene)
        self.assertIn('character_id = &"diego_gonzalez"', scene)
        ferran_block = scene[scene.find('[node name="Ferran"') : scene.find('[node name="Diego"')]
        diego_block = scene[scene.find('[node name="Diego"') : scene.find('[node name="Mesnada"')]
        avengalvon_block = scene[
            scene.find('[node name="Avengalvon"') : scene.find('[node name="Infantes"')
        ]
        self.assertIn("spectator = true", ferran_block)
        self.assertIn("spectator = true", diego_block)
        self.assertNotIn("spectator = true", avengalvon_block)
        self.assertIn("CavalryCharge", _read("content/art/characters/horse/horse.tscn"))
        self.assertIn("NavigationRegion3D", scene)
        self.assertNotIn("GPUParticles3D", scene)
        gift_at = scene.find('[node name="GiftZone"')
        ambush_at = scene.find('[node name="AmbushZone"')
        self.assertGreaterEqual(gift_at, 0)
        self.assertGreaterEqual(ambush_at, 0)
        self.assertIn("collision_mask = 130", scene[gift_at : gift_at + 280])
        self.assertIn("collision_mask = 130", scene[ambush_at : ambush_at + 280])

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
            ("GiftZone", "Box_gift"),
            ("AmbushZone", "Box_ambush"),
        ):
            zmin, zmax = _zone_aabb(scene, node_name, shape_id)
            origin = _origin(scene, node_name)
            size = _subresource_size(scene, shape_id)
            self.assertFalse(
                _aabb_overlap(cid_min, cid_max, zmin, zmax),
                f"{node_name} {origin} size {size} overlaps Cid spawn {cid}",
            )
            self.assertFalse(
                _aabb_overlap(horse_min, horse_max, zmin, zmax),
                f"{node_name} overlaps Horse spawn {horse}",
            )
            self.assertGreater(abs(cid[2] - origin[2]), size[2] / 2.0 + cid_radius)

    def test_world_script_gift_and_road(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func start_departure", source)
        self.assertIn("func run_departure", source)
        self.assertIn("func start_ambush", source)
        self.assertIn("func run_ambush", source)
        self.assertIn("func start_let_go", source)
        self.assertIn("GIFTED_TO_INFANTES", source)
        self.assertIn("SwordItem", source)
        self.assertIn("colada", source)
        self.assertIn("tizona", source)
        self.assertIn("avengalvon_dead", source)
        self.assertIn("hard_fail", source)
        self.assertIn("fail_copy.gd", source)
        self.assertIn("avengalvon_alive_despedida", source)
        self.assertIn("keep_avengalvon", source)
        self.assertIn("a3_corpes", source)
        self.assertIn("ResourceLoader.exists", source)
        self.assertIn("hub_lock_cardena", source)
        self.assertIn("horse_companion", source)
        self.assertIn("can_travel", source)
        self.assertIn("autosave", source)
        self.assertIn("current_scene != self", source)
        self.assertIn("goto", source)
        self.assertIn("func _ready", source)
        self.assertIn("lanza_body_limit", source)
        self.assertIn("_restore_avengalvon_if_ready", source)
        self.assertIn("MesnadaMember.from_id", source)
        self.assertIn("must_survive_until", _read("data/characters/avengalvon.json"))
        self.assertIn("PROCESS_MODE_DISABLED", source)
        leave = source.split("func _leave_for_corpes", 1)[1].split("func _dest_ready", 1)[0]
        self.assertIn("not _dest_ready() or not _travel", leave)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn('apply_id(&"colada")', source)
        self.assertNotIn('apply_id(&"tizona")', source)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a3_despedida/world.tscn", runner)
        self.assertIn('&"a3_despedida"', runner)
        bucar = _read("content/chapters/a3_bucar/world.gd")
        self.assertIn("DEST_SCENE", bucar)
        self.assertIn("goto", bucar)
        self.assertIn("current_scene != self", bucar)

    def test_sword_item_gift_is_plot_not_loot(self) -> None:
        source = _read("game/systems/inventory/sword_item.gd")
        self.assertIn("GIFTED_TO_INFANTES", source)
        for stem in ("colada", "tizona"):
            payload = json.loads(_read(f"data/items/{stem}.json"))
            self.assertEqual(payload["kind"], "plot_sword")
            self.assertEqual(payload["gifted_beat"], "a3_despedida")
            self.assertFalse(payload["lootable"])
            self.assertFalse(payload["sellable"])
        core = json.loads(_read("data/honor_events/core.json"))
        events = {row["id"]: row for row in core["events"]}
        self.assertNotIn("colada", events)
        self.assertNotIn("tizona", events)
        fail = _read("game/ui/fail_copy.gd")
        self.assertIn('&"avengalvon_dead"', fail)
        self.assertIn("_copy_for", fail)
        self.assertIn("fail.%s", fail)

    def test_avengalvon_is_essential(self) -> None:
        person = json.loads(_read("data/characters/avengalvon.json"))
        self.assertEqual(person["id"], "avengalvon")
        self.assertTrue(person["essential"])
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
            "a3_despedida.prompt",
            "a3_despedida.agree",
            "a3_despedida.swords",
            "a3_despedida.daughters_leave",
            "a3_despedida.ambush",
            "a3_despedida.lets_go",
            "fail.avengalvon_dead",
            "char.avengalvon",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("Colada", rows["a3_despedida.swords"]["es"])
        self.assertIn("Tizona", rows["a3_despedida.swords"]["es"])
        self.assertIn("botín", rows["a3_despedida.swords"]["es"].lower() + rows["a3_despedida.agree"]["es"].lower())
        self.assertIn("Avengalvón", rows["a3_despedida.lets_go"]["es"])
        self.assertIn("vive", rows["a3_despedida.lets_go"]["es"].lower())
        self.assertIn("Avengalvón", rows["fail.avengalvon_dead"]["es"])
        self.assertIn("Recargad", rows["fail.avengalvon_dead"]["es"])
        self.assertNotEqual(rows["fail.avengalvon_dead"]["es"].lower(), "the name is empty")
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a3_despedida.place_name,Valencia,", poem)

    def test_dialogue_and_beats(self) -> None:
        text = _read(f"{CHAPTER}/despedida.dialogue")
        self.assertIn("~ depart", text)
        self.assertIn("~ swords", text)
        self.assertIn("~ ambush", text)
        self.assertIn("~ lets_go", text)
        self.assertIn("Cid:", text)
        self.assertIn("Jimena:", text)
        self.assertIn("Avengalvon:", text)
        self.assertIn("a3_despedida.swords", text)
        self.assertIn("a3_despedida.lets_go", text)
        self.assertNotIn("{{", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a3_despedida")
        nexts = [step.get("next") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("a3_corpes", nexts)
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("cinematic", types)
        self.assertIn("dialogue", types)
        self.assertIn("travel_spawn", types)
        flags = []
        for step in payload["steps"]:
            if isinstance(step, dict):
                flags.extend(step.get("set_flags", []))
        for flag in GIFT_FLAGS:
            self.assertIn(flag, flags, flag)

    def test_graph_cannot_skip_bucar(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a3_bucar", "a3_despedida"), pairs)
        self.assertIn(("a3_despedida", "a3_corpes"), pairs)
        self.assertNotIn(("a3_leon", "a3_despedida"), pairs)
        self.assertNotIn(("a3_bucar", "a3_corpes"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertFalse(can_travel(graph, "a3_bucar", "a3_despedida", locked))
        self.assertTrue(
            can_travel(graph, "a3_bucar", "a3_despedida", locked + ["tizona_acquired"])
        )
        self.assertTrue(
            can_travel(
                graph,
                "a3_despedida",
                "a3_corpes",
                locked + ["tizona_acquired", "swords_gifted"],
            )
        )
        self.assertFalse(
            can_travel(graph, "a3_leon", "a3_despedida", locked + ["lion_returned"])
        )
        dest_out = next(
            edge
            for edge in graph["edges"]
            if edge["from"] == "a3_despedida" and edge["to"] == "a3_corpes"
        )
        self.assertIn("swords_gifted", dest_out.get("set_flags", []))
        self.assertIn("avengalvon_alive_despedida", dest_out.get("set_flags", []))
        node = next(n for n in graph["nodes"] if n["id"] == "a3_despedida")
        self.assertEqual(node["scene"], "res://content/chapters/a3_despedida/world.tscn")

    def test_ci_keeps_siblings_and_runs_despedida_after_import(self) -> None:
        workflow = _read(".github/workflows/import-and-test.yml")
        self.assertIn("Run Python embassy2 tests", workflow)
        self.assertIn("Run Python a3_leon tests", workflow)
        self.assertIn("Run Python a3_bucar tests", workflow)
        self.assertIn("Run Python a3_despedida tests", workflow)
        self.assertIn("Run Python a3_corpes tests", workflow)
        self.assertIn("tests/unit/test_embassy2.py", workflow)
        self.assertIn("tests/unit/test_a3_leon.py", workflow)
        self.assertIn("tests/unit/test_a3_bucar.py", workflow)
        self.assertIn("tests/unit/test_a3_despedida.py", workflow)
        self.assertIn("tests/unit/test_a3_corpes.py", workflow)
        self.assertIn("Run embassy2 Avengalvón escort headless test", workflow)
        self.assertIn("Run a3_leon lion scene headless test", workflow)
        self.assertIn("Run a3_bucar shore/Tizona headless test", workflow)
        self.assertIn("Run a3_despedida departure/Avengalvón headless test", workflow)
        self.assertIn("Run a3_corpes aftermath headless test", workflow)
        self.assertIn("res://tests/unit/test_embassy2.gd", workflow)
        self.assertIn("res://tests/unit/test_a3_leon.gd", workflow)
        self.assertIn("res://tests/unit/test_a3_bucar.gd", workflow)
        self.assertIn("res://tests/unit/test_a3_despedida.gd", workflow)
        self.assertIn("res://tests/unit/test_a3_corpes.gd", workflow)
        imported = workflow.find("Import project")
        self.assertLess(imported, workflow.find("res://tests/unit/test_a3_despedida.gd"))
        self.assertLess(imported, workflow.find("res://tests/unit/test_a3_corpes.gd"))
        self.assertLess(
            workflow.find("Run Python a3_bucar tests"),
            workflow.find("Run Python a3_despedida tests"),
        )
        self.assertLess(
            workflow.find("Run Python a3_despedida tests"),
            workflow.find("Run Python a3_corpes tests"),
        )

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/despedida.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/depart_npc.gd",
            "game/systems/inventory/sword_item.gd",
            "game/ui/fail_copy.gd",
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
                "res://tests/unit/test_a3_despedida.gd",
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
