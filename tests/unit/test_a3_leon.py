#!/usr/bin/env python3
"""Structural tests for PR-29 a3_leon lion scene.

Run: python3 tests/unit/test_a3_leon.py
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

CHAPTER = "content/chapters/a3_leon"
HIDE_FLAGS = (
    "ferran_hid_leon",
    "diego_hid_leon",
    "infantes_hid_leon",
    "infantes_cowardice_leon",
)


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


class TestA3LeonLionScene(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/leon.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/choice_ui.tscn",
            f"{CHAPTER}/choice_ui.gd",
            "data/honor_events/core.json",
            "data/characters/ferran_gonzalez.json",
            "data/characters/diego_gonzalez.json",
            "content/art/characters/cid/cid.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertTrue((ROOT / "content/chapters/a3_bucar/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_despedida/world.tscn").is_file())

    def test_scene_is_cheap_greybox_hall(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("captain.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn("mesura_hud.tscn", scene)
        self.assertIn("choice_ui.tscn", scene)
        self.assertEqual(scene.count('type="DirectionalLight3D"'), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 8)
        for node in (
            "Hall",
            "LionCage",
            "CageGate",
            "LionProp",
            "SleepCouch",
            "HallBenchA",
            "Solar",
            "SolarBed",
            "Ferran",
            "Diego",
            "Mesnada",
            "Cid",
            "CageZone",
            "HallZone",
            "ChoiceUI",
        ):
            self.assertIn(f'[node name="{node}"', scene, node)
        self.assertIn("visible = false", scene[scene.find("CageGate") : scene.find("CageGate") + 280])
        cage_block = scene[scene.find('[node name="LionCage"') : scene.find('[node name="LionProp"')]
        self.assertIn('[node name="Door"', cage_block)
        self.assertIn("operation = 2", cage_block)
        lion_block = scene[scene.find('[node name="LionProp"') : scene.find('[node name="WallWalk"')]
        self.assertIn("CollisionShape3D", lion_block)
        self.assertNotIn("Box_appoint", scene)
        self.assertNotIn("Box_embassy", scene)
        self.assertNotIn('[node name="Jeronimo"', scene)
        self.assertNotIn("GPUParticles3D", scene)
        cage_at = scene.find('[node name="CageZone"')
        hall_at = scene.find('[node name="HallZone"')
        self.assertGreaterEqual(cage_at, 0)
        self.assertGreaterEqual(hall_at, 0)
        self.assertIn("collision_mask = 130", scene[cage_at : cage_at + 280])
        self.assertIn("collision_mask = 130", scene[hall_at : hall_at + 280])

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
        zmin, zmax = _zone_aabb(scene, "CageZone", "Box_cage")
        size = _subresource_size(scene, "Box_cage")
        origin = _origin(scene, "CageZone")
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, zmin, zmax),
            f"CageZone {origin} size {size} overlaps Cid spawn {cid}",
        )
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, zmin, zmax),
            f"CageZone overlaps Horse spawn {horse}",
        )
        self.assertAlmostEqual(origin[2], 12.0, delta=0.6)
        hall_min, hall_max = _zone_aabb(scene, "HallZone", "Box_hall")
        hall_origin = _origin(scene, "HallZone")
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, hall_min, hall_max),
            f"HallZone {hall_origin} overlaps Cid spawn {cid}",
        )
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, hall_min, hall_max),
            f"HallZone overlaps Horse spawn {horse}",
        )
        lion = _origin(scene, "LionProp")
        cage = _origin(scene, "LionCage")
        self.assertGreater(
            abs(lion[2] - cage[2]),
            2.0,
            f"escaped lion {lion} must not start inside the cage {cage}",
        )

    def test_infantes_hide_under_bench_and_solar(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        ferran = _origin(scene, "Ferran")
        bench = _origin(scene, "HallBenchA")
        diego = _origin(scene, "Diego")
        bed = _origin(scene, "SolarBed")
        self.assertLess(abs(ferran[0] - bench[0]), 0.6)
        self.assertLess(abs(ferran[2] - bench[2]), 0.6)
        self.assertLess(ferran[1], 0.4)
        ferran_block = scene[scene.find('[node name="Ferran"') : scene.find('[node name="Diego"')]
        self.assertIn("0, 1, 0, -1, 0", ferran_block)
        self.assertLess(abs(diego[0] - bed[0]), 1.2)
        self.assertLess(abs(diego[2] - bed[2]), 1.6)
        ferran_json = json.loads(_read("data/characters/ferran_gonzalez.json"))
        diego_json = json.loads(_read("data/characters/diego_gonzalez.json"))
        self.assertEqual(ferran_json["mesura_max"], 0)
        self.assertEqual(diego_json["mesura_max"], 0)

    def test_world_script_mesura_vs_rage(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        for name in (
            "func wake_cid",
            "func start_joke",
            "func run_joke",
            "func choose_mesura",
            "func choose_rage",
            "func run_mesura",
            "func run_rage",
            "func return_lion",
            "func try_kill_lion",
            "func is_cage_closed",
            "func is_lion_escaped",
            "func is_cid_asleep",
            "func on_sleep_input",
            "func _dest_ready",
        ):
            self.assertIn(name, source, name)
        self.assertIn("lion_mesura", source)
        self.assertIn("lion_rage", source)
        self.assertIn("ferran_hid_leon", source)
        self.assertIn("diego_hid_leon", source)
        self.assertIn("infantes_cowardice_leon", source)
        self.assertIn("set_holding", source)
        self.assertIn("mesura_max", source)
        self.assertIn("set_chapter_asleep", source)
        self.assertIn("panic", source)
        self.assertIn("BUCAR_SCENE", source)
        leave = source.split("func _finish_beat", 1)[1].split("func _dest_ready", 1)[0]
        self.assertIn("not _dest_ready() or not _travel", leave)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn("tizona", source.lower())
        self.assertNotIn("flute", source.lower())
        self.assertNotIn("a3_corpes", source)
        cid = _read("game/actors/player/cid_controller.gd")
        self.assertIn("chapter_asleep", cid)
        self.assertIn("_apply_sleep_pose", cid)
        self.assertIn("_notify_chapter_sleep_input", cid)

    def test_honor_events_mesura_dump_costs_honra(self) -> None:
        payload = json.loads(_read("data/honor_events/core.json"))
        events = {row["id"]: row for row in payload["events"]}
        mesura = events["lion_mesura"]
        rage = events["lion_rage"]
        self.assertEqual(mesura["beat"], "a3_leon")
        self.assertEqual(rage["beat"], "a3_leon")
        self.assertEqual(mesura["deltas"]["honra"], 8)
        self.assertEqual(rage["deltas"]["honra"], -10)
        self.assertIn("mesura", mesura["tags"])
        self.assertIn("mesura_fail", rage["tags"])
        self.assertIn("lion_returned", mesura["flags_set"])
        self.assertIn("lion_returned", rage["flags_set"])
        self.assertNotIn("onores", rage["deltas"])
        self.assertLess(rage["deltas"]["honra"], 0)

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "char.ferran_gonzalez",
            "char.diego_gonzalez",
            "a3_leon.asleep",
            "a3_leon.joke",
            "a3_leon.ferran_hide",
            "a3_leon.diego_hide",
            "a3_leon.choice_mesura",
            "a3_leon.choice_rage",
            "a3_leon.mesura_done",
            "a3_leon.rage_done",
            "a3_leon.returned",
            "a3_leon.no_kill",
            "a3_leon.no_mesura",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("mesura", rows["a3_leon.joke"]["es"].lower())
        self.assertIn("mesura_max", rows["a3_leon.no_mesura"]["es"])
        self.assertIn("banco", rows["a3_leon.ferran_hide"]["es"].lower())
        self.assertIn("solar", rows["a3_leon.diego_hide"]["es"].lower())
        self.assertIn("jaula", rows["a3_leon.returned"]["es"].lower())
        self.assertIn("honra", rows["a3_leon.rage_done"]["es"].lower())
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a3_leon.place_name,Valencia,", poem)

    def test_dialogue_joke_before_choice(self) -> None:
        text = _read(f"{CHAPTER}/leon.dialogue")
        self.assertIn("~ joke", text)
        self.assertIn("~ mesura", text)
        self.assertIn("~ rage", text)
        self.assertIn("a3_leon.joke", text)
        self.assertIn("a3_leon.ferran_hide", text)
        self.assertIn("a3_leon.diego_hide", text)
        joke_at = text.find("~ joke")
        mesura_at = text.find("~ mesura")
        self.assertLess(joke_at, mesura_at)
        self.assertNotIn("{{", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)

    def test_beats_graph_and_validate(self) -> None:
        self.assertEqual(validate_main([]), 0)
        beats = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(beats["id"], "a3_leon")
        types = [step.get("type") for step in beats["steps"] if isinstance(step, dict)]
        self.assertIn("dialogue", types)
        self.assertIn("choice", types)
        self.assertIn("blocking", types)
        self.assertNotIn("honor_event", types)
        choice = next(
            step
            for step in beats["steps"]
            if isinstance(step, dict) and step.get("id") == "mesura_or_rage"
        )
        self.assertEqual(choice.get("white"), "lion_mesura")
        self.assertEqual(choice.get("red"), "lion_rage")
        flags = []
        for step in beats["steps"]:
            if isinstance(step, dict):
                flags.extend(step.get("set_flags", []))
        for flag in HIDE_FLAGS:
            self.assertIn(flag, flags, flag)
        self.assertIn("lion_returned", flags)
        self.assertIn("lion_escaped", flags)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a2_bodas", "a3_leon"), pairs)
        self.assertIn(("a3_leon", "a3_bucar"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertTrue(can_travel(graph, "a2_bodas", "a3_leon", locked))
        self.assertFalse(can_travel(graph, "a3_leon", "a3_bucar", locked))
        self.assertTrue(
            can_travel(graph, "a3_leon", "a3_bucar", locked + ["lion_returned"])
        )
        self.assertFalse(can_travel(graph, "a2_bodas", "a3_bucar", locked))
        self.assertFalse(can_travel(graph, "a3_leon", "a3_corpes", locked + ["lion_returned"]))
        node = next(n for n in graph["nodes"] if n["id"] == "a3_leon")
        self.assertEqual(node["scene"], "res://content/chapters/a3_leon/world.tscn")
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a3_leon/world.tscn", runner)
        self.assertIn('&"a3_leon"', runner)

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/leon.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/choice_ui.gd",
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
                "res://tests/unit/test_a3_leon.gd",
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
