#!/usr/bin/env python3
"""Structural tests for a3_bucar shore battle / Infantes flee / Tizona.

Run: python3 tests/unit/test_a3_bucar.py
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

CHAPTER = "content/chapters/a3_bucar"
COWARDICE_FLAGS = ("infantes_fled_bucar", "captains_covered_bucar")


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


class TestA3BucarTizona(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/bucar.dialogue",
            f"{CHAPTER}/beats.json",
            "game/systems/inventory/sword_item.gd",
            "data/items/tizona.json",
            "data/honor_events/bucar.json",
            "data/characters/bucar.json",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
            "content/art/characters/dummy/dummy.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertTrue((ROOT / "content/chapters/a3_leon/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_despedida/world.tscn").is_file())

    def test_scene_is_cheap_greybox_shore(self) -> None:
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
        self.assertGreaterEqual(scene.count('[node name="Palm'), 6)
        self.assertIn("cone = true", scene)
        for node in (
            "Water",
            "Shore",
            "Wall",
            "BattleZone",
            "Host",
            "Bucar",
            "Infantes",
            "Ferran",
            "Diego",
            "Mesnada",
            "Cid",
            "Horse",
            "PlaceName",
        ):
            self.assertIn(f'[node name="{node}"', scene, node)
        self.assertIn('character_id = &"bucar"', scene)
        self.assertIn('character_id = &"ferran_gonzalez"', scene)
        self.assertIn('character_id = &"diego_gonzalez"', scene)
        ferran_block = scene[scene.find('[node name="Ferran"') : scene.find('[node name="Diego"')]
        diego_block = scene[scene.find('[node name="Diego"') : scene.find('[node name="Host"')]
        bucar_block = scene[scene.find('[node name="Bucar"') : scene.find('[node name="Dummy1"')]
        self.assertIn("spectator = true", ferran_block)
        self.assertIn("spectator = true", diego_block)
        self.assertNotIn("spectator = true", bucar_block)
        self.assertIn("CavalryCharge", _read("content/art/characters/horse/horse.tscn"))
        self.assertIn("NavigationRegion3D", scene)
        self.assertNotIn('[node name="RestZone"', scene)
        self.assertNotIn('[node name="StormZone"', scene)
        self.assertNotIn('[node name="ChargeZone"', scene)
        self.assertNotIn("GPUParticles3D", scene)
        battle_at = scene.find('[node name="BattleZone"')
        self.assertGreaterEqual(battle_at, 0)
        self.assertIn("collision_mask = 130", scene[battle_at : battle_at + 280])

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
        battle_size = _subresource_size(scene, "Box_battle")
        battle = _origin(scene, "BattleZone")
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, battle_min, battle_max),
            f"BattleZone {battle} size {battle_size} overlaps Cid spawn {cid}",
        )
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, battle_min, battle_max),
            f"BattleZone overlaps Horse spawn {horse}",
        )
        self.assertGreater(abs(cid[2] - battle[2]), battle_size[2] / 2.0 + cid_radius)

    def test_world_script_battle_flee_cover_win(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func start_battle", source)
        self.assertIn("func run_battle", source)
        self.assertIn("func start_flee", source)
        self.assertIn("func start_cover", source)
        self.assertIn("func run_win", source)
        self.assertIn("func start_win", source)
        self.assertIn('await _walk_lines(resource, "win")', source)
        self.assertIn("last_dialogue_speakers", source)
        self.assertIn("PROCESS_MODE_DISABLED", source)
        self.assertIn('set_order(&"hold")', source)
        self.assertIn("bucar_win", source)
        self.assertIn("SwordItem", source)
        self.assertIn("Phase.IN_HAND", source)
        self.assertIn("infantes_fled_bucar", source)
        self.assertIn("captains_covered_bucar", source)
        self.assertIn("a3_despedida", source)
        self.assertIn("hub_lock_cardena", source)
        self.assertIn("horse_companion", source)
        self.assertIn("can_travel", source)
        self.assertIn("autosave", source)
        self.assertIn("current_scene != self", source)
        self.assertIn("func _ready", source)
        self.assertIn("lanza_body_limit", source)
        self.assertIn("bucar", source)
        self.assertIn("MesnadaMember.from_id", source)
        self.assertIn("goto", source)
        self.assertIn("ResourceLoader.exists", source)
        self.assertIn("_protect_infantes", source)
        self.assertIn("spectator", source)
        finish = source.split("func _finish_win", 1)[1].split("func try_travel", 1)[0]
        self.assertLess(finish.find("start_flee"), finish.find("_won = true"))
        self.assertNotIn("if _fled or _won", source)
        self.assertNotIn("if _covered or _won", source)
        leave = source.split("func _leave_for_despedida", 1)[1].split("func _dest_ready", 1)[0]
        self.assertIn("not _dest_ready() or not _travel", leave)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn('apply_id(&"tizona")', source)
        self.assertNotIn('apply_id("tizona")', source)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a3_bucar/world.tscn", runner)
        self.assertIn('&"a3_bucar"', runner)
        leon = _read("content/chapters/a3_leon/world.gd")
        self.assertIn("BUCAR_SCENE", leon)
        self.assertIn("goto", leon)
        self.assertIn("current_scene != self", leon)

    def test_sword_item_is_plot_not_loot(self) -> None:
        source = _read("game/systems/inventory/sword_item.gd")
        self.assertRegex(source, re.compile(r"^class_name SwordItem$", re.MULTILINE))
        tizona = json.loads(_read("data/items/tizona.json"))
        self.assertEqual(tizona["id"], "tizona")
        self.assertEqual(tizona["kind"], "plot_sword")
        self.assertEqual(tizona["acquired_beat"], "a3_bucar")
        self.assertFalse(tizona["lootable"])
        self.assertFalse(tizona["sellable"])
        self.assertEqual(tizona["wielded_in_lists_by"], "pero_bermudez")
        core = json.loads(_read("data/honor_events/core.json"))
        events = {row["id"]: row for row in core["events"]}
        self.assertNotIn("tizona", events)
        payload = json.loads(_read("data/honor_events/bucar.json"))
        bucar_events = {row["id"]: row for row in payload["events"]}
        self.assertNotIn("tizona", bucar_events)
        win = bucar_events["bucar_win"]
        self.assertEqual(win["deltas"]["honor"], 12)
        self.assertIn("battle", win["tags"])
        self.assertEqual(win["beat"], "a3_bucar")
        self.assertFalse(win.get("hard_fail", False))
        self.assertNotIn("tizona", json.dumps(win))

    def test_bucar_json_taifa_king(self) -> None:
        bucar = json.loads(_read("data/characters/bucar.json"))
        self.assertEqual(bucar["id"], "bucar")
        self.assertEqual(bucar["display_name_key"], "char.bucar")
        self.assertEqual(bucar["role"], "taifa_king")
        self.assertEqual(bucar["combat"], 68)
        self.assertFalse(bucar["unkillable"])
        self.assertEqual(bucar["recruitable_beat"], "a3_bucar")

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a3_bucar.battle",
            "a3_bucar.flee",
            "a3_bucar.cover",
            "a3_bucar.win",
            "a3_bucar.tizona_kept",
            "char.bucar",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("Búcar", rows["a3_bucar.battle"]["es"])
        self.assertIn("playa", rows["a3_bucar.battle"]["es"].lower())
        self.assertIn("huyen", rows["a3_bucar.flee"]["es"].lower())
        self.assertIn("capitanes", rows["a3_bucar.cover"]["es"].lower())
        self.assertIn("Tizona", rows["a3_bucar.tizona_kept"]["es"])
        self.assertIn("botín", rows["a3_bucar.tizona_kept"]["es"].lower())
        self.assertIn("Búcar", rows["char.bucar"]["es"])
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a3_bucar.place_name,Playa de Valencia,", poem)

    def test_dialogue_flee_cover_tizona(self) -> None:
        text = _read(f"{CHAPTER}/bucar.dialogue")
        self.assertIn("~ battle", text)
        self.assertIn("~ flee", text)
        self.assertIn("~ cover", text)
        self.assertIn("~ win", text)
        self.assertIn("Cid:", text)
        self.assertIn("Alvar:", text)
        self.assertIn("Pero:", text)
        self.assertIn("a3_bucar.flee", text)
        self.assertIn("a3_bucar.cover", text)
        self.assertIn("a3_bucar.tizona_kept", text)
        self.assertNotIn("{{", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)
        self.assertNotIn("honor_event=tizona", text)

    def test_beats_then_despedida(self) -> None:
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a3_bucar")
        nexts = [step.get("next") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("a3_despedida", nexts)
        self.assertNotIn("a3_corpes", nexts)
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("cinematic", types)
        self.assertIn("honor_event", types)
        self.assertIn("travel_spawn", types)
        ids = [step.get("id") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("bucar_win", ids)
        self.assertNotIn("tizona", ids)
        flags = []
        for step in payload["steps"]:
            if isinstance(step, dict):
                flags.extend(step.get("set_flags", []))
        for flag in COWARDICE_FLAGS:
            self.assertIn(flag, flags, flag)

    def test_graph_cannot_skip_bucar_or_leon(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a3_leon", "a3_bucar"), pairs)
        self.assertIn(("a3_bucar", "a3_despedida"), pairs)
        self.assertNotIn(("a3_leon", "a3_despedida"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertFalse(can_travel(graph, "a3_leon", "a3_bucar", locked))
        self.assertTrue(
            can_travel(graph, "a3_leon", "a3_bucar", locked + ["lion_returned"])
        )
        self.assertFalse(can_travel(graph, "a3_bucar", "a3_despedida", locked))
        self.assertTrue(
            can_travel(graph, "a3_bucar", "a3_despedida", locked + ["tizona_acquired"])
        )
        self.assertFalse(can_travel(graph, "a3_leon", "a3_despedida", locked + ["lion_returned"]))
        self.assertFalse(can_travel(graph, "a2_bodas", "a3_bucar", locked))
        bucar_out = next(
            edge
            for edge in graph["edges"]
            if edge["from"] == "a3_bucar" and edge["to"] == "a3_despedida"
        )
        self.assertEqual(bucar_out.get("set_flags"), ["tizona_acquired"])
        self.assertEqual(bucar_out.get("req_flags"), ["tizona_acquired"])
        node = next(n for n in graph["nodes"] if n["id"] == "a3_bucar")
        self.assertEqual(node["scene"], "res://content/chapters/a3_bucar/world.tscn")

    def test_ci_keeps_leon_and_runs_bucar_after_import(self) -> None:
        workflow = _read(".github/workflows/import-and-test.yml")
        self.assertIn("Run Python a3_leon tests", workflow)
        self.assertIn("Run Python a3_bucar tests", workflow)
        self.assertIn("Run Python a3_despedida tests", workflow)
        self.assertIn("tests/unit/test_a3_leon.py", workflow)
        self.assertIn("tests/unit/test_a3_bucar.py", workflow)
        self.assertIn("tests/unit/test_a3_despedida.py", workflow)
        self.assertIn("Run a3_leon lion scene headless test", workflow)
        self.assertIn("Run a3_bucar shore/Tizona headless test", workflow)
        self.assertIn("Run a3_despedida departure/Avengalvón headless test", workflow)
        self.assertIn("res://tests/unit/test_a3_leon.gd", workflow)
        self.assertIn("res://tests/unit/test_a3_bucar.gd", workflow)
        self.assertIn("res://tests/unit/test_a3_despedida.gd", workflow)
        leon_py = workflow.find("Run Python a3_leon tests")
        bucar_py = workflow.find("Run Python a3_bucar tests")
        despedida_py = workflow.find("Run Python a3_despedida tests")
        imported = workflow.find("Import project")
        leon_gd = workflow.find("res://tests/unit/test_a3_leon.gd")
        bucar_gd = workflow.find("res://tests/unit/test_a3_bucar.gd")
        despedida_gd = workflow.find("res://tests/unit/test_a3_despedida.gd")
        self.assertLess(leon_py, bucar_py)
        self.assertLess(bucar_py, despedida_py)
        self.assertLess(imported, leon_gd)
        self.assertLess(imported, bucar_gd)
        self.assertLess(imported, despedida_gd)

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/bucar.dialogue",
            f"{CHAPTER}/beats.json",
            "game/systems/inventory/sword_item.gd",
            "data/items/tizona.json",
            "data/honor_events/bucar.json",
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
                "res://tests/unit/test_a3_bucar.gd",
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
