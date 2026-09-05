#!/usr/bin/env python3
"""Structural tests for a3_valencia_wait."""

from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestValenciaWait(unittest.TestCase):
    def test_files(self) -> None:
        for rel in (
            "content/chapters/a3_valencia_wait/world.tscn",
            "content/chapters/a3_valencia_wait/world.gd",
            "content/chapters/a3_valencia_wait/beats.json",
            "content/chapters/a3_valencia_wait/wait.dialogue",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_clock_and_travel(self) -> None:
        source = _read("content/chapters/a3_valencia_wait/world.gd")
        self.assertIn("lists_wait", source)
        self.assertIn("21", source)
        self.assertIn("advance_calendar", source)
        self.assertIn("Jimena", source)
        self.assertIn("JimenaZone", source)
        self.assertIn("wait.dialogue", source)
        self.assertIn("a3_carrion", source)
        scene = _read("content/chapters/a3_valencia_wait/world.tscn")
        self.assertIn("jimena.gd", scene)
        self.assertIn('[node name="JimenaZone"', scene)
        self.assertIn("autosave", source)
        self.assertIn("current_scene != self", source)
        self.assertNotIn("puy", source.lower())
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a3_valencia_wait.place_name,Valencia,", poem)


if __name__ == "__main__":
    unittest.main()
