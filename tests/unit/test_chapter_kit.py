#!/usr/bin/env python3
"""Structural tests for issue #12 chapter art kits."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _load(rel: str) -> dict:
    return json.loads(_read(rel))


class TestChapterKit(unittest.TestCase):
    def test_kits_cover_opening_and_castejon(self) -> None:
        data = _load("data/art/kits.json")
        chapters = data["chapters"]
        self.assertEqual(chapters["a1_vivar"], "castile")
        self.assertEqual(chapters["a1_burgos"], "castile")
        self.assertEqual(chapters["a1_arcas"], "river")
        self.assertEqual(chapters["a1_cardena"], "cardena")
        self.assertEqual(chapters["a1_castejon"], "frontier")
        for kit_id in ("castile", "river", "cardena", "frontier", "pine", "valencia", "toledo", "corpes"):
            row = data["kits"][kit_id]
            for key in ("earth", "stone", "wood", "sky", "ambient", "sun"):
                self.assertGreaterEqual(len(row[key]), 3, kit_id + " " + key)

    def test_kit_script_does_not_add_lights(self) -> None:
        source = _read("game/systems/art/chapter_kit.gd")
        self.assertIn("class_name ChapterKit", source)
        self.assertIn("data/art/kits.json", source)
        self.assertNotIn("OmniLight3D", source)
        self.assertNotIn("SpotLight3D", source)
        self.assertNotIn("GPUParticles", source)
        self.assertIn("sdfgi_enabled = false", source)

    def test_style_sheet_and_license(self) -> None:
        sheet = _read("docs/STYLE_SHEET.md")
        self.assertIn("limestone", sheet.lower())
        self.assertIn("three-quarter", sheet.lower())
        license_doc = _read("docs/ART_LICENSE.md")
        self.assertIn("Mixamo", license_doc)
        self.assertIn("Puy du Fou", license_doc)


if __name__ == "__main__":
    unittest.main(verbosity=2)
