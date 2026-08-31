#!/usr/bin/env python3
"""Structural tests for PR-13 mesnada follow and wedge.

Run: python3 tests/unit/test_mesnada_ai.py
"""

from __future__ import annotations

import json
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUY_DENY = ("puy", "babieca", "santa_gadea", "espadero", "stornetta", "flute")
BLIZZARD = ("arthas", "uther", "jaina", "thrall", "sylvanas", "anduin")


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _load_json(rel: str) -> dict:
    return json.loads(_read(rel))


class TestMesnadaFollowAndWedge(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            "game/actors/mesnada/mesnada_ai.gd",
            "game/actors/mesnada/mesnada_follower.gd",
            "game/actors/mesnada/mesnada_roster.gd",
            "content/art/characters/captain/captain.tscn",
            "content/art/characters/lanza/lanza.tscn",
            "content/chapters/_dev/arena.tscn",
            "data/mesnada/follow.json",
            "data/schema/mesnada_follow.json",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_class_names_are_not_autoload(self) -> None:
        self.assertRegex(
            _read("game/actors/mesnada/mesnada_ai.gd"),
            re.compile(r"^class_name MesnadaAI$", re.MULTILINE),
        )
        self.assertRegex(
            _read("game/actors/mesnada/mesnada_follower.gd"),
            re.compile(r"^class_name MesnadaFollower$", re.MULTILINE),
        )
        project = _read("project.godot")
        self.assertNotIn("MesnadaAI=", project)
        self.assertNotIn("MesnadaFollower=", project)
        for autoload in (ROOT / "game" / "autoload").glob("*.gd"):
            source = autoload.read_text(encoding="utf-8")
            self.assertIsNone(
                re.search(r"^class_name\s", source, re.MULTILINE),
                autoload.name,
            )

    def test_follow_tunables_live_in_json(self) -> None:
        data = _load_json("data/mesnada/follow.json")
        self.assertEqual(data["skinned_cap"], 24)
        self.assertEqual(data["lod_distance"], 25)
        self.assertEqual(data["impostor_distance"], 40)
        self.assertEqual(data["visible_lanza_bodies"], 8)
        schema = _load_json("data/schema/mesnada_follow.json")
        for key in (
            "follow_distance",
            "wedge_row_depth",
            "wedge_row_width",
            "skinned_cap",
            "visible_lanza_bodies",
        ):
            self.assertIn(key, schema["required"])
        self.assertEqual(schema["properties"]["skinned_cap"]["maximum"], 24)
        source = _read("game/actors/mesnada/mesnada_ai.gd")
        self.assertIn("res://data/mesnada/follow.json", source)
        self.assertIn("wedge_local_offset", source)
        self.assertIn("ensure_navigation_plane", source)
        self.assertIn("plant_banner_at", source)
        self.assertNotIn("skinned_cap := 24", source)

    def test_lanzas_are_count_plus_cheap_bodies(self) -> None:
        ai = _read("game/actors/mesnada/mesnada_ai.gd")
        self.assertIn("lanza_count", ai)
        self.assertIn("visible_lanza_body_cap", ai)
        self.assertIn("spawn_lanza_bodies", ai)
        lanza = _read("content/art/characters/lanza/lanza.tscn")
        self.assertIn("CapsuleMesh", lanza)
        self.assertIn("radial_segments = 4", lanza)
        self.assertIn("cast_shadow = 0", lanza)
        self.assertIn("kind = &\"lanza\"", lanza)
        self.assertIn("collision_layer = 8", lanza)
        self.assertNotIn("GPUParticles", lanza)
        self.assertNotIn("OmniLight3D", lanza)
        captain = _read("content/art/characters/captain/captain.tscn")
        self.assertIn("MeshSkinned", captain)
        self.assertIn("MeshCapsule", captain)
        self.assertIn("radial_segments = 8", captain)
        self.assertIn("cast_shadow = 0", captain)
        self.assertIn("NavigationAgent3D", captain)
        self.assertIn("avoidance_enabled = false", captain)
        self.assertIn("collision_layer = 8", captain)
        self.assertIn("type=\"CharacterBody3D\"", captain)

    def test_follow_is_isometric_not_souls_lock(self) -> None:
        ai = _read("game/actors/mesnada/mesnada_ai.gd")
        follower = _read("game/actors/mesnada/mesnada_follower.gd")
        self.assertIn("leader_facing", ai)
        self.assertIn("facing_dir", ai)
        self.assertNotIn("lock_on", ai)
        self.assertNotIn("SpringArm3D", ai)
        self.assertNotIn("lock-on", follower)
        self.assertIn("_nav_usable", follower)
        self.assertIn("desired_xz", follower)

    def test_arena_keeps_cheap_lights_and_instances_captains(self) -> None:
        scene = _read("content/chapters/_dev/arena.tscn")
        self.assertIn("mesnada_ai.gd", scene)
        self.assertIn("captain.tscn", scene)
        self.assertIn("type=\"NavigationRegion3D\"", scene)
        self.assertIn("AlvarFanez", scene)
        self.assertIn("MartinAntolinez", scene)
        self.assertIn("PeroBermudez", scene)
        self.assertIn('member_id = &"alvar_fanez"', scene)
        self.assertEqual(len(re.findall(r'parent="Mesnada" instance=', scene)), 3)
        self.assertEqual(len(re.findall(r'\[node name="Dummy\d+"', scene)), 8)
        self.assertEqual(scene.count("type=\"DirectionalLight3D\""), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertNotIn("GPUParticles", scene)
        self.assertNotIn("CPUParticles", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertIn("plant_banner={", _read("project.godot"))

    def test_loc_keys_are_english_identifiers_spanish_first(self) -> None:
        csv = _read("content/locales/poem_formulas.csv")
        self.assertIn("mesnada.plant_banner,Plantar pendón,Plant banner,", csv)
        self.assertIn("mesnada.wedge_form,La mesnada forma la cuña,", csv)
        self.assertIn("mesnada.order_charge,¡Cargad!,Charge,", csv)
        self.assertIn("mesnada.lanzas,lanzas,lanzas,", csv)
        lowered = csv.lower()
        for token in BLIZZARD:
            self.assertNotIn(token, lowered)

    def test_filenames_are_not_denylist(self) -> None:
        for path in (
            ROOT / "game" / "actors" / "mesnada",
            ROOT / "content" / "art" / "characters" / "captain",
            ROOT / "content" / "art" / "characters" / "lanza",
            ROOT / "data" / "mesnada",
        ):
            for child in path.rglob("*"):
                lowered = child.name.lower()
                for token in PUY_DENY + BLIZZARD:
                    self.assertNotIn(token, lowered, str(child))

    def test_godot_headless_mesnada_if_available(self) -> None:
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
                "res://tests/unit/test_mesnada_ai.gd",
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
