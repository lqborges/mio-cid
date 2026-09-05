#!/usr/bin/env python3
"""Structural tests for issue #12 combat feel / mount hold."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _load(rel: str) -> dict:
    return json.loads(_read(rel))


class TestCombatFeel(unittest.TestCase):
    def test_tunables_are_data_driven(self) -> None:
        tunables = _load("data/combat/tunables.json")
        for key in ("windup_frac", "active_frac", "recovery_frac", "input_buffer_sec", "hit_flash_sec"):
            self.assertIn(key, tunables)
        self.assertAlmostEqual(tunables["windup_frac"] + tunables["active_frac"] + tunables["recovery_frac"], 1.0, places=2)
        combat = _read("game/actors/player/cid_combat.gd")
        self.assertIn("windup_frac", combat)
        self.assertNotIn("windup_frac = 0.12", combat)
        hurt = _read("game/combat/hurt_box.gd")
        self.assertIn('preload("res://game/combat/combat_feel.gd")', hurt)
        self.assertIn("Feel.note_hit", hurt)
        self.assertNotIn("CombatFeel.", hurt)

    def test_feel_respects_reduced_motion(self) -> None:
        feel = _read("game/combat/combat_feel.gd")
        self.assertIn("flash_enabled", feel)
        self.assertIn("shake_enabled", feel)
        self.assertIn("Visual/Humanoid", feel)
        self.assertIn("_visible_look_meshes", feel)
        self.assertNotIn("GPUParticles", feel)
        dummy = _read("game/combat/dummy_enemy.gd")
        self.assertIn("data/combat/roles.json", dummy)

    def test_horse_exposes_mount_progress(self) -> None:
        horse = _read("game/actors/player/horse_companion.gd")
        self.assertIn("func mount_progress(", horse)
        self.assertIn("mount_hold_sec", horse)
        guide = _read("game/autoload/player_guide.gd")
        self.assertIn("mount_progress", guide)
        self.assertIn("note_blocked", guide)
        self.assertIn("combat.blocked.mesura", _read("content/locales/strings.csv"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
