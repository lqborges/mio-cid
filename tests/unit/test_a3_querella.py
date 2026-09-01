#!/usr/bin/env python3
"""Structural tests for a3_querella one-ask SpeechTrial.

Run: python3 tests/unit/test_a3_querella.py
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

CHAPTER = "content/chapters/a3_querella"
WIN_FLAGS = ("querella_filed", "querella_done")


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


class TestA3QuerellaSpeechTrial(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/querella.dialogue",
            f"{CHAPTER}/beats.json",
            "data/speech/querella.json",
            "data/honor_events/core.json",
            "data/characters/muno_gustioz.json",
            "content/art/characters/cid/cid.tscn",
            "game/ui/speech_trial.tscn",
            "game/systems/speech/speech_trial.gd",
            "content/chapters/a3_corpes/world.tscn",
            "content/chapters/a3_despedida/world.tscn",
            "content/chapters/a3_bucar/world.tscn",
            "content/chapters/a3_leon/world.tscn",
            "content/chapters/a2_embassy2/world.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertTrue((ROOT / "content/chapters/a3_toledo/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_valencia_wait/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_carrion/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a1_vivar/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a2_jeronimo/world.tscn").is_file())

    def test_scene_is_cheap_greybox_hall(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("captain.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn("mesura_hud.tscn", scene)
        self.assertIn("speech_trial.tscn", scene)
        self.assertIn("speech_trial.gd", scene)
        self.assertEqual(scene.count('type="DirectionalLight3D"'), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 8)
        for node in (
            "Hall",
            "Table",
            "HallBench",
            "Cid",
            "Horse",
            "Jimena",
            "MunoGustioz",
            "Mesnada",
            "DictateZone",
            "PlaceName",
            "SpeechTrial",
            "SpeechTrialUI",
        ):
            self.assertIn(f'[node name="{node}"', scene, node)
        self.assertIn("NavigationRegion3D", scene)
        self.assertNotIn("GPUParticles3D", scene)
        self.assertNotIn("DummyEnemy", scene)
        self.assertNotIn("Timer", scene)
        dictate_at = scene.find('[node name="DictateZone"')
        self.assertGreaterEqual(dictate_at, 0)
        self.assertIn("collision_mask = 130", scene[dictate_at : dictate_at + 280])

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
        zmin, zmax = _zone_aabb(scene, "DictateZone", "Box_dictate")
        origin = _origin(scene, "DictateZone")
        size = _subresource_size(scene, "Box_dictate")
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, zmin, zmax),
            f"DictateZone {origin} size {size} overlaps Cid spawn {cid}",
        )
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, zmin, zmax),
            f"DictateZone overlaps Horse spawn {horse}",
        )
        self.assertGreater(abs(cid[2] - origin[2]), size[2] / 2.0 + cid_radius)

    def test_world_script_speech_trial(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func start_dictate", source)
        self.assertIn("func run_legal", source)
        self.assertIn("func run_mesura", source)
        self.assertIn("func run_ride_host", source)
        self.assertIn("func run_ira", source)
        gd = _read("tests/unit/test_a3_querella.gd")
        self.assertIn("func _check_ira_does_not_commit", gd)
        self.assertIn("querella_filed", source)
        self.assertIn("ride_host_to_carrion", source)
        self.assertIn("querella_sent", source)
        self.assertIn("ResourceLoader.exists", source)
        self.assertIn("a3_toledo", source)
        self.assertIn("can_travel", source)
        self.assertIn("autosave", source)
        self.assertIn("current_scene != self", source)
        self.assertIn("goto", source)
        self.assertIn("func _ready", source)
        self.assertIn("set_chapter_locked", source)
        self.assertIn("SpeechTrial", source)
        self.assertIn("win_threshold", source)
        self.assertNotIn("set_chapter_asleep", source)
        self.assertNotIn("OptionsService", source)
        self.assertNotIn("func _enter_tree", source)
        leave = source.split("func _finish_beat", 1)[1].split("func _dest_ready", 1)[0]
        self.assertIn("not _dest_ready() or not _travel", leave)
        self.assertIn("if _host_ridden:", leave)
        host_block = leave.split("if _host_ridden:", 1)[1].split(
            "if not _dest_ready()", 1
        )[0]
        self.assertIn("return", host_block)
        self.assertNotIn("WAIT_KEY", host_block)
        submit = source.split("func _submit", 1)[1].split("func _load_querella", 1)[0]
        self.assertIn("if _filed or _host_ridden:", submit)
        travel_try = source.split("func try_travel_toledo", 1)[1].split(
            "func can_leave_to_toledo", 1
        )[0]
        self.assertIn("if not _filed or _host_ridden:", travel_try)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a3_querella/world.tscn", runner)
        self.assertIn('&"a3_querella"', runner)
        self.assertIn("EMBASSY2_SCENE", runner)
        self.assertIn("LEON_SCENE", runner)
        self.assertIn("BUCAR_SCENE", runner)
        self.assertIn("DESPEDIDA_SCENE", runner)
        self.assertIn("CORPES_SCENE", runner)
        corpes = _read("content/chapters/a3_corpes/world.gd")
        self.assertNotIn("ride_host", corpes)
        self.assertNotIn("ride_host_to_carrion", corpes)

    def test_speech_trial_one_ask(self) -> None:
        payload = json.loads(_read("data/speech/querella.json"))
        asks = payload["asks"]
        self.assertEqual(len(asks), 1)
        self.assertEqual(asks[0]["id"], "querella_dictate")
        self.assertIn("win_threshold", payload)
        self.assertNotIn("win_threshold", asks[0])
        lines = {row["id"]: row for row in asks[0]["lines"]}
        for line_id in ("legal", "mesura", "ira", "ride_host"):
            self.assertIn(line_id, lines, line_id)
        self.assertIn("legal", lines["legal"]["tags"])
        self.assertIn("mesura", lines["mesura"]["tags"])
        self.assertIn("ira", lines["ira"]["tags"])
        self.assertIn("ride_host", lines["ride_host"]["tags"])
        self.assertGreaterEqual(
            float(lines["legal"]["legal"]) - float(lines["legal"]["ira"]),
            float(payload["win_threshold"]),
        )
        self.assertGreaterEqual(
            float(lines["mesura"]["legal"]) - float(lines["mesura"]["ira"]),
            float(payload["win_threshold"]),
        )
        self.assertLess(
            float(lines["ira"]["legal"]) - float(lines["ira"]["ira"]),
            0.0,
        )
        self.assertGreaterEqual(
            float(lines["ride_host"]["legal"]) - float(lines["ride_host"]["ira"]),
            0.0,
        )
        source = _read("game/systems/speech/speech_trial.gd")
        self.assertIn("var net := line.legal - line.ira", source)
        self.assertRegex(source, re.compile(r"^class_name SpeechTrial$", re.MULTILINE))
        project = _read("project.godot")
        self.assertNotIn("SpeechTrial=", project)
        self.assertIn("querella.dialogue", project)

    def test_honor_events(self) -> None:
        payload = json.loads(_read("data/honor_events/core.json"))
        events = {row["id"]: row for row in payload["events"]}
        ride = events["ride_host_to_carrion"]
        filed = events["querella_filed"]
        self.assertEqual(ride["beat"], "a3_querella")
        self.assertEqual(filed["beat"], "a3_querella")
        self.assertEqual(ride["deltas"]["honra"], -25)
        self.assertEqual(filed["deltas"]["honra"], 6)
        self.assertIn("mesura_fail", ride["tags"])
        self.assertIn("illegal", ride["tags"])
        self.assertIn("law", filed["tags"])
        self.assertIn("ride_host", ride.get("flags_set", []))
        self.assertIn("querella_filed", filed.get("flags_set", []))
        traits = json.loads(_read("data/mesura_traits.json"))
        rows = {row["id"]: row for row in traits["traits"]}
        self.assertEqual(
            rows["querella_not_hueste"]["unlocks_at"]["honor_event"],
            "querella_filed",
        )
        bus = _read("game/autoload/event_bus.gd")
        self.assertIn("signal querella_sent", bus)

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a3_querella.prompt",
            "a3_querella.table",
            "a3_querella.line_legal",
            "a3_querella.line_mesura",
            "a3_querella.line_ira",
            "a3_querella.line_ride_host",
            "a3_querella.sent",
            "a3_querella.ride_host",
            "a3_querella.toledo_wait",
            "char.muno_gustioz",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("querella", rows["a3_querella.prompt"]["es"].lower())
        self.assertIn("muño", rows["a3_querella.prompt"]["es"].lower())
        self.assertIn("hueste", rows["a3_querella.line_legal"]["es"].lower())
        self.assertIn("carrión", rows["a3_querella.line_ride_host"]["es"].lower())
        self.assertNotIn("the name is empty", rows["a3_querella.prompt"]["es"].lower())
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a3_querella.place_name,Valencia,", poem)

    def test_dialogue_and_beats(self) -> None:
        text = _read(f"{CHAPTER}/querella.dialogue")
        self.assertIn("~ dictate", text)
        self.assertIn("~ legal", text)
        self.assertIn("~ mesura", text)
        self.assertIn("~ ira", text)
        self.assertIn("a3_querella.line_ira", text)
        self.assertIn("~ ride_host", text)
        self.assertIn("MunoGustioz:", text)
        self.assertIn("Cid:", text)
        self.assertIn("a3_querella.prompt", text)
        self.assertNotIn("{{", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a3_querella")
        nexts = [step.get("next") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("a3_toledo", nexts)
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("speech_trial", types)
        self.assertIn("honor_event", types)
        self.assertIn("travel_spawn", types)
        honor_ids = [
            step.get("id")
            for step in payload["steps"]
            if isinstance(step, dict) and step.get("type") == "honor_event"
        ]
        self.assertEqual(honor_ids, ["querella_filed"])
        flags = []
        for step in payload["steps"]:
            if isinstance(step, dict):
                flags.extend(step.get("set_flags", []))
        for flag in WIN_FLAGS:
            self.assertIn(flag, flags, flag)
        reds = [step.get("red") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("ride_host", reds)

    def test_graph_gates_toledo(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a3_corpes", "a3_querella"), pairs)
        self.assertIn(("a3_querella", "a3_toledo"), pairs)
        self.assertNotIn(("a3_corpes", "a3_toledo"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertTrue(can_travel(graph, "a3_corpes", "a3_querella", locked))
        self.assertFalse(can_travel(graph, "a3_querella", "a3_toledo", locked))
        self.assertTrue(
            can_travel(graph, "a3_querella", "a3_toledo", locked + ["querella_filed"])
        )
        self.assertFalse(
            can_travel(
                graph,
                "a3_querella",
                "a3_toledo",
                locked + ["querella_filed", "ride_host"],
            )
        )
        self.assertFalse(
            can_travel(graph, "a3_querella", "a3_toledo", locked + ["ride_host"])
        )
        dest_out = next(
            edge
            for edge in graph["edges"]
            if edge["from"] == "a3_querella" and edge["to"] == "a3_toledo"
        )
        self.assertIn("querella_filed", dest_out.get("req_flags", []))
        self.assertIn("ride_host", dest_out.get("forbid_flags", []))
        node = next(n for n in graph["nodes"] if n["id"] == "a3_querella")
        self.assertEqual(node["scene"], "res://content/chapters/a3_querella/world.tscn")

    def test_ci_keeps_corpes_speechtrial_and_runs_querella_after_import(self) -> None:
        workflow = _read(".github/workflows/import-and-test.yml")
        self.assertIn("Run Python a3_corpes tests", workflow)
        self.assertIn("Run Python a3_querella tests", workflow)
        self.assertIn("tests/unit/test_a3_corpes.py", workflow)
        self.assertIn("tests/unit/test_a3_querella.py", workflow)
        self.assertIn("Run a3_corpes aftermath headless test", workflow)
        self.assertIn("Run SpeechTrial headless test", workflow)
        self.assertIn("Run a3_querella SpeechTrial headless test", workflow)
        self.assertIn("res://tests/unit/test_a3_corpes.gd", workflow)
        self.assertIn("res://tests/unit/test_speech_trial.gd", workflow)
        self.assertIn("res://tests/unit/test_a3_querella.gd", workflow)
        imported = workflow.find("Import project")
        self.assertLess(imported, workflow.find("res://tests/unit/test_a3_querella.gd"))
        self.assertLess(
            workflow.find("Run Python a3_corpes tests"),
            workflow.find("Run Python a3_querella tests"),
        )
        self.assertLess(
            workflow.find("res://tests/unit/test_speech_trial.gd"),
            workflow.find("res://tests/unit/test_a3_querella.gd"),
        )

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/querella.dialogue",
            f"{CHAPTER}/beats.json",
            "data/speech/querella.json",
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
                "res://tests/unit/test_a3_querella.gd",
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
