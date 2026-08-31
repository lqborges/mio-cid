#!/usr/bin/env python3
"""Structural tests for PR-20 horse companion.

Run: python3 tests/unit/test_horse_companion.py
"""

from __future__ import annotations

import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DENY = ("puy", "babieca", "santa_gadea", "espadero", "stornetta", "flute")
HORSE_FILES = (
    "game/actors/player/horse_companion.gd",
    "game/combat/cavalry_charge.gd",
    "content/art/characters/horse/horse.tscn",
    "data/combat/horse.json",
    "data/schema/horse.json",
    "content/locales/strings.csv",
)


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _load_json(rel: str) -> dict:
    return json.loads(_read(rel))


class TestHorseCompanion(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in HORSE_FILES:
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_class_names_and_no_autoload_horse(self) -> None:
        self.assertRegex(
            _read("game/actors/player/horse_companion.gd"),
            re.compile(r"^class_name HorseCompanion$", re.MULTILINE),
        )
        self.assertRegex(
            _read("game/combat/cavalry_charge.gd"),
            re.compile(r"^class_name CavalryCharge$", re.MULTILINE),
        )
        self.assertRegex(
            _read("game/actors/player/horse_companion.gd"),
            re.compile(r"^extends CharacterBody3D$", re.MULTILINE),
        )
        project = _read("project.godot")
        self.assertNotIn("HorseCompanion=", project)
        self.assertNotIn("CavalryCharge=", project)
        self.assertIn('3d_physics/layer_4="lance_wedge"', project)
        self.assertIn('3d_physics/layer_8="horse"', project)
        for autoload in (ROOT / "game" / "autoload").glob("*.gd"):
            source = autoload.read_text(encoding="utf-8")
            self.assertIsNone(
                re.search(r"^class_name\s", source, re.MULTILINE),
                autoload.name,
            )

    def test_flag_horse_companion_on(self) -> None:
        source = _read("game/autoload/game_state.gd")
        self.assertIn('HORSE_COMPANION_FLAG := "horse_companion"', source)
        self.assertIn("packed.append(HORSE_COMPANION_FLAG)", source)
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        self.assertIsNone(re.search(r"^var ", source, re.MULTILINE))
        self.assertRegex(source, re.compile(r"^extends Node", re.MULTILINE))
        chapter = _read("game/autoload/chapter_runner.gd")
        self.assertEqual(
            [line.strip() for line in chapter.splitlines() if line.strip() and not line.strip().startswith("#")],
            ["extends Node"],
        )

    def test_gaits_and_mount_api(self) -> None:
        source = _read("game/actors/player/horse_companion.gd")
        for method in (
            "func gait_for_speed(",
            "func current_gait(",
            "func mount(",
            "func dismount(",
            "func follow_wish(",
            "func panic(",
            "func couch(",
            "func is_mounted(",
            "func feature_enabled(",
            "func try_gallop(",
            "func set_facing(",
            "func interact_prompt_key(",
        ):
            self.assertIn(method, source)
        self.assertIn('&"walk"', source)
        self.assertIn('&"trot"', source)
        self.assertIn('&"gallop"', source)
        self.assertIn("follow_distance", source)
        self.assertIn("LAYER_HORSE := 128", source)
        self.assertIn("process_physics_priority = -1", source)
        self.assertNotIn("process_priority = -1", source)
        self.assertIn("hold", source.lower())
        self.assertIn("Visual", source)
        scene = _read("content/art/characters/horse/horse.tscn")
        self.assertIn("process_physics_priority = -1", scene)
        controller = _read("game/actors/player/cid_controller.gd")
        self.assertIn("func is_mounted(", controller)
        self.assertIn("_consume_mounted_queues", controller)
        self.assertIn("Horse owns XZ", controller)
        self.assertIn("_lock_isometric_camera", controller)
        self.assertNotIn("SpringArm3D", controller)
        self.assertNotIn("MOUSE_MODE_CAPTURED", controller)

    def test_cavalry_charge_uses_lance_wedge(self) -> None:
        source = _read("game/combat/cavalry_charge.gd")
        self.assertIn("LAYER_LANCE_WEDGE := 8", source)
        self.assertIn("func couch(", source)
        self.assertIn("func panic_for(", source)
        self.assertIn("func dismount_hook(", source)
        self.assertIn('&"lance_couch"', source)
        self.assertIn('&"shout"', source)
        self.assertIn('&"fire"', source)
        hit = _read("game/combat/hit_box.gd")
        self.assertIn("LAYER_LANCE_WEDGE := 8", hit)
        self.assertIn("LAYER_HORSE := 128", hit)
        sword = _load_json("data/combat/sword.json")
        self.assertGreater(sword["lance_couch"]["damage"], 0)
        self.assertGreater(sword["lance_couch"]["duration"], 0)

    def test_tunables_live_in_json(self) -> None:
        horse = _load_json("data/combat/horse.json")
        self.assertEqual(horse["id"], "horse")
        self.assertIn(horse["debug_id"], ("horse", "destrier"))
        self.assertEqual(horse["hp"], 80)
        self.assertLess(horse["walk_speed"], horse["trot_speed"])
        self.assertLess(horse["trot_speed"], horse["gallop_speed"])
        self.assertLess(horse["trot_min_speed"], horse["gallop_min_speed"])
        self.assertEqual(horse["straight_couch_m"], 8.0)
        self.assertEqual(horse["display_name_key"], "horse.companion")
        self.assertEqual(horse["mount_prompt_key"], "horse.mount")
        self.assertEqual(horse["dismount_prompt_key"], "horse.dismount")
        schema = _load_json("data/schema/horse.json")
        self.assertIn("walk_speed", schema["required"])
        self.assertIn("gallop_speed", schema["required"])
        gallop_desc = schema["properties"]["gallop_speed"].get("description", "")
        self.assertIn("canter", gallop_desc.lower())
        self.assertIn("leash", schema["properties"]["follow_distance"].get("description", "").lower())
        source = _read("game/actors/player/horse_companion.gd")
        self.assertIn("data/combat/horse.json", source)
        self.assertNotIn("walk_speed: float =", source)
        self.assertNotIn("gallop_speed: float =", source)

    def test_greybox_scene_and_cheap_arena(self) -> None:
        scene = _read("content/art/characters/horse/horse.tscn")
        self.assertIn("type=\"CharacterBody3D\"", scene)
        self.assertIn("CapsuleMesh", scene)
        self.assertIn("CapsuleShape3D", scene)
        self.assertIn("CSGBox3D", scene)
        self.assertIn("horse_companion.gd", scene)
        self.assertIn("cavalry_charge.gd", scene)
        self.assertIn('parent="Visual"', scene)
        self.assertIn("LanceHitBox", scene)
        self.assertIn("collision_layer = 128", scene)
        self.assertIn("collision_layer = 8", scene)
        self.assertNotIn("Camera3D", scene)
        self.assertNotIn("SpringArm3D", scene)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertNotIn("GPUParticles", scene)
        self.assertIn("cast_shadow = 0", scene)
        arena = _read("content/chapters/_dev/arena.tscn")
        self.assertIn("horse.tscn", arena)
        self.assertEqual(arena.count("type=\"DirectionalLight3D\""), 1)
        self.assertNotIn("OmniLight3D", arena)
        self.assertNotIn("SpotLight3D", arena)
        cid = _read("content/art/characters/cid/cid.tscn")
        self.assertIn("type=\"Camera3D\"", cid)
        self.assertIn("cid_controller.gd", cid)

    def test_spanish_loc_and_unnamed(self) -> None:
        loc = _read("content/locales/strings.csv")
        self.assertIn("horse.companion,el caballo,the horse", loc)
        self.assertIn("horse.mount,Montar,Mount", loc)
        self.assertIn("horse.dismount,Desmontar,Dismount", loc)
        loc_gd = _read("game/autoload/loc.gd")
        self.assertIn("strings.csv", loc_gd)
        self.assertIn('DEFAULT_LOCALE := "es"', loc_gd)
        horse_gd = _read("game/actors/player/horse_companion.gd")
        self.assertIn("el caballo", horse_gd)
        self.assertIn('debug_id", "horse"', horse_gd)
        self.assertIn("horse.mount", horse_gd)
        self.assertIn("horse.dismount", horse_gd)
        self.assertIn("func set_facing(", _read("game/actors/player/cid_controller.gd"))

    def test_denylist_tokens_absent(self) -> None:
        for rel in HORSE_FILES + (
            "game/actors/player/cid_controller.gd",
            "game/autoload/game_state.gd",
            "content/chapters/_dev/arena.tscn",
        ):
            lowered = _read(rel).lower()
            for token in DENY:
                self.assertNotIn(token, lowered, rel)
            lowered_name = Path(rel).name.lower()
            for token in DENY:
                self.assertNotIn(token, lowered_name, rel)

    def test_godot_headless_horse_if_available(self) -> None:
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
        deps = Path("/tmp/grok-lqborges/deps/godot-unz/Godot_v4.7.2-stable_linux.x86_64")
        if godot is None and deps.is_file():
            godot = str(deps)
        if godot is None:
            self.skipTest("Godot binary not on PATH; gdUnit4 not vendored")
        result = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "--audio-driver",
                "Dummy",
                "-s",
                "res://tests/unit/test_horse_companion.gd",
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
