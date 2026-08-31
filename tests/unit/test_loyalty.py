#!/usr/bin/env python3
"""Structural tests for PR-04 mesnada data. Run: python3 tests/unit/test_loyalty.py

gdUnit4 is not vendored yet. This runner plus tests/unit/test_loyalty.gd cover
loyalty, schema, and the seed roster until gdUnit4 v6.2.1 is vendored.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from import_characters import (  # noqa: E402
    CharacterImportError,
    import_characters,
    load_schema,
    validate_character,
)

SEED_IDS = [
    "cid",
    "alvar_fanez",
    "martin_antolinez",
    "pero_bermudez",
    "muno_gustioz",
    "felez_munoz",
    "jimena",
    "elvira",
    "sol",
    "alfonso",
    "raquel",
    "vidas",
    "avengalvon",
    "jeronimo",
    "ferran_gonzalez",
    "diego_gonzalez",
    "asur_gonzalez",
    "ramon_berenguer",
    "fariz",
    "galve",
    "yusuf",
    "bucar",
    "garcia_ordonez",
    "diego_tellez",
    "burgos_child",
]
DESERTION_CAPABLE = {
    "martin_antolinez",
    "pero_bermudez",
    "muno_gustioz",
    "felez_munoz",
}
INFANTES = {"ferran_gonzalez", "diego_gonzalez", "asur_gonzalez"}


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _load_json(rel: str) -> dict:
    return json.loads(_read(rel))


class TestMesnadaDataAndRoster(unittest.TestCase):
    def test_one_json_file_per_seed_id(self) -> None:
        data_dir = ROOT / "data" / "characters"
        files = sorted(p.name for p in data_dir.glob("*.json"))
        self.assertEqual(files, sorted(f"{cid}.json" for cid in SEED_IDS))
        for cid in SEED_IDS:
            payload = _load_json(f"data/characters/{cid}.json")
            self.assertEqual(payload["id"], cid)
            self.assertNotIn("characters", payload)
            self.assertNotIn("members", payload)

    def test_raquel_and_vidas_are_separate_files(self) -> None:
        raquel = _load_json("data/characters/raquel.json")
        vidas = _load_json("data/characters/vidas.json")
        self.assertEqual(raquel["id"], "raquel")
        self.assertEqual(vidas["id"], "vidas")
        self.assertNotEqual(raquel["id"], vidas["id"])
        self.assertNotIn("vidas", json.dumps(raquel))
        self.assertNotIn("raquel", json.dumps(vidas))

    def test_schema_required_fields_and_roles(self) -> None:
        schema = _load_json("data/schema/character.json")
        self.assertEqual(schema["$id"], "mio-cid/character")
        required = schema["required"]
        for key in (
            "id",
            "role",
            "combat",
            "unkillable",
            "desertion_capable",
            "list_eligible",
            "mesura_max",
            "essential",
        ):
            self.assertIn(key, required)
        roles = schema["properties"]["role"]["enum"]
        for role in (
            "player",
            "captain",
            "family",
            "king",
            "infante",
            "ally_taifa",
            "bishop",
            "burgales",
            "usurer",
            "count",
            "taifa_captain",
            "taifa_king",
            "ally",
        ):
            self.assertIn(role, roles)
        self.assertFalse(schema.get("additionalProperties", True))

    def test_seed_invariants(self) -> None:
        alvar = _load_json("data/characters/alvar_fanez.json")
        self.assertFalse(alvar["desertion_capable"])
        self.assertFalse(alvar["list_eligible"])
        self.assertTrue(alvar["essential"])

        for cid in DESERTION_CAPABLE:
            row = _load_json(f"data/characters/{cid}.json")
            self.assertTrue(row["desertion_capable"], cid)
            self.assertTrue(row["list_eligible"], cid)
            self.assertEqual(row["role"], "captain", cid)

        alfonso = _load_json("data/characters/alfonso.json")
        self.assertEqual(alfonso["combat"], 0)
        self.assertTrue(alfonso["unkillable"])
        self.assertEqual(alfonso["role"], "king")

        for cid in INFANTES:
            row = _load_json(f"data/characters/{cid}.json")
            self.assertEqual(row["mesura_max"], 0, cid)
            self.assertEqual(row["role"], "infante", cid)

        avengalvon = _load_json("data/characters/avengalvon.json")
        self.assertEqual(avengalvon["must_survive_until"], "a3_despedida")
        self.assertTrue(avengalvon["essential"])
        self.assertEqual(avengalvon["role"], "ally_taifa")

    def test_importer_accepts_seed_and_writes_tres(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            characters = import_characters(
                ROOT / "data" / "characters",
                ROOT / "data" / "schema" / "character.json",
                out,
            )
            self.assertEqual({row["id"] for row in characters}, set(SEED_IDS))
            for cid in SEED_IDS:
                tres = (out / f"{cid}.tres").read_text(encoding="utf-8")
                self.assertIn(f'id = &"{cid}"', tres)
                self.assertIn("script_class=\"MesnadaMember\"", tres)

    def test_importer_rejects_packed_pair(self) -> None:
        schema = load_schema(ROOT / "data" / "schema" / "character.json")
        packed = [
            _load_json("data/characters/raquel.json"),
            _load_json("data/characters/vidas.json"),
        ]
        with self.assertRaises(CharacterImportError):
            validate_character(packed, schema, Path("raquel_y_vidas.json"))
        nested = {
            "id": "raquel",
            "display_name_key": "char.raquel",
            "role": "usurer",
            "combat": 0,
            "birth": 20,
            "loyalty_0": 0.4,
            "essential": False,
            "desertion_capable": False,
            "unkillable": True,
            "list_eligible": False,
            "mesura_max": 30,
            "vidas": _load_json("data/characters/vidas.json"),
        }
        with self.assertRaises(CharacterImportError):
            validate_character(nested, schema, Path("raquel.json"))

    def test_importer_rejects_filename_id_mismatch(self) -> None:
        schema = load_schema(ROOT / "data" / "schema" / "character.json")
        raquel = _load_json("data/characters/raquel.json")
        with self.assertRaises(CharacterImportError):
            validate_character(raquel, schema, Path("vidas.json"))

    def test_member_script_gifts_and_starvation(self) -> None:
        source = _read("game/actors/mesnada/mesnada_member.gd")
        self.assertRegex(source, re.compile(r"^class_name MesnadaMember$", re.MULTILINE))
        self.assertRegex(source, re.compile(r"^extends Resource$", re.MULTILINE))
        self.assertIn("func receive_gift(value_marks: float, public: bool)", source)
        self.assertIn("value_marks * 0.002", source)
        self.assertIn("0.04 if public else 0.0", source)
        self.assertIn("func tick_starvation(onores: float, unfed_loyalty_delta: float)", source)
        self.assertIn("desertion_capable", source)
        self.assertIn("loyalty < 0.15", source)
        self.assertNotIn("class_name HonorService", source)
        self.assertNotIn("class_name EventBus", source)

    def test_roster_script_is_resource_not_autoload(self) -> None:
        source = _read("game/actors/mesnada/mesnada_roster.gd")
        self.assertRegex(source, re.compile(r"^class_name MesnadaRoster$", re.MULTILINE))
        self.assertRegex(source, re.compile(r"^extends Resource$", re.MULTILINE))
        self.assertIn("func gift_to(", source)
        self.assertIn("func tick_starvation(", source)
        self.assertIn("func living_named_captains(", source)
        project = _read("project.godot")
        self.assertNotIn("MesnadaRoster=", project)
        self.assertNotIn("MesnadaMember=", project)
        self.assertFalse((ROOT / "game" / "actors" / "mesnada" / "mesnada_ai.gd").exists())

    def test_no_combat_in_mesnada_scripts(self) -> None:
        for rel in (
            "game/actors/mesnada/mesnada_member.gd",
            "game/actors/mesnada/mesnada_roster.gd",
        ):
            source = _read(rel)
            self.assertNotIn("HitBox", source)
            self.assertNotIn("HurtBox", source)
            self.assertNotIn("CharacterBody3D", source)

    def test_godot_headless_loyalty_if_available(self) -> None:
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
            self.skipTest("Godot binary not on PATH; gdUnit4 not vendored")
        result = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "-s",
                "res://tests/unit/test_loyalty.gd",
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
