#!/usr/bin/env python3
"""Structural tests for PlayerGuide + pause Help/Settings.

Run: python3 tests/unit/test_player_guide.py
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestPlayerGuide(unittest.TestCase):
    def test_autoload_and_pause_pages(self) -> None:
        project = _read("project.godot")
        self.assertIn('PlayerGuide="*res://game/autoload/player_guide.gd"', project)
        guide = _read("game/autoload/player_guide.gd")
        self.assertRegex(guide, re.compile(r"^extends CanvasLayer", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", guide, re.MULTILINE))
        self.assertIn("user://player_guide.json", guide)
        self.assertNotIn("collect_payload", guide)
        self.assertIn("func current_objective(", guide)
        self.assertIn("func journal_entries(", guide)
        self.assertIn("func replay_tips(", guide)
        self.assertIn("func format_interact_prompt(", guide)
        pause = _read("game/ui/pause_menu.gd")
        self.assertIn('_make_button("Resume"', pause)
        self.assertIn('_make_button("Menu"', pause)
        self.assertIn('_make_button("Quit"', pause)
        self.assertIn('_make_button("Journal"', pause)
        self.assertIn('_make_button("Help"', pause)
        self.assertIn('_make_button("Settings"', pause)
        self.assertIn("grab_focus", pause)
        self.assertIn("_clear_action_queues", pause)
        self.assertIn("reduced_motion", pause)

    def test_controller_uses_glyphs_and_target(self) -> None:
        source = _read("game/actors/player/cid_controller.gd")
        self.assertIn("InputGlyphs.note_event", source)
        self.assertIn("format_interact_prompt", source)
        self.assertIn("SelectedTarget", source)
        self.assertIn("_set_target_ring", source)
        self.assertIn("note_interacted", source)
        fail = _read("game/ui/fail_copy.gd")
        self.assertIn("ChapterRunner.goto", fail)
        self.assertIn("the name is empty", fail)

    def test_glyphs_cover_devices(self) -> None:
        source = _read("game/systems/input/input_glyphs.gd")
        self.assertRegex(source, re.compile(r"^class_name InputGlyphs", re.MULTILINE))
        self.assertIn("DEVICE_TOUCH", source)
        self.assertIn("DEVICE_GAMEPAD", source)
        self.assertIn("func prompt(", source)
        self.assertIn("func action_glyph(", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
