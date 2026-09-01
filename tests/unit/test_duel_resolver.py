#!/usr/bin/env python3
"""Structural tests for DuelResolver and spectator lists."""

from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestDuelResolver(unittest.TestCase):
    def test_files_exist(self) -> None:
        self.assertTrue((ROOT / "game/combat/duel_resolver.gd").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_carrion/world.tscn").is_file())
        self.assertTrue((ROOT / "tests/unit/test_duel_resolver.gd").is_file())

    def test_formula_and_pick(self) -> None:
        source = _read("game/combat/duel_resolver.gd")
        self.assertIn("class_name DuelResolver", source)
        self.assertIn("&\"felez_munoz\"", source)
        self.assertIn("&\"jeronimo\"", source)
        self.assertIn("0.35", source)
        self.assertIn("0.20", source)
        self.assertIn("correct_sword", source)
        self.assertIn("shout_silence", source)
        self.assertIn("shout_too_much", source)
        self.assertIn("score >= 0.50", source)
        self.assertIn("_canonical", source)
        self.assertIn("0.45", source)
        self.assertIn("Cid is never", source)
        self.assertIn("&\"cid\"", source)
        self.assertNotIn("Blizzard", source)

    def test_spectator_chapter(self) -> None:
        world = _read("content/chapters/a3_carrion/world.gd")
        self.assertIn("set_spectator_mode", world)
        self.assertIn("HurtBox", world)
        self.assertIn("possess_pawn", world)
        self.assertIn("shout_silence", world)
        self.assertIn("name_empty", world)
        self.assertIn("lists_lose_any", world)
        self.assertIn("current_scene != self", world)
        self.assertNotRegex(world, r"^class_name\s")


if __name__ == "__main__":
    unittest.main()
