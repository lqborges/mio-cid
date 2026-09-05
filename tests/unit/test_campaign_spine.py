#!/usr/bin/env python3
"""Full-campaign playability spine: enter, objective, leave.

Run: python3 tests/unit/test_campaign_spine.py
"""

from __future__ import annotations

import csv
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

STAGES = (
    "a1_vivar",
    "a1_burgos",
    "a1_arcas",
    "a1_cardena",
    "a1_navapalos",
    "a1_castejon",
    "a1_alcocer",
    "a1_embassy1",
    "a1_poyo",
    "a1_tevar",
    "a2_murviedro",
    "a2_siege",
    "a2_jeronimo",
    "a2_embassy2",
    "a2_yusuf",
    "a2_embassy3",
    "a2_repay_raquel",
    "a2_tagus",
    "a2_bodas",
    "a3_leon",
    "a3_bucar",
    "a3_despedida",
    "a3_corpes",
    "a3_querella",
    "a3_toledo",
    "a3_valencia_wait",
    "a3_carrion",
    "a3_pentecost",
)

HAPPY_EDGES = (
    ("a1_vivar", "a1_burgos", ["vivar_seen"]),
    ("a1_burgos", "a1_arcas", ["burgos_shutters_seen"]),
    ("a1_arcas", "a1_cardena", ["arcas_refused"]),
    ("a1_cardena", "a1_navapalos", []),
    ("a1_navapalos", "a1_castejon", []),
    ("a1_castejon", "a1_alcocer", []),
    ("a1_alcocer", "a1_embassy1", ["alcocer_booty_divided"]),
    ("a1_embassy1", "a1_poyo", []),
    ("a1_poyo", "a1_tevar", []),
    ("a1_tevar", "a2_murviedro", []),
    ("a2_murviedro", "a2_siege", []),
    ("a2_siege", "a2_jeronimo", []),
    ("a2_jeronimo", "a2_embassy2", []),
    ("a2_embassy2", "a2_jeronimo", []),
    ("a2_jeronimo", "a2_yusuf", ["embassy2_done"]),
    ("a2_yusuf", "a2_embassy3", []),
    ("a2_embassy3", "a2_tagus", ["embassy3_done"]),
    ("a2_embassy3", "a2_repay_raquel", ["embassy3_done", "arcas_cheated"]),
    ("a2_repay_raquel", "a2_tagus", ["repay_done"]),
    ("a2_tagus", "a2_bodas", []),
    ("a2_bodas", "a3_leon", []),
    ("a3_leon", "a3_bucar", ["lion_returned"]),
    ("a3_bucar", "a3_despedida", ["tizona_acquired"]),
    ("a3_despedida", "a3_corpes", []),
    ("a3_corpes", "a3_querella", []),
    ("a3_querella", "a3_toledo", ["querella_filed"]),
    ("a3_toledo", "a3_valencia_wait", []),
    ("a3_valencia_wait", "a3_carrion", []),
    ("a3_carrion", "a3_pentecost", []),
)


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _graph() -> dict:
    return json.loads(_read("data/chapters/graph.json"))


def _edge_open(graph: dict, frm: str, to: str, flags: list[str]) -> bool:
    have = set(flags)
    for edge in graph["edges"]:
        if edge.get("from") != frm or edge.get("to") != to:
            continue
        req = set(edge.get("req_flags") or [])
        forbid = set(edge.get("forbid_flags") or [])
        if req and not req.issubset(have):
            continue
        if forbid & have:
            continue
        return True
    return False


class TestCampaignSpine(unittest.TestCase):
    def test_every_stage_has_scene_and_runner(self) -> None:
        runner = _read("game/autoload/chapter_runner.gd")
        for stage in STAGES:
            scene = ROOT / "content" / "chapters" / stage / "world.tscn"
            self.assertTrue(scene.is_file(), scene)
            self.assertIn(f'&"{stage}"', runner, stage)

    def test_catalog_covers_every_stage(self) -> None:
        data = json.loads(_read("data/objectives/catalog.json"))
        chapters = {row["chapter"] for row in data["objectives"]}
        for stage in STAGES:
            self.assertIn(stage, chapters, stage)

    def test_happy_path_edges_open(self) -> None:
        graph = _graph()
        for frm, to, flags in HAPPY_EDGES:
            self.assertTrue(
                _edge_open(graph, frm, to, flags),
                f"{frm} -> {to} with {flags}",
            )
        self.assertFalse(
            _edge_open(graph, "a2_jeronimo", "a2_embassy2", ["embassy2_done"])
        )
        self.assertFalse(
            _edge_open(graph, "a2_embassy3", "a2_tagus", ["embassy3_done", "arcas_cheated"])
        )
        self.assertFalse(
            _edge_open(graph, "a3_querella", "a3_toledo", ["querella_filed", "ride_host"])
        )

    def test_load_resumes_saved_chapter(self) -> None:
        menu = _read("game/ui/main_menu.gd")
        self.assertIn("func _resume_chapter", menu)
        enter = menu.split("func _enter_game", 1)[1].split("func _rebuild_slots", 1)[0]
        self.assertIn("_resume_chapter", enter)
        self.assertNotIn('goto(&"a1_vivar")', enter)

    def test_jeronimo_hub_opens_yusuf_after_embassy2(self) -> None:
        source = _read("content/chapters/a2_jeronimo/world.gd")
        self.assertIn("func travel_to_yusuf", source)
        self.assertIn("func travel_next", source)
        self.assertIn("embassy2_done", source)
        rows = _strings()
        self.assertTrue(rows["a2_jeronimo.to_yusuf"]["es"].strip())
        self.assertTrue(rows["obj.jeronimo_yusuf.title"]["es"].strip())

    def test_carrion_lists_see_spectator_and_offer_shout(self) -> None:
        scene = _read("content/chapters/a3_carrion/world.tscn")
        self.assertIn("collision_mask = 194", scene)
        self.assertIn("shout_choice.tscn", scene)
        source = _read("content/chapters/a3_carrion/world.gd")
        self.assertIn("func present_shout", source)
        self.assertIn("func choose_shout", source)
        self.assertIn("present_shout()", source.split("func _on_list_entered", 1)[1])
        self.assertNotIn(
            "resolve_lists()",
            source.split("func _on_list_entered", 1)[1].split("func _hide_shout", 1)[0],
        )
        rows = _strings()
        for key in (
            "a3_carrion.shout_prompt",
            "a3_carrion.shout_silence",
            "a3_carrion.shout_once",
            "a3_carrion.shout_too_much",
        ):
            self.assertTrue(rows[key]["es"].strip(), key)

    def test_corpes_stays_off_stage(self) -> None:
        source = _read("content/chapters/a3_corpes/world.gd").lower()
        self.assertIn("hear_only", source)
        self.assertIn("warning", source)
        self.assertNotIn("robledo", source)
        self.assertNotIn("interactable corpse", source)


def _strings() -> dict:
    with (ROOT / "content/locales/strings.csv").open(encoding="utf-8", newline="") as handle:
        return {row["key"]: row for row in csv.DictReader(handle)}


if __name__ == "__main__":
    unittest.main(verbosity=2)
