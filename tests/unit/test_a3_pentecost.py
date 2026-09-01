#!/usr/bin/env python3
"""Structural tests for Pentecost. No corpse on Babieca."""

from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

DENY = ("puy", "santa gadea", "santa_gadea", "blizzard")


class TestPentecost(unittest.TestCase):
    def test_files(self) -> None:
        chapter = ROOT / "content/chapters/a3_pentecost"
        self.assertTrue((chapter / "world.tscn").is_file())
        self.assertTrue((chapter / "world.gd").is_file())
        self.assertFalse((chapter / "babieca_corpse.tscn").is_file())
        self.assertFalse((ROOT / "content/art/characters/horse/babieca_corpse.tscn").is_file())

    def test_no_corpse_on_babieca(self) -> None:
        world = (ROOT / "content/chapters/a3_pentecost/world.gd").read_text(encoding="utf-8")
        scene = (ROOT / "content/chapters/a3_pentecost/world.tscn").read_text(encoding="utf-8")
        self.assertIn("play_death", world)
        self.assertIn("Credits", world)
        self.assertIn("babieca_has_corpse", world)
        self.assertNotIn("BabiecaCorpse", scene)
        self.assertNotIn("CorpseOnBabieca", scene)
        self.assertNotIn("cid_corpse", scene.lower())
        blob = (world + scene).lower()
        self.assertNotIn("corpse on babieca", blob)
        for token in DENY:
            self.assertNotIn(token, blob)
        poem = (ROOT / "content/locales/poem_formulas.csv").read_text(encoding="utf-8")
        self.assertIn("a3_pentecost.place_name,Valencia,", poem)


if __name__ == "__main__":
    unittest.main()
