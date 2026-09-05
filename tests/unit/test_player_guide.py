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
        self.assertIn("var _hud_panel: Control", guide)
        self.assertIn("_hud_panel.visible = true", guide)
        self.assertIn("func journal_entries(", guide)
        self.assertIn("func replay_tips(", guide)
        self.assertIn("func format_interact_prompt(", guide)
        self.assertIn("func announce_travel(", guide)
        self.assertIn("func place_title(", guide)
        self.assertIn("func _update_controls_hint(", guide)
        self.assertIn("ControlsHint", guide)
        self.assertNotIn("ObjectiveCatalog", guide)
        self.assertIn("var catalog: Variant", guide)
        self.assertNotIn("InputGlyphs.", guide)
        self.assertIn('preload("res://game/systems/objectives/objective_catalog.gd")', guide)
        self.assertIn('preload("res://game/systems/input/input_glyphs.gd")', guide)
        self.assertIn("TravelCard", guide)
        self.assertIn("data/travel/places.json", guide)
        self.assertIn('_is_main_menu() and _travel_dest.is_empty()', guide)
        tips = _read("data/onboarding/tips.json")
        self.assertIn('"id": "burgos"', tips)
        self.assertIn('"chapters": ["a1_vivar"]', tips)
        self.assertIn('"locale": "es"', guide)
        self.assertIn("_apply_locale()", guide)
        pause = _read("game/ui/pause_menu.gd")
        self.assertNotIn("InputGlyphs.", pause)
        self.assertIn('preload("res://game/systems/input/input_glyphs.gd")', pause)
        self.assertIn('_make_button("Resume"', pause)
        self.assertIn('_make_button("Menu"', pause)
        self.assertIn('_make_button("Quit"', pause)
        self.assertIn('_make_button("Journal"', pause)
        self.assertIn('_make_button("Help"', pause)
        self.assertIn('_make_button("Settings"', pause)
        self.assertIn("grab_focus", pause)
        self.assertIn("_clear_action_queues", pause)
        self.assertIn("reduced_motion", pause)
        self.assertIn("NOTIFICATION_WM_GO_BACK_REQUEST", pause)
        self.assertIn("config/quit_on_go_back=false", project)
        hud = _read("content/ui/touch_hud.tscn")
        self.assertIn('name="Pause"', hud)
        self.assertIn("Pausa", hud)
        self.assertIn('_wire_pause()', _read("game/ui/touch_hud.gd"))
        self.assertIn('_language_button', pause)
        self.assertIn("ui.settings.language", _read("content/locales/strings.csv"))
        locales = _read("content/locales/strings.csv")
        self.assertIn("ui.menu.new", locales)
        self.assertIn("hud.controls_hint", locales)
        self.assertIn("hud.plazo", locales)
        self.assertIn("WASD walk · E talk", locales)
        self.assertIn("Press E to talk", locales)
        self.assertIn('name="Language"', _read("game/ui/main_menu.tscn"))
        self.assertIn("Nueva partida", _read("game/ui/main_menu.tscn"))
        playable = _read("PLAYABLE.md")
        self.assertIn("godot --headless --path . --import", playable)
        self.assertIn("global_script_class_cache.cfg", playable)

    def test_controller_uses_glyphs_and_target(self) -> None:
        source = _read("game/actors/player/cid_controller.gd")
        self.assertIn('preload("res://game/systems/input/input_glyphs.gd")', source)
        self.assertIn("Glyphs.note_event", source)
        self.assertNotIn("InputGlyphs.", source)
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
