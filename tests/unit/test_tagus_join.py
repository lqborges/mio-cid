#!/usr/bin/env python3
"""Structural tests for PR-06 chapter graph. Run: python3 tests/unit/test_tagus_join.py

gdUnit4 is not vendored yet. This runner plus tests/unit/test_tagus_join.gd
cover Tagus AND-join until gdUnit4 v6.2.1 is vendored.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from validate_graph import (  # noqa: E402
    BIBLE_ACT1,
    BIBLE_IDS,
    STAGED_PRODUCERS,
    can_travel,
    load_graph,
    load_schema,
    main as validate_main,
    validate_graph,
)

DENY = ("santa gadea", "santa_gadea", "puy du fou", "corpse-horse", "stornetta", "espadero")


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _graph() -> dict:
    return load_graph(ROOT / "data" / "chapters" / "graph.json")


class TestChapterGraph(unittest.TestCase):
    def test_validate_graph_cli_ok(self) -> None:
        self.assertEqual(validate_main([]), 0)

    def test_schema_and_bible_ids(self) -> None:
        schema = load_schema(ROOT / "data" / "schema" / "chapter_graph.json")
        self.assertEqual(schema["$id"], "mio-cid/chapter_graph")
        graph = _graph()
        errors = validate_graph(
            graph,
            schema=schema,
            root=ROOT,
            source=ROOT / "data" / "chapters" / "graph.json",
        )
        self.assertEqual(errors, [])
        ids = {node["id"] for node in graph["nodes"]}
        for beat_id in BIBLE_IDS:
            self.assertIn(beat_id, ids, beat_id)
        locked = [
            node["id"]
            for node in graph["nodes"]
            if node.get("act") == 1 and not node.get("reorderable", False)
        ]
        self.assertEqual(locked, BIBLE_ACT1)
        for node in graph["nodes"]:
            if node["id"] in BIBLE_ACT1:
                self.assertFalse(node.get("reorderable", False), node["id"])

    def test_resources_have_class_name_runner_does_not(self) -> None:
        for rel, name in (
            ("game/chapters/chapter_node.gd", "ChapterNode"),
            ("game/chapters/chapter_edge.gd", "ChapterEdge"),
            ("game/chapters/chapter_graph.gd", "ChapterGraph"),
            ("game/chapters/beat_director.gd", "BeatDirector"),
        ):
            source = _read(rel)
            self.assertRegex(source, re.compile(rf"^class_name {name}$", re.MULTILINE), rel)
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertRegex(runner, re.compile(r"^extends Node$", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", runner, re.MULTILINE))
        self.assertIn("func can_travel(", runner)
        self.assertIn("func travel(", runner)
        self.assertIn("func restore(", runner)
        self.assertIn("_emit_completed", runner)
        self.assertIn("_start_director", runner)
        graph_src = _read("game/chapters/chapter_graph.gd")
        self.assertIn("func can_travel(", graph_src)
        self.assertIn("func _is_next_locked(", graph_src)
        self.assertIn("src.reorderable", graph_src)
        edge_src = _read("game/chapters/chapter_edge.gd")
        self.assertIn("@export var forbid_flags: PackedStringArray = []", edge_src)
        director = _read("game/chapters/beat_director.gd")
        self.assertIn('"set_flags"', director)
        self.assertIn('"honor_event"', director)
        self.assertIn('"travel_spawn"', director)
        self.assertIn('_apply_flags(step.get("set_flags"', director)
        self.assertIn("step_index += 1", director)
        advance = re.search(
            r"func advance\(\) -> bool:\n(?P<body>.*?)(?=\nfunc |\Z)",
            director,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(advance)
        body = advance.group("body")
        self.assertLess(body.find("run_step"), body.find("step_index += 1"))
        self.assertIn("source_id", body)
        self.assertIn("beat_id == source_id", body)
        menu = _read("game/ui/main_menu.gd")
        self.assertIn("ChapterRunner.reset()", menu)
        save_src = _read("game/autoload/save_service.gd")
        self.assertIn("ChapterRunner.restore(", save_src)

    def test_tagus_and_join_cheated_save(self) -> None:
        graph = _graph()
        cheated = ["arcas_cheated", "embassy3_done"]
        self.assertFalse(can_travel(graph, "a2_embassy3", "a2_tagus", cheated))
        self.assertTrue(can_travel(graph, "a2_embassy3", "a2_repay_raquel", cheated))
        self.assertFalse(can_travel(graph, "a2_repay_raquel", "a2_tagus", cheated))
        repaid = cheated + ["repay_done"]
        self.assertTrue(can_travel(graph, "a2_repay_raquel", "a2_tagus", repaid))
        self.assertFalse(can_travel(graph, "a2_embassy3", "a2_tagus", repaid))

    def test_tagus_honest_path_skips_repay(self) -> None:
        graph = _graph()
        honest = ["embassy3_done"]
        self.assertTrue(can_travel(graph, "a2_embassy3", "a2_tagus", honest))
        self.assertFalse(can_travel(graph, "a2_embassy3", "a2_repay_raquel", honest))
        self.assertFalse(can_travel(graph, "a2_yusuf", "a2_repay_raquel", honest))

    def test_act_i_linear_and_poyo_cut(self) -> None:
        graph = _graph()
        self.assertTrue(can_travel(graph, "a1_vivar", "a1_burgos", ["vivar_seen"]))
        self.assertFalse(can_travel(graph, "a1_vivar", "a1_burgos", []))
        self.assertFalse(
            can_travel(graph, "a1_vivar", "a1_arcas", ["vivar_seen", "burgos_shutters_seen"])
        )
        self.assertFalse(can_travel(graph, "a1_poyo", "a1_poyo_raid", []))
        self.assertTrue(can_travel(graph, "a1_poyo_raid", "a1_poyo", []))
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a1_poyo_raid", "a1_poyo"), pairs)
        self.assertIn(("a1_cardena", "a1_navapalos"), pairs)
        cardena = next(
            edge
            for edge in graph["edges"]
            if edge["from"] == "a1_cardena" and edge["to"] == "a1_navapalos"
        )
        self.assertEqual(cardena.get("set_flags"), ["hub_lock_cardena"])

    def test_spine_and_staged_producers(self) -> None:
        graph = _graph()
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a2_bodas", "a3_leon"), pairs)
        self.assertIn(("a2_tagus", "a2_bodas"), pairs)
        self.assertIn(("a1_tevar", "a2_murviedro"), pairs)
        self.assertNotIn("v1_extra_raids", STAGED_PRODUCERS)
        broken = json.loads(json.dumps(graph))
        broken["edges"] = [
            edge
            for edge in broken["edges"]
            if not (edge.get("from") == "a2_bodas" and edge.get("to") == "a3_leon")
        ]
        errors = validate_graph(broken, root=ROOT)
        self.assertTrue(any("a2_bodas -> a3_leon" in err for err in errors), errors)

    def test_denylist_absent_from_graph(self) -> None:
        lowered = _read("data/chapters/graph.json").lower()
        for token in DENY:
            self.assertNotIn(token, lowered, token)
        for rel in (
            "game/chapters/chapter_graph.gd",
            "game/autoload/chapter_runner.gd",
            "game/chapters/beat_director.gd",
            "tools/validate_graph.py",
        ):
            text = _read(rel).lower()
            self.assertNotIn("puy du fou", text)
            self.assertNotIn("santa gadea", text)

    def test_event_bus_stubs_no_longer_include_chapter_runner(self) -> None:
        source = _read("tests/unit/test_event_bus.py")
        stubs_block = source.split("STUBS = {", 1)[1].split("}", 1)[0]
        self.assertNotIn("ChapterRunner", stubs_block)

    def test_godot_headless_tagus_join_if_available(self) -> None:
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
            self.skipTest("Godot binary not on PATH; gdUnit4 not vendored")
        result = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "--audio-driver",
                "Dummy",
                "-s",
                "res://tests/unit/test_tagus_join.gd",
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
