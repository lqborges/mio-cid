#!/usr/bin/env python3
"""Structural tests for a3_toledo Cortes de Toledo.

Run: python3 tests/unit/test_a3_toledo.py
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

CHAPTER = "content/chapters/a3_toledo"
BETROTHAL = ("elvira_betrothed_navarre", "sol_betrothed_aragon")
ASK_IDS = ("swords", "dowry", "riepto")
ASK_EVENTS = ("toledo_ask1_swords", "toledo_ask2_dowry", "toledo_ask3_riepto")


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


class TestA3ToledoCortes(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/toledo.dialogue",
            f"{CHAPTER}/beats.json",
            "data/speech/toledo.json",
            "data/speech/garcia_preliminary.json",
            "data/speech/navarre_aragon.json",
            "data/speech/querella.json",
            "data/honor_events/core.json",
            "data/items/colada.json",
            "data/items/tizona.json",
            "data/characters/garcia_ordonez.json",
            "content/art/characters/cid/cid.tscn",
            "game/ui/speech_trial.tscn",
            "game/systems/speech/speech_trial.gd",
            "content/chapters/a3_querella/world.tscn",
            "content/chapters/a3_corpes/world.tscn",
            "content/chapters/a3_despedida/world.tscn",
            "content/chapters/a3_bucar/world.tscn",
            "content/chapters/a3_leon/world.tscn",
            "content/chapters/a2_embassy2/world.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
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
            "Alfonso",
            "GarciaOrdonez",
            "FerranGonzalez",
            "DiegoGonzalez",
            "Elvira",
            "Sol",
            "PeroBermudez",
            "MartinAntolinez",
            "Mesnada",
            "CourtZone",
            "PlaceName",
            "GarciaTrial",
            "SpeechTrial",
            "SpeechTrialUI",
        ):
            self.assertIn(f'[node name="{node}"', scene, node)
        self.assertIn("NavigationRegion3D", scene)
        self.assertNotIn("GPUParticles3D", scene)
        self.assertNotIn("DummyEnemy", scene)
        self.assertNotIn("Timer", scene)
        court_at = scene.find('[node name="CourtZone"')
        self.assertGreaterEqual(court_at, 0)
        self.assertIn("collision_mask = 130", scene[court_at : court_at + 280])

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
        zmin, zmax = _zone_aabb(scene, "CourtZone", "Box_court")
        origin = _origin(scene, "CourtZone")
        size = _subresource_size(scene, "Box_court")
        self.assertFalse(
            _aabb_overlap(cid_min, cid_max, zmin, zmax),
            f"CourtZone {origin} size {size} overlaps Cid spawn {cid}",
        )
        self.assertFalse(
            _aabb_overlap(horse_min, horse_max, zmin, zmax),
            f"CourtZone overlaps Horse spawn {horse}",
        )
        self.assertGreater(abs(cid[2] - origin[2]), size[2] / 2.0 + cid_radius)

    def test_world_script_speech_trials(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("func start_garcia", source)
        self.assertIn("func start_asks", source)
        self.assertIn("func run_garcia_legal", source)
        self.assertIn("func run_skip_to_riepto", source)
        self.assertIn("func run_draw_steel", source)
        self.assertIn("func give_swords_to_champions", source)
        self.assertIn("func play_navarre_aragon", source)
        self.assertIn("IN_COURT", source)
        self.assertIn("IN_CHAMPION_HAND", source)
        self.assertIn("GameState.sword", source)
        self.assertIn("&\"tizona\"", source)
        self.assertIn("&\"colada\"", source)
        self.assertIn("ResourceLoader.exists", source)
        self.assertIn("a3_valencia_wait", source)
        self.assertIn("can_travel", source)
        self.assertIn("autosave", source)
        self.assertIn("current_scene != self", source)
        self.assertIn("goto", source)
        self.assertIn("func _ready", source)
        self.assertIn("set_chapter_locked", source)
        self.assertIn("GarciaTrial", source)
        self.assertIn("win_threshold", source)
        self.assertNotIn("set_chapter_asleep", source)
        self.assertNotIn("OptionsService", source)
        self.assertNotIn("func _enter_tree", source)
        leave = source.split("func _finish_beat", 1)[1].split("func _dest_ready", 1)[0]
        self.assertIn("not _dest_ready() or not _travel", leave)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("TOLEDO_SCENE", runner)
        self.assertIn("res://content/chapters/a3_toledo/world.tscn", runner)
        self.assertIn('&"a3_toledo"', runner)
        self.assertIn("QUERELLA_SCENE", runner)
        self.assertIn("EMBASSY2_SCENE", runner)
        self.assertIn("LEON_SCENE", runner)
        self.assertIn("BUCAR_SCENE", runner)
        self.assertIn("DESPEDIDA_SCENE", runner)
        self.assertIn("CORPES_SCENE", runner)

    def test_garcia_is_separate_trial(self) -> None:
        garcia = json.loads(_read("data/speech/garcia_preliminary.json"))
        toledo = json.loads(_read("data/speech/toledo.json"))
        self.assertEqual(len(garcia["asks"]), 1)
        self.assertEqual(garcia["asks"][0]["id"], "garcia_preliminary")
        self.assertFalse(garcia["asks"][0]["counts_toward_win"])
        self.assertIn("win_threshold", garcia)
        self.assertNotIn("win_threshold", garcia["asks"][0])
        asks = toledo["asks"]
        self.assertEqual(len(asks), 3)
        self.assertEqual([row["id"] for row in asks], list(ASK_IDS))
        for row in asks:
            self.assertNotEqual(row["id"], "garcia_preliminary")
            self.assertTrue(row.get("counts_toward_win", True))
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("garcia_trial", source)
        self.assertIn("GarciaTrial", source)
        self.assertIn("garcia_preliminary.json", source)
        self.assertIn("toledo.json", source)
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn('[node name="GarciaTrial"', scene)
        self.assertIn('[node name="SpeechTrial"', scene)
        self.assertNotEqual(
            scene.find('[node name="GarciaTrial"'),
            scene.find('[node name="SpeechTrial"'),
        )

    def test_three_asks_poem_order(self) -> None:
        payload = json.loads(_read("data/speech/toledo.json"))
        self.assertIn("win_threshold", payload)
        self.assertGreaterEqual(float(payload["win_threshold"]), 12.0)
        asks = payload["asks"]
        self.assertEqual(len(asks), 3)
        self.assertEqual(asks[0]["id"], "swords")
        self.assertEqual(asks[1]["id"], "dowry")
        self.assertEqual(asks[2]["id"], "riepto")
        skip_found = False
        steel_found = False
        for ask in asks:
            self.assertNotIn("win_threshold", ask)
            lines = {row["id"]: row for row in ask["lines"]}
            self.assertIn("legal", lines)
            self.assertIn("ira", lines)
            legal_net = float(lines["legal"]["legal"]) - float(lines["legal"]["ira"])
            self.assertGreater(legal_net, 0.0)
            ira_net = float(lines["ira"]["legal"]) - float(lines["ira"]["ira"])
            self.assertLess(ira_net, 0.0)
            for row in ask["lines"]:
                if "skip_to_riepto" in row.get("tags", []):
                    skip_found = True
                if "draw_steel" in row.get("tags", []):
                    steel_found = True
        self.assertTrue(skip_found)
        self.assertTrue(steel_found)
        runtime = _read("game/systems/speech/speech_trial.gd")
        self.assertIn("var net := line.legal - line.ira", runtime)
        self.assertIn("third_ask_allowed = false", runtime)
        self.assertIn("steel_in_cortes", runtime)
        self.assertRegex(runtime, re.compile(r"^class_name SpeechTrial$", re.MULTILINE))
        project = _read("project.godot")
        self.assertNotIn("SpeechTrial=", project)
        self.assertIn("toledo.dialogue", project)
        self.assertIn("querella.dialogue", project)

    def test_swords_in_court_then_champion_hand(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("IN_COURT", source)
        self.assertIn("IN_CHAMPION_HAND", source)
        self.assertIn("set_phase_name", source)
        self.assertIn("pero", source.lower())
        self.assertIn("martin", source.lower())
        give = source.split("func give_swords_to_champions", 1)[1].split(
            "func play_navarre_aragon", 1
        )[0]
        self.assertIn("tizona", give)
        self.assertIn("IN_CHAMPION_HAND", give)
        self.assertIn("colada", give)
        court = source.split("func _return_swords_to_court", 1)[1].split(
            "func _set_sword_phase", 1
        )[0]
        self.assertIn("IN_COURT", court)
        colada = json.loads(_read("data/items/colada.json"))
        tizona = json.loads(_read("data/items/tizona.json"))
        self.assertEqual(colada["wielded_in_lists_by"], "martin_antolinez")
        self.assertEqual(tizona["wielded_in_lists_by"], "pero_bermudez")
        item = _read("game/systems/inventory/sword_item.gd")
        self.assertIn("IN_COURT", item)
        self.assertIn("IN_CHAMPION_HAND", item)
        self.assertIn("can_player_wield", item)

    def test_navarre_aragon_is_not_a_speech_trial(self) -> None:
        payload = json.loads(_read("data/speech/navarre_aragon.json"))
        self.assertEqual(payload["id"], "princes_ask")
        self.assertEqual(payload["type"], "cutscene_dialogue")
        self.assertFalse(payload["skill_check"])
        self.assertNotEqual(payload["type"], "speech_trial")
        self.assertNotIn("asks", payload)
        self.assertNotIn("win_threshold", payload)
        for flag in BETROTHAL:
            self.assertIn(flag, payload["set_flags"])
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("navarre_aragon.json", source)
        self.assertIn("elvira_betrothed_navarre", source)
        self.assertIn("sol_betrothed_aragon", source)
        self.assertIn("skill_check", source)
        beats = json.loads(_read(f"{CHAPTER}/beats.json"))
        types = [step.get("type") for step in beats["steps"] if isinstance(step, dict)]
        self.assertIn("cutscene_dialogue", types)

    def test_honor_events(self) -> None:
        payload = json.loads(_read("data/honor_events/core.json"))
        events = {row["id"]: row for row in payload["events"]}
        self.assertEqual(events["toledo_ask1_swords"]["deltas"]["honra"], 4)
        self.assertEqual(events["toledo_ask2_dowry"]["deltas"]["honra"], 8)
        self.assertEqual(events["toledo_ask3_riepto"]["deltas"]["honra"], 12)
        self.assertIn("joke", events["toledo_ask1_swords"]["tags"])
        self.assertIn("speech", events["toledo_ask1_swords"]["tags"])
        self.assertEqual(
            events["toledo_ask1_swords"].get("clear_stain"), "uncurable_by_combat"
        )
        self.assertIn("humiliation_them", events["toledo_ask2_dowry"]["tags"])
        for event_id in ASK_EVENTS:
            self.assertEqual(events[event_id]["beat"], "a3_toledo")

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a3_toledo.table",
            "a3_toledo.garcia_prompt",
            "a3_toledo.garcia_legal",
            "a3_toledo.ask1_prompt",
            "a3_toledo.ask1_legal",
            "a3_toledo.ask2_prompt",
            "a3_toledo.ask2_legal",
            "a3_toledo.ask3_prompt",
            "a3_toledo.ask3_legal",
            "a3_toledo.line_skip",
            "a3_toledo.line_steel",
            "a3_toledo.give_swords",
            "a3_toledo.princes",
            "a3_toledo.wait",
            "char.garcia_ordonez",
            "char.alfonso",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("colada", rows["a3_toledo.ask1_legal"]["es"].lower())
        self.assertIn("tizona", rows["a3_toledo.ask1_legal"]["es"].lower())
        self.assertIn("tres mil", rows["a3_toledo.ask2_prompt"]["es"].lower())
        self.assertIn("riepto", rows["a3_toledo.ask3_prompt"]["es"].lower())
        self.assertIn("pero", rows["a3_toledo.give_swords"]["es"].lower())
        self.assertIn("martín", rows["a3_toledo.give_swords"]["es"].lower())
        self.assertNotIn("the name is empty", rows["a3_toledo.garcia_prompt"]["es"].lower())
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a3_toledo.place_name,Toledo,", poem)

    def test_dialogue_and_beats(self) -> None:
        text = _read(f"{CHAPTER}/toledo.dialogue")
        self.assertIn("~ garcia", text)
        self.assertIn("~ swords", text)
        self.assertIn("~ dowry", text)
        self.assertIn("~ riepto", text)
        self.assertIn("~ skip_to_riepto", text)
        self.assertIn("~ draw_steel", text)
        self.assertIn("~ give_swords", text)
        self.assertIn("~ princes", text)
        self.assertIn("Cid:", text)
        self.assertIn("Alfonso:", text)
        self.assertIn("a3_toledo.garcia_prompt", text)
        self.assertNotIn("{{", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)
        payload = json.loads(_read(f"{CHAPTER}/beats.json"))
        self.assertEqual(payload["id"], "a3_toledo")
        nexts = [step.get("next") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("a3_valencia_wait", nexts)
        types = [step.get("type") for step in payload["steps"] if isinstance(step, dict)]
        self.assertIn("speech_trial", types)
        self.assertIn("honor_event", types)
        self.assertIn("travel_spawn", types)
        honor_ids = [
            step.get("id")
            for step in payload["steps"]
            if isinstance(step, dict) and step.get("type") == "honor_event"
        ]
        self.assertEqual(list(honor_ids), list(ASK_EVENTS))

    def test_graph_toledo_to_wait(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a3_querella", "a3_toledo"), pairs)
        self.assertIn(("a3_toledo", "a3_valencia_wait"), pairs)
        self.assertNotIn(("a3_querella", "a3_valencia_wait"), pairs)
        locked = ["hub_lock_cardena", "querella_filed"]
        self.assertTrue(can_travel(graph, "a3_querella", "a3_toledo", locked))
        self.assertTrue(can_travel(graph, "a3_toledo", "a3_valencia_wait", locked))
        node = next(n for n in graph["nodes"] if n["id"] == "a3_toledo")
        self.assertEqual(node["scene"], "res://content/chapters/a3_toledo/world.tscn")

    def test_ci_keeps_querella_speechtrial_and_runs_toledo_after_import(self) -> None:
        workflow = _read(".github/workflows/import-and-test.yml")
        self.assertIn("Run Python a3_corpes tests", workflow)
        self.assertIn("Run Python a3_querella tests", workflow)
        self.assertIn("Run Python a3_toledo tests", workflow)
        self.assertIn("tests/unit/test_a3_corpes.py", workflow)
        self.assertIn("tests/unit/test_a3_querella.py", workflow)
        self.assertIn("tests/unit/test_a3_toledo.py", workflow)
        self.assertIn("Run a3_corpes aftermath headless test", workflow)
        self.assertIn("Run SpeechTrial headless test", workflow)
        self.assertIn("Run a3_querella SpeechTrial headless test", workflow)
        self.assertIn("Run a3_toledo Cortes headless test", workflow)
        self.assertIn("res://tests/unit/test_a3_corpes.gd", workflow)
        self.assertIn("res://tests/unit/test_speech_trial.gd", workflow)
        self.assertIn("res://tests/unit/test_a3_querella.gd", workflow)
        self.assertIn("res://tests/unit/test_a3_toledo.gd", workflow)
        imported = workflow.find("Import project")
        self.assertLess(imported, workflow.find("res://tests/unit/test_a3_toledo.gd"))
        self.assertLess(
            workflow.find("Run Python a3_querella tests"),
            workflow.find("Run Python a3_toledo tests"),
        )
        self.assertLess(
            workflow.find("res://tests/unit/test_a3_querella.gd"),
            workflow.find("res://tests/unit/test_a3_toledo.gd"),
        )

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/toledo.dialogue",
            f"{CHAPTER}/beats.json",
            "data/speech/toledo.json",
            "data/speech/garcia_preliminary.json",
            "data/speech/navarre_aragon.json",
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
                "res://tests/unit/test_a3_toledo.gd",
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
