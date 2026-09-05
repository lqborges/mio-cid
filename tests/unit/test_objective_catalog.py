#!/usr/bin/env python3
"""Structural tests for issue #12 objective catalog.

Run: python3 tests/unit/test_objective_catalog.py
"""

from __future__ import annotations

import csv
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestObjectiveCatalog(unittest.TestCase):
    def test_catalog_covers_opening_slice(self) -> None:
        data = json.loads(_read("data/objectives/catalog.json"))
        by_id = {row["id"]: row for row in data["objectives"]}
        self.assertEqual(by_id["vivar_talk"]["chapter"], "a1_vivar")
        self.assertIn("vivar_seen", by_id["vivar_talk"]["when_none_flags"])
        self.assertIn("vivar_seen", by_id["vivar_leave"]["when_all_flags"])
        self.assertIn("burgos_child_heard", by_id["burgos_child"]["when_none_flags"])
        self.assertIn("burgos_child_heard", by_id["burgos_inn"]["when_all_flags"])
        self.assertIn("burgos_inn_asked", by_id["burgos_camp"]["when_all_flags"])
        self.assertEqual(by_id["arcas_choose"]["lock_reason_key"], "lock.arcas_choose")
        self.assertEqual(by_id["castejon_take"]["place_key"], "location.castejon")
        self.assertIn("alcocer_occupied", by_id["alcocer_occupy"]["when_none_flags"])
        self.assertIn("jeronimo_appointed", by_id["jeronimo"]["when_none_flags"])
        self.assertIn("embassy2_done", by_id["jeronimo_yusuf"]["when_all_flags"])
        self.assertIn("avengalvon_recruited", by_id["embassy2_recruit"]["when_none_flags"])
        self.assertIn("garcia_done", by_id["toledo_garcia"]["when_none_flags"])
        self.assertIn("murviedro_roads_cut", by_id["murviedro_roads"]["when_none_flags"])
        locks = {row["id"]: row for row in data["locks"]}
        self.assertEqual(locks["cardena_closed"]["to"], "a1_cardena")
        self.assertIn("hub_lock_cardena", locks["cardena_closed"]["when_all_flags"])

    def test_schema_and_scripts_exist(self) -> None:
        for rel in (
            "data/schema/objective.json",
            "data/objectives/catalog.json",
            "data/onboarding/tips.json",
            "game/systems/objectives/objective_catalog.gd",
            "game/systems/input/input_glyphs.gd",
            "game/autoload/player_guide.gd",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        catalog = _read("game/systems/objectives/objective_catalog.gd")
        self.assertRegex(catalog, re.compile(r"^class_name ObjectiveCatalog", re.MULTILINE))
        self.assertIn("func current(", catalog)
        self.assertIn("func journal(", catalog)
        self.assertIn("func lock_reason(", catalog)
        self.assertIsNone(re.search(r"^class_name\s", _read("game/autoload/player_guide.gd"), re.MULTILINE))

    def test_strings_have_spanish_objectives(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(encoding="utf-8", newline="") as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "obj.vivar_talk.title",
            "obj.burgos_child.title",
            "obj.burgos_inn.title",
            "obj.burgos_camp.title",
            "travel.arrive",
            "obj.arcas_choose.title",
            "obj.cardena_farewell.title",
            "obj.castejon_take.title",
            "obj.alcocer_occupy.title",
            "obj.jeronimo_yusuf.title",
            "obj.embassy2_recruit.title",
            "obj.toledo_garcia.title",
            "a2_jeronimo.to_yusuf",
            "a3_carrion.shout_prompt",
            "lock.cardena_closed",
            "tip.mesura.body",
            "ui.pause.journal",
            "hud.interact_verb",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("Mesura", rows["tip.mesura.body"]["es"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
