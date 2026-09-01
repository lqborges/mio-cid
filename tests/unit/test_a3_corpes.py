#!/usr/bin/env python3
"""Structural tests for a3_corpes aftermath / PEGI packet.

Run: python3 tests/unit/test_a3_corpes.py
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

CHAPTER = "content/chapters/a3_corpes"
NEWS_FLAGS = (
    "corpes_happened",
    "corpes_news",
    "elvira_alive",
    "sol_alive",
    "felez_found_them",
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


class TestA3CorpesAftermath(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/corpes.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/warning_ui.tscn",
            f"{CHAPTER}/warning_ui.gd",
            f"{CHAPTER}/choice_ui.tscn",
            f"{CHAPTER}/choice_ui.gd",
            "docs/content-rating-corpes.md",
            ".github/PULL_REQUEST_TEMPLATE.md",
            "data/honor_events/core.json",
            "data/characters/felez_munoz.json",
            "data/characters/diego_tellez.json",
            "content/art/characters/cid/cid.tscn",
            "content/chapters/a3_despedida/world.tscn",
            "content/chapters/a3_bucar/world.tscn",
            "content/chapters/a3_leon/world.tscn",
            "content/chapters/a2_embassy2/world.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertFalse((ROOT / "content/chapters/a3_querella/world.tscn").is_file())

    def test_scene_is_cheap_greybox_hall(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("captain.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn("mesura_hud.tscn", scene)
        self.assertIn("warning_ui.tscn", scene)
        self.assertIn("choice_ui.tscn", scene)
        self.assertEqual(scene.count('type="DirectionalLight3D"'), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 8)
        self.assertIn("cone = true", scene)
        for node in (
            "Hall",
            "Table",
            "HallBench",
            "Grove",
            "Linen",
            "LeafStain",
            "Cid",
            "Horse",
            "Jimena",
            "Elvira",
            "Sol",
            "Felez",
            "DiegoTellez",
            "Mesnada",
            "ReportZone",
            "PlaceName",
            "WarningUI",
            "ChoiceUI",
        ):
            self.assertIn(f'[node name="{node}"', scene, node)
        grove_at = scene.find('[node name="Grove"')
        self.assertGreaterEqual(grove_at, 0)
        self.assertIn("visible = false", scene[grove_at : grove_at + 220])
        self.assertIn('[node name="Cloak"', scene)
        self.assertIn("NavigationRegion3D", scene)
        self.assertNotIn("GPUParticles3D", scene)
        self.assertNotIn("DummyEnemy", scene)
        self.assertNotIn("HurtBox", scene)
        report_at = scene.find('[node name="ReportZone"')
        self.assertGreaterEqual(report_at, 0)
        self.assertIn("collision_mask = 130", scene[report_at : report_at + 280])

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
        zmin, zmax = _zone_aabb(scene, "ReportZone", "Box_report")
        origin = _origin(scene, "ReportZone")
        size = _subresource_size(scene, "Box_report")
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, zmin, zmax),
            f"ReportZone {origin} size {size} overlaps Cid spawn {cid}",
        )
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, zmin, zmax),
            f"ReportZone overlaps Horse spawn {horse}",
        )
        self.assertGreater(abs(cid[2] - origin[2]), size[2] / 2.0 + cid_radius)

    def test_world_script_aftermath(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func choose_hear", source)
        self.assertIn("func choose_see", source)
        self.assertIn("func run_hear_only", source)
        self.assertIn("func run_default", source)
        self.assertIn("func start_report", source)
        self.assertIn("func choose_mesura", source)
        self.assertIn("func choose_rage", source)
        self.assertIn("corpes_news", source)
        self.assertIn("corpes_rage_dump", source)
        self.assertIn("felez_found_them", source)
        self.assertIn("elvira_alive", source)
        self.assertIn("sol_alive", source)
        self.assertIn("advance_calendar", source)
        self.assertIn("ResourceLoader.exists", source)
        self.assertIn("a3_querella", source)
        self.assertIn("hub_lock_cardena", source)
        self.assertIn("horse_companion", source)
        self.assertIn("can_travel", source)
        self.assertIn("autosave", source)
        self.assertIn("current_scene != self", source)
        self.assertIn("goto", source)
        self.assertIn("func _ready", source)
        self.assertIn("set_chapter_locked", source)
        self.assertIn("GROVE_HOLD_SEC", source)
        self.assertIn("_arm_grove_camera", source)
        self.assertIn("_hold_grove_then_cut", source)
        self.assertIn("_set_body_colliders", source)
        self.assertNotIn("set_chapter_asleep", source)
        self.assertNotIn("OptionsService", source)
        self.assertNotIn("ride_host", source)
        self.assertNotIn("func skip_fact", source)
        self.assertNotIn("func _enter_tree", source)
        leave = source.split("func _finish_beat", 1)[1].split("func _dest_ready", 1)[0]
        self.assertIn("not _dest_ready() or not _travel", leave)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a3_corpes/world.tscn", runner)
        self.assertIn('&"a3_corpes"', runner)
        despedida = _read("content/chapters/a3_despedida/world.gd")
        self.assertIn("DEST_SCENE", despedida)
        self.assertIn("goto", despedida)
        self.assertIn("current_scene != self", despedida)

    def test_honor_events(self) -> None:
        payload = json.loads(_read("data/honor_events/core.json"))
        events = {row["id"]: row for row in payload["events"]}
        news = events["corpes_news"]
        rage = events["corpes_rage_dump"]
        self.assertEqual(news["beat"], "a3_corpes")
        self.assertEqual(rage["beat"], "a3_corpes")
        self.assertEqual(news["deltas"]["honra"], -35)
        self.assertEqual(rage["deltas"]["honra"], -12)
        self.assertIn("uncurable_by_combat", news["tags"])
        self.assertEqual(news.get("stain_id"), "uncurable_by_combat")
        self.assertIn("crime_against_you", news["tags"])
        self.assertIn("mesura_fail", rage["tags"])
        self.assertNotIn("onores", news["deltas"])
        self.assertNotIn("ride_host_to_carrion", _read(f"{CHAPTER}/world.gd"))

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a3_corpes.warning",
            "a3_corpes.choice_hear",
            "a3_corpes.choice_see",
            "a3_corpes.report",
            "a3_corpes.diego_escort",
            "a3_corpes.alive",
            "a3_corpes.choice_mesura",
            "a3_corpes.choice_rage",
            "char.felez_munoz",
            "char.diego_tellez",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("crimen", rows["a3_corpes.warning"]["es"].lower())
        self.assertIn("félez", rows["a3_corpes.choice_hear"]["es"].lower())
        self.assertIn("viven", rows["a3_corpes.alive"]["es"].lower())
        self.assertIn("elvira", rows["a3_corpes.alive"]["es"].lower())
        self.assertNotIn("the name is empty", rows["a3_corpes.warning"]["es"].lower())
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a3_corpes.place_name,Valencia,", poem)

    def test_dialogue_and_beats(self) -> None:
        text = _read(f"{CHAPTER}/corpes.dialogue")
        self.assertIn("~ warning", text)
        self.assertIn("~ report", text)
        self.assertIn("~ mesura", text)
        self.assertIn("~ rage", text)
        self.assertIn("Felez:", text)
        self.assertIn("DiegoTellez:", text)
        self.assertIn("Cid:", text)
        self.assertIn("a3_corpes.report", text)
        self.assertNotIn("{{", text)
        self.assertNotIn("ride_host", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a3_corpes")
        nexts = [step.get("next") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("a3_querella", nexts)
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("cinematic", types)
        self.assertIn("dialogue", types)
        self.assertIn("honor_event", types)
        self.assertIn("travel_spawn", types)
        honor_ids = [
            step.get("id")
            for step in payload["steps"]
            if isinstance(step, dict) and step.get("type") == "honor_event"
        ]
        self.assertEqual(honor_ids, ["corpes_news"])
        flags = []
        for step in payload["steps"]:
            if isinstance(step, dict):
                flags.extend(step.get("set_flags", []))
        for flag in NEWS_FLAGS:
            self.assertIn(flag, flags, flag)

    def test_rating_packet(self) -> None:
        packet = _read("docs/content-rating-corpes.md").lower()
        self.assertIn("not depicted", packet)
        self.assertIn("hear félez", packet)
        self.assertIn("player is not there", packet)
        self.assertIn("crime", packet)
        template = _read(".github/PULL_REQUEST_TEMPLATE.md").lower()
        self.assertIn("sensitivity-reader checklist", template)
        self.assertIn("fact cannot be skipped", template)

    def test_graph_cannot_skip_to_querella_from_despedida(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a3_despedida", "a3_corpes"), pairs)
        self.assertIn(("a3_corpes", "a3_querella"), pairs)
        self.assertNotIn(("a3_despedida", "a3_querella"), pairs)
        self.assertNotIn(("a3_bucar", "a3_corpes"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertTrue(can_travel(graph, "a3_despedida", "a3_corpes", locked))
        self.assertTrue(can_travel(graph, "a3_corpes", "a3_querella", locked))
        self.assertFalse(can_travel(graph, "a3_bucar", "a3_corpes", locked + ["tizona_acquired"]))
        self.assertFalse(can_travel(graph, "a3_leon", "a3_corpes", locked + ["lion_returned"]))
        dest_out = next(
            edge
            for edge in graph["edges"]
            if edge["from"] == "a3_corpes" and edge["to"] == "a3_querella"
        )
        for flag in NEWS_FLAGS:
            self.assertIn(flag, dest_out.get("set_flags", []), flag)
        node = next(n for n in graph["nodes"] if n["id"] == "a3_corpes")
        self.assertEqual(node["scene"], "res://content/chapters/a3_corpes/world.tscn")

    def test_ci_keeps_despedida_and_runs_corpes_after_import(self) -> None:
        workflow = _read(".github/workflows/import-and-test.yml")
        self.assertIn("Run Python a3_despedida tests", workflow)
        self.assertIn("Run Python a3_corpes tests", workflow)
        self.assertIn("tests/unit/test_a3_despedida.py", workflow)
        self.assertIn("tests/unit/test_a3_corpes.py", workflow)
        self.assertIn("Run a3_despedida departure/Avengalvón headless test", workflow)
        self.assertIn("Run a3_corpes aftermath headless test", workflow)
        self.assertIn("res://tests/unit/test_a3_despedida.gd", workflow)
        self.assertIn("res://tests/unit/test_a3_corpes.gd", workflow)
        imported = workflow.find("Import project")
        self.assertLess(imported, workflow.find("res://tests/unit/test_a3_corpes.gd"))
        self.assertLess(
            workflow.find("Run Python a3_despedida tests"),
            workflow.find("Run Python a3_corpes tests"),
        )
        self.assertLess(
            workflow.find("res://tests/unit/test_a3_despedida.gd"),
            workflow.find("res://tests/unit/test_a3_corpes.gd"),
        )

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/corpes.dialogue",
            f"{CHAPTER}/beats.json",
            f"{CHAPTER}/warning_ui.gd",
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
                "res://tests/unit/test_a3_corpes.gd",
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
