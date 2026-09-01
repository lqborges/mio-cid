#!/usr/bin/env python3
"""Structural tests for PR-02 isometric player controller.

Run: python3 tests/unit/test_cid_controller.py
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

INPUT_ACTIONS = (
    "move_left",
    "move_right",
    "move_forward",
    "move_back",
    "run",
    "dodge",
    "click_move",
    "interact",
    "slam",
    "pause",
    "leap",
    "shout",
    "weapon_swap",
)


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestCidController(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            "game/actors/player/cid_controller.gd",
            "game/actors/player/cid_combat.gd",
            "content/art/characters/cid/cid.tscn",
            "content/chapters/_dev/arena.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_controller_is_locked_isometric_not_tps(self) -> None:
        source = _read("game/actors/player/cid_controller.gd")
        self.assertRegex(source, re.compile(r"^class_name CidController", re.MULTILINE))
        self.assertRegex(source, re.compile(r"^extends CharacterBody3D", re.MULTILINE))
        self.assertIn("MOUSE_MODE_VISIBLE", source)
        self.assertNotIn("MOUSE_MODE_CAPTURED", source)
        self.assertIn("_lock_isometric_camera", source)
        self.assertIn("click_move", source)
        self.assertIn("_world_click_blocked", source)
        self.assertIn("_mouse_over_hud", source)
        self.assertIn("_click_move_from_hud", source)
        self.assertIn("_try_interact_node", source)
        self.assertIn("_dialogue_open", source)
        self.assertIn("_is_talk_target", source)
        self.assertIn("_point_over_hud", source)
        self.assertIn("_hud_hit_rect", source)
        self.assertIn("dodge", source)
        self.assertIn("chapter_asleep", source)
        self.assertIn("chapter_locked", source)
        self.assertIn("set_chapter_locked", source)
        self.assertIn("_apply_sleep_pose", source)
        self.assertNotRegex(source, re.compile(r"^func roll\b", re.MULTILINE))
        self.assertNotIn("SpringArm3D", source)
        self.assertNotRegex(source, re.compile(r"yaw\s*\+="))

    def test_dodge_is_short_not_souls_roll(self) -> None:
        source = _read("game/actors/player/cid_controller.gd")
        self.assertIn("dodge_duration: float = 0.14", source)
        self.assertIn("_start_dodge", source)
        self.assertNotIn("i-frame", source.lower())
        self.assertNotIn("estus", source.lower())

    def test_click_move_raycast_is_deferred_to_physics(self) -> None:
        source = _read("game/actors/player/cid_controller.gd")
        start = source.index("func _unhandled_input")
        end = source.index("\nfunc ", start + 1)
        unhandled = source[start:end]
        self.assertIn("_queued_click_pos", unhandled)
        self.assertNotIn("_ground_point_from_mouse", unhandled)
        self.assertIn("func _resolve_queued_click", source)

    def test_combat_stub_has_kit_slots(self) -> None:
        source = _read("game/actors/player/cid_combat.gd")
        self.assertRegex(source, re.compile(r"^class_name CidCombat", re.MULTILINE))
        for method in ("func slam(", "func leap(", "func shout(", "func weapon_swap("):
            self.assertIn(method, source)
        self.assertNotRegex(source, re.compile(r"^func roll\b", re.MULTILINE))

    def test_cid_scene_is_greybox_capsule_with_locked_camera(self) -> None:
        scene = _read("content/art/characters/cid/cid.tscn")
        self.assertIn("type=\"CharacterBody3D\"", scene)
        self.assertIn("CapsuleMesh", scene)
        self.assertIn("CapsuleShape3D", scene)
        self.assertIn("type=\"Camera3D\"", scene)
        self.assertIn("cid_controller.gd", scene)
        self.assertIn("cid_combat.gd", scene)
        self.assertIn("collision_layer = 2", scene)
        self.assertNotIn("SpringArm3D", scene)

    def test_arena_is_cheap_greybox(self) -> None:
        scene = _read("content/chapters/_dev/arena.tscn")
        self.assertIn("type=\"CSGBox3D\"", scene)
        self.assertIn("type=\"DirectionalLight3D\"", scene)
        self.assertEqual(scene.count("type=\"DirectionalLight3D\""), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertIn("cid.tscn", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertGreaterEqual(scene.count("type=\"CSGBox3D\""), 4)

    def test_project_boots_compatibility_16_9(self) -> None:
        text = _read("project.godot")
        self.assertIn('run/main_scene="res://game/ui/main_menu.tscn"', text)
        self.assertIn('renderer/rendering_method="gl_compatibility"', text)
        self.assertIn("GL Compatibility", text)
        self.assertNotIn("Forward Plus", text)
        self.assertIn("window/size/viewport_width=1280", text)
        self.assertIn("window/size/viewport_height=720", text)
        self.assertIn('window/stretch/aspect="keep"', text)
        self.assertIn('3d/physics_engine="Jolt Physics"', text)
        for action in INPUT_ACTIONS:
            self.assertIn("%s={" % action, text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
