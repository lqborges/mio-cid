#!/usr/bin/env python3
"""Named Cantar portraits must exist for every character json."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class TestPortraits(unittest.TestCase):
    def test_every_character_has_a_portrait(self) -> None:
        portraits = json.loads(
            (ROOT / "data/look/portraits.json").read_text(encoding="utf-8")
        )
        ids = sorted(p.stem for p in (ROOT / "data/characters").glob("*.json"))
        missing = [i for i in ids if i not in portraits]
        self.assertEqual(missing, [], "missing portraits: %s" % missing)
        for key in ("cid", "jimena", "alfonso", "yusuf", "jeronimo", "innkeeper", "burgos_child"):
            self.assertIn("kit", portraits[key])
        look = (ROOT / "game/actors/look/humanoid_look.gd").read_text(encoding="utf-8")
        self.assertIn('"Child": "burgos_child"', look)
        self.assertIn('"Innkeeper": "innkeeper"', look)
        self.assertIn("cap.height >= 1.0", look)
        looks = (ROOT / "game/autoload/humanoid_looks.gd").read_text(encoding="utf-8")
        self.assertIn("cap.height >= 1.0", looks)
        follower = (ROOT / "game/actors/mesnada/mesnada_follower.gd").read_text(
            encoding="utf-8"
        )
        self.assertIn('get_node_or_null("Visual/Humanoid")', follower)

    def test_look_scripts_exist(self) -> None:
        self.assertTrue((ROOT / "game/actors/look/humanoid_look.gd").is_file())
        self.assertTrue((ROOT / "game/autoload/humanoid_looks.gd").is_file())
        autoload = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertIn(
            'HumanoidLooks="*res://game/autoload/humanoid_looks.gd"', autoload
        )
        looks = (ROOT / "game/autoload/humanoid_looks.gd").read_text(encoding="utf-8")
        self.assertIn("get_instance_id", looks)
        self.assertIn("is_instance_id_valid", looks)
        self.assertIn("func _consider_deferred", looks)
        self.assertIn("obj as Node", looks)
        self.assertNotIn("var node: Node = obj", looks)
        self.assertNotIn("_consider.call_deferred", looks)
        self.assertNotIn('call_deferred("_consider"', looks)


if __name__ == "__main__":
    unittest.main(verbosity=2)
