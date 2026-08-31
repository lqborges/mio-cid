#!/usr/bin/env python3
"""Structural tests for PR-12 foot melee.

Run: python3 tests/unit/test_combat.py
"""

from __future__ import annotations

import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUY_DENY = ("puy", "babieca", "santa_gadea", "espadero", "stornetta", "flute")
SFX_IDS = ("slam", "leap", "shout", "ignite", "sword")
DIFFICULTIES = ("infanzon", "mesura", "campeador")


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _load_json(rel: str) -> dict:
    return json.loads(_read(rel))


class TestCombatV1(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            "game/combat/hit_box.gd",
            "game/combat/hurt_box.gd",
            "game/combat/weapon_moveset.gd",
            "game/combat/dummy_enemy.gd",
            "game/actors/player/cid_combat.gd",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/dummy/dummy.tscn",
            "content/chapters/_dev/arena.tscn",
            "data/combat/sword.json",
            "data/combat/tunables.json",
            "data/schema/difficulty.json",
            "data/schema/weapon_moveset.json",
            "data/difficulty/infanzon.json",
            "data/difficulty/mesura.json",
            "data/difficulty/campeador.json",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_class_names_and_no_autoload_combat(self) -> None:
        self.assertRegex(_read("game/combat/hit_box.gd"), re.compile(r"^class_name HitBox$", re.MULTILINE))
        self.assertRegex(_read("game/combat/hurt_box.gd"), re.compile(r"^class_name HurtBox$", re.MULTILINE))
        self.assertRegex(
            _read("game/combat/weapon_moveset.gd"),
            re.compile(r"^class_name WeaponMoveset$", re.MULTILINE),
        )
        self.assertRegex(_read("game/actors/player/cid_combat.gd"), re.compile(r"^class_name CidCombat$", re.MULTILINE))
        project = _read("project.godot")
        self.assertNotIn("CidCombat=", project)
        self.assertNotIn("HitBox=", project)
        self.assertNotIn("AudioService=", project)
        for autoload in (ROOT / "game" / "autoload").glob("*.gd"):
            source = autoload.read_text(encoding="utf-8")
            self.assertIsNone(
                re.search(r"^class_name\s", source, re.MULTILINE),
                autoload.name,
            )

    def test_kit_slots_and_sfx_guard(self) -> None:
        source = _read("game/actors/player/cid_combat.gd")
        for method in ("func slam(", "func leap(", "func shout(", "func weapon_swap("):
            self.assertIn(method, source)
        self.assertIn('get_node_or_null("AudioService")', source)
        self.assertIn('has_method("play_sfx_id")', source)
        for sfx in SFX_IDS:
            self.assertIn('&"%s"' % sfx, source)
        self.assertNotRegex(source, re.compile(r"^func roll\b", re.MULTILINE))
        self.assertNotIn("estus", source.lower())

    def test_unkillable_and_layers_documented(self) -> None:
        hit = _read("game/combat/hit_box.gd")
        hurt = _read("game/combat/hurt_box.gd")
        combat = _read("game/actors/player/cid_combat.gd")
        self.assertIn("LAYER_STREET_MELEE := 16", hit)
        self.assertIn("LAYER_HURTBOX_KILLABLE := 4", hit)
        self.assertIn("LAYER_UNKILLABLE := 32", hurt)
        self.assertIn("LAYER_SPECTATOR := 64", hurt)
        self.assertIn("unkillable", combat)
        self.assertIn("can_hit", combat)
        self.assertIn("&\"you_fell\"", combat)
        self.assertIn("fail_copy.tscn", combat)
        self.assertIn("reload_current_scene", combat)
        project = _read("project.godot")
        self.assertIn('3d_physics/layer_1="world"', project)
        self.assertIn('3d_physics/layer_2="player"', project)
        self.assertIn('3d_physics/layer_3="hurtbox_killable"', project)
        self.assertIn('3d_physics/layer_5="street_melee"', project)
        self.assertIn('3d_physics/layer_6="unkillable"', project)
        self.assertIn('3d_physics/layer_7="spectator"', project)

    def test_moveset_is_three_hit_max(self) -> None:
        sword = _load_json("data/combat/sword.json")
        self.assertEqual(sword["max_combo"], 3)
        self.assertEqual(sword["combo"], ["slash", "thrust", "bash"])
        self.assertLessEqual(len(sword["combo"]), 3)
        self.assertIn("shield_bash", sword)
        self.assertIn("lance_couch", sword)
        self.assertIn("dismount_hook", sword)
        schema = _load_json("data/schema/weapon_moveset.json")
        self.assertEqual(schema["properties"]["max_combo"]["maximum"], 3)
        source = _read("game/combat/weapon_moveset.gd")
        self.assertIn("combo_cap", source)
        self.assertNotIn("12-hit", source)

    def test_difficulty_table(self) -> None:
        schema = _load_json("data/schema/difficulty.json")
        for key in (
            "hp_regen_camp_night",
            "hp_regen_beat_start",
            "stamina_regen",
            "incoming",
            "parry_window_ms",
            "meter_sinks",
        ):
            self.assertIn(key, schema["required"])
        rows = {name: _load_json("data/difficulty/%s.json" % name) for name in DIFFICULTIES}
        self.assertEqual(rows["infanzon"]["hp_regen_camp_night"], 8)
        self.assertEqual(rows["infanzon"]["hp_regen_beat_start"], 15)
        self.assertEqual(rows["infanzon"]["stamina_regen"], 1.4)
        self.assertEqual(rows["infanzon"]["incoming"], 0.7)
        self.assertEqual(rows["infanzon"]["parry_window_ms"], 80)
        self.assertEqual(rows["infanzon"]["meter_sinks"], 0.7)
        self.assertEqual(rows["mesura"]["hp_regen_camp_night"], 5)
        self.assertEqual(rows["mesura"]["stamina_regen"], 1.0)
        self.assertEqual(rows["mesura"]["incoming"], 1.0)
        self.assertEqual(rows["mesura"]["parry_window_ms"], 0)
        self.assertEqual(rows["campeador"]["hp_regen_camp_night"], 5)
        self.assertEqual(rows["campeador"]["hp_regen_beat_start"], 0)
        self.assertEqual(rows["campeador"]["stamina_regen"], 0.85)
        self.assertEqual(rows["campeador"]["incoming"], 1.25)
        self.assertEqual(rows["campeador"]["parry_window_ms"], -40)
        tunables = _load_json("data/combat/tunables.json")
        self.assertEqual(tunables["default_difficulty"], "mesura")
        self.assertIn("player_stamina", tunables)
        self.assertIn("player_hp", tunables)

    def test_cid_and_dummy_are_greybox_capsules(self) -> None:
        cid = _read("content/art/characters/cid/cid.tscn")
        self.assertIn("cid_combat.gd", cid)
        self.assertIn("hit_box.gd", cid)
        self.assertIn("hurt_box.gd", cid)
        self.assertIn("BoxMesh_sword", cid)
        self.assertIn("collision_layer = 16", cid)
        self.assertIn("collision_layer = 2", cid)
        self.assertIn("type=\"Camera3D\"", cid)
        self.assertNotIn("SpringArm3D", cid)
        dummy = _read("content/art/characters/dummy/dummy.tscn")
        self.assertIn("CapsuleMesh", dummy)
        self.assertIn("cast_shadow = 0", dummy)
        self.assertIn("collision_layer = 4", dummy)
        self.assertIn("hurt_box.gd", dummy)
        self.assertNotIn("GPUParticles", dummy)
        self.assertNotIn("CPUParticles", dummy)
        self.assertNotIn("OmniLight3D", dummy)

    def test_arena_has_eight_dummies_and_stays_cheap(self) -> None:
        scene = _read("content/chapters/_dev/arena.tscn")
        self.assertEqual(len(re.findall(r'\[node name="Dummy\d+"', scene)), 8)
        self.assertIn("dummy.tscn", scene)
        self.assertEqual(scene.count("type=\"DirectionalLight3D\""), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertNotIn("GPUParticles", scene)
        self.assertNotIn("CPUParticles", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("cid.tscn", scene)

    def test_filenames_are_not_denylist(self) -> None:
        for path in ROOT.rglob("*"):
            if ".git" in path.parts or "addons" in path.parts:
                continue
            lowered = path.name.lower()
            for token in PUY_DENY:
                self.assertNotIn(token, lowered, str(path))

    def test_godot_headless_combat_if_available(self) -> None:
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
                "res://tests/unit/test_combat.gd",
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
