#!/usr/bin/env python3
"""Structural tests for PR-08 a1_vivar prologue.

Run: python3 tests/unit/test_a1_vivar.py
"""

from __future__ import annotations

import csv
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DENY = (
    "puy",
    "stornetta",
    "santa gadea",
    "santa_gadea",
    "espadero",
    "flute",
    "babieca",
    "jura",
    "heston",
)

CHAPTER = "content/chapters/a1_vivar"


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestA1VivarPrologue(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/vivar.dialogue",
            f"{CHAPTER}/companion.gd",
            f"{CHAPTER}/gate.gd",
            "game/ui/plazo_bar.tscn",
            "game/ui/talk_balloon.tscn",
            "game/ui/pause_menu.gd",
            "content/art/characters/cid/cid.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_scene_is_cheap_greybox_solar(self) -> None:
        scene = _read(f"{CHAPTER}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("plazo_bar.tscn", scene)
        self.assertIn("type=\"DirectionalLight3D\"", scene)
        self.assertEqual(scene.count("type=\"DirectionalLight3D\""), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertIn("type=\"CSGBox3D\"", scene)
        self.assertIn("type=\"CSGCombiner3D\"", scene)
        self.assertGreaterEqual(scene.count("type=\"CSGBox3D\""), 6)
        self.assertIn("Alvar", scene)
        self.assertIn("Martin", scene)
        self.assertIn("Álvar", scene)
        self.assertIn("Martín", scene)
        self.assertNotIn("font_size = 42", scene)
        self.assertIn("font_size = 28", scene)
        self.assertNotIn("fixed_size = true", scene)
        self.assertNotIn("type=\"OmniLight3D\"", scene)
        lowered = scene.lower()
        self.assertNotIn("chest", lowered)
        self.assertNotIn("cofre", lowered)

    def test_world_script_advances_plazo_never_feeds(self) -> None:
        source = _read(f"{CHAPTER}/world.gd")
        self.assertIn("advance_plazo", source)
        self.assertIn("func leave_solar", source)
        self.assertIn("func _physics_process", source)
        self.assertIn("func run_first_names", source)
        self.assertIn("vivar_seen", source)
        scene = _read(f"{CHAPTER}/world.tscn")
        gate = scene.split('[node name="Gate"', 1)[1].split("[node name=", 1)[0]
        self.assertIn("collision_layer = 8", gate)
        self.assertIn('path="res://content/chapters/a1_vivar/gate.gd"', scene)
        self.assertIn("collision_layer = 8", _read(f"{CHAPTER}/gate.gd"))
        self.assertNotIn("camp_night(", source)
        self.assertNotIn("rest_camp(", source)
        self.assertNotIn("tick_night(", source)
        balloon = _read("game/ui/talk_balloon.gd")
        self.assertNotIn("camp_night(", balloon)

    def test_dialogue_first_names_set_flag(self) -> None:
        text = _read(f"{CHAPTER}/vivar.dialogue")
        self.assertIn("~ start", text)
        self.assertIn("Álvar", text)
        self.assertIn("Martín", text)
        self.assertIn("[#flag_set=vivar_seen]", text)
        self.assertIn("a1_vivar.call_alvar", text)
        self.assertIn("a1_vivar.call_martin", text)
        lowered = text.lower()
        for banned in DENY:
            self.assertNotIn(banned, lowered, banned)

    def test_strings_csv_spanish_first_names(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(encoding="utf-8", newline="") as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a1_vivar.call_alvar",
            "a1_vivar.alvar_here",
            "a1_vivar.call_martin",
            "a1_vivar.martin_here",
            "a1_vivar.empty_solar",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("Álvar", rows["a1_vivar.call_alvar"]["es"])
        self.assertIn("Martín", rows["a1_vivar.call_martin"]["es"])
        self.assertIn("vacío", rows["a1_vivar.alvar_here"]["es"])

    def test_hud_loc_and_pause_copy(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(encoding="utf-8", newline="") as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        self.assertEqual(rows["hud.onores"]["es"], "Honores")
        self.assertEqual(rows["hud.onores"]["en"], "Means")
        self.assertEqual(rows["hud.honor"]["es"], "Honor")
        self.assertEqual(rows["hud.honor"]["en"], "Standing")
        self.assertEqual(rows["hud.honra"]["es"], "Honra")
        self.assertEqual(rows["hud.honra"]["en"], "Name")
        self.assertEqual(rows["hud.plazo"]["es"], "Plazo")
        self.assertEqual(rows["hud.plazo"]["en"], "Term")
        self.assertTrue(rows["hud.onores.tip"]["en"].strip())
        self.assertTrue(rows["hud.plazo.tip"]["es"].strip())
        self.assertIn("WASD", rows["hud.controls_hint"]["es"])
        self.assertIn("E", rows["hud.controls_hint"]["en"])
        self.assertEqual(rows["hud.interact_hint"]["es"], "E — Hablar")
        self.assertEqual(rows["hud.leave_hint"]["es"], "E — Salir")
        self.assertEqual(rows["ui.pause.resume"]["es"], "Continuar")
        self.assertEqual(rows["ui.pause.menu"]["es"], "Menú principal")
        self.assertEqual(rows["ui.pause.quit"]["es"], "Salir")
        meters = _read("game/ui/honor_meters.gd")
        self.assertIn("Honores", meters)
        self.assertNotIn('"onores": "onores"', meters)
        self.assertIn("MOUSE_FILTER_STOP", meters)
        self.assertIn("hud_click_sink", meters)
        self.assertIn("func _gui_input", meters)
        self.assertIn("MOUSE_FILTER_STOP", _read("game/ui/plazo_bar.gd"))
        self.assertIn("hud_click_sink", _read("game/ui/plazo_bar.gd"))
        plazo = _read("game/ui/plazo_bar.gd")
        ready, gui = plazo.split("func _gui_input", 1)
        self.assertIn("set_process", ready)
        self.assertIn("beat_completed", ready)
        self.assertNotIn("beat_completed.connect", gui.split("func _process", 1)[0])
        balloon = _read("game/ui/talk_balloon.gd")
        self.assertIn("func _input", balloon)
        self.assertIn("func _try_advance", balloon)
        self.assertIn("func _on_panel_gui_input", balloon)
        self.assertIn("PauseMenu", _read("project.godot"))
        self.assertIn("PlayerGuide", _read("project.godot"))
        self.assertIn("func open", _read("game/ui/pause_menu.gd"))
        self.assertIn("ui_cancel", _read("game/ui/pause_menu.gd"))
        self.assertIn("func _input", _read("game/ui/pause_menu.gd"))

    def test_nueva_partida_loads_vivar(self) -> None:
        menu = _read("game/ui/main_menu.gd")
        self.assertIn("res://content/chapters/a1_vivar/world.tscn", menu)
        self.assertIn("Nueva partida", _read("game/ui/main_menu.tscn"))
        self.assertIn("ChapterRunner.goto", menu)
        self.assertNotIn("_overwrite_armed", menu)
        self.assertIn("_first_empty_slot", menu)
        self.assertIn("_enter_game", menu)
        project = _read("project.godot")
        self.assertIn('run/main_scene="res://game/ui/main_menu.tscn"', project)
        self.assertIn("viewport_width=1280", project)
        self.assertIn("viewport_height=720", project)
        self.assertIn('renderer/rendering_method="gl_compatibility"', project)

    def test_chapter_runner_owns_flags(self) -> None:
        source = _read("game/autoload/chapter_runner.gd")
        self.assertRegex(source, re.compile(r"^extends Node", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        self.assertIn("var current_id: StringName", source)
        self.assertIn("var flags: PackedStringArray", source)
        self.assertIn("func set_flag(flag_id: StringName)", source)
        self.assertIn("func goto(beat_id: StringName)", source)
        goto = source.split("func goto(beat_id: StringName)", 1)[1].split("func _scene_path", 1)[0]
        self.assertIn("call_deferred", goto)
        self.assertIn("change_scene_to_file", goto)
        self.assertIn("_pending_scene", goto)
        self.assertIn("queued_scene_changes", goto)
        self.assertIn("_clear_pending_scene", goto)
        self.assertNotIn("camp_night(", source)
        phys = _read(f"{CHAPTER}/world.gd").split("func _physics_process", 1)[1].split(
            "func _travel_to_burgos", 1
        )[0]
        self.assertIn("if _left:", phys)
        self.assertNotIn("_travel_to_burgos()", phys)
        self.assertNotIn("ChapterRunner.goto", phys)

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{CHAPTER}/world.gd",
            f"{CHAPTER}/world.tscn",
            f"{CHAPTER}/vivar.dialogue",
            f"{CHAPTER}/companion.gd",
            f"{CHAPTER}/gate.gd",
            "game/ui/talk_balloon.gd",
            "game/autoload/chapter_runner.gd",
        ):
            lowered = _read(rel).lower()
            for token in DENY:
                self.assertNotIn(token, lowered, f"{rel} has {token}")

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
            local = Path("/home/lqborges/.local/bin/godot")
            if local.is_file():
                godot = str(local)
        if godot is None:
            self.skipTest("Godot binary not on PATH")
        if not (ROOT / ".godot").is_dir():
            self.skipTest("Godot import cache missing")
        result = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "-s",
                "res://tests/unit/test_a1_vivar.gd",
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

    def test_godot_early_game_travel_if_available(self) -> None:
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
            self.skipTest("Godot binary not on PATH")
        if not (ROOT / ".godot").is_dir():
            self.skipTest("Godot import cache missing")
        self.assertTrue((ROOT / "tests/unit/test_early_game_travel.gd").is_file())
        result = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "-s",
                "res://tests/unit/test_early_game_travel.gd",
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        combined = result.stdout + "\n" + result.stderr
        self.assertEqual(result.returncode, 0, combined)
        self.assertNotIn("Cannot convert argument", combined)


if __name__ == "__main__":
    unittest.main(verbosity=2)
