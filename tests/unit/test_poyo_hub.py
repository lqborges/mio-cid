#!/usr/bin/env python3
"""Structural tests for PR-18 El Poyo camp hub.

Run: python3 tests/unit/test_poyo_hub.py
"""

from __future__ import annotations

import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys_path_tools = str(ROOT / "tools")

import sys

sys.path.insert(0, sys_path_tools)

from validate_graph import can_travel, load_graph, main as validate_main  # noqa: E402

DENY = (
    "puy",
    "stornetta",
    "santa_gadea",
    "santa gadea",
    "espadero",
    "flute",
    "babieca",
    "corpse",
)


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _graph() -> dict:
    return load_graph(ROOT / "data" / "chapters" / "graph.json")


class TestPoyoCampHub(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            "content/chapters/a1_poyo/world.tscn",
            "content/chapters/a1_poyo/world.gd",
            "content/chapters/a1_poyo/beats.json",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_greybox_one_directional_light(self) -> None:
        scene = _read("content/chapters/a1_poyo/world.tscn")
        self.assertEqual(scene.count("type=\"DirectionalLight3D\""), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertNotIn("GPUParticles3D", scene)
        self.assertIn("Mesnada", scene)
        self.assertIn("mesnada_ai.gd", scene)
        self.assertIn("PoyoHill", scene)
        self.assertIn("NavigationRegion3D", scene)

    def test_beats_skip_repeatable_arrival(self) -> None:
        beats = json.loads(_read("content/chapters/a1_poyo/beats.json"))
        self.assertEqual(beats["id"], "a1_poyo")
        steps = beats["steps"]
        arrive = next(step for step in steps if step.get("id") == "arrive_name")
        self.assertEqual(arrive.get("skip_if"), ["poyo_named"])
        self.assertEqual(arrive.get("set_flags"), ["poyo_named"])
        self.assertEqual(arrive.get("type"), "cinematic")
        camp = next(step for step in steps if step.get("id") == "camp")
        self.assertEqual(camp.get("segment"), "camp_night")

    def test_runner_skip_hook_and_forbid_flags(self) -> None:
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("func can_skip_travel(", runner)
        self.assertIn("func skip_travel(", runner)
        self.assertIn("func has_flag(", runner)
        self.assertIsNone(re.search(r"^class_name\s", runner, re.MULTILINE))
        director = _read("game/chapters/beat_director.gd")
        self.assertIn("func skip_repeatable(", director)
        self.assertIn('step.get("skip_if"', director)
        graph_src = _read("game/chapters/chapter_graph.gd")
        self.assertIn("func _hub_locked(", graph_src)
        self.assertIn("hub_lock_", graph_src)
        edge = _read("game/chapters/chapter_edge.gd")
        self.assertIn("forbid_flags", edge)

    def test_graph_locks(self) -> None:
        self.assertEqual(validate_main([]), 0)
        graph = _graph()
        self.assertTrue(can_travel(graph, "a1_poyo", "a1_tevar", []))
        self.assertFalse(can_travel(graph, "a1_poyo", "a2_murviedro", []))
        self.assertFalse(can_travel(graph, "a1_poyo", "a1_cardena", ["hub_lock_cardena"]))
        self.assertFalse(can_travel(graph, "a1_arcas", "a1_cardena", ["hub_lock_cardena"]))
        self.assertTrue(can_travel(graph, "a1_arcas", "a1_cardena", []))
        self.assertFalse(can_travel(graph, "a1_poyo", "a1_poyo_raid", []))
        self.assertFalse(can_travel(graph, "a1_poyo", "a1_poyo_raid", ["poyo_named"]))
        self.assertTrue(can_travel(graph, "a1_poyo", "a1_poyo_raid", ["v1_extra_raids"]))
        arcas = next(
            edge
            for edge in graph["edges"]
            if edge["from"] == "a1_arcas" and edge["to"] == "a1_cardena"
        )
        self.assertEqual(arcas.get("forbid_flags"), ["hub_lock_cardena"])
        raid = next(
            edge
            for edge in graph["edges"]
            if edge["from"] == "a1_poyo" and edge["to"] == "a1_poyo_raid"
        )
        self.assertEqual(raid.get("req_flags"), ["v1_extra_raids"])

    def test_loc_spanish_first(self) -> None:
        csv_text = _read("content/locales/poem_formulas.csv")
        self.assertIn("a1_poyo.place_name,El Poyo del Cid,", csv_text)
        self.assertIn("a1_poyo.skip_travel,Saltar el camino,", csv_text)
        world = _read("content/chapters/a1_poyo/world.gd")
        self.assertIn('Loc', world)
        self.assertIn("a1_poyo.place_name", world)
        self.assertNotIn("The Poyo of the Cid", world)

    def test_denylist_absent(self) -> None:
        blob = "\n".join(
            _read(rel).lower()
            for rel in (
                "content/chapters/a1_poyo/world.gd",
                "content/chapters/a1_poyo/world.tscn",
                "content/chapters/a1_poyo/beats.json",
                "tests/unit/test_poyo_hub.gd",
            )
        )
        for token in DENY:
            self.assertNotIn(token, blob, token)

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
                Path("/tmp/grok-lqborges/deps/godot-unz/Godot_v4.7.2-stable_linux.x86_64"),
                Path("/tmp/grok-lqborges/deps/godot-unz/godot"),
                Path("/home/lqborges/.local/bin/godot"),
            ):
                if local.is_file():
                    godot = str(local)
                    break
        if godot is None:
            self.skipTest("Godot binary not on PATH")
        result = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "--audio-driver",
                "Dummy",
                "-s",
                "res://tests/unit/test_poyo_hub.gd",
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
