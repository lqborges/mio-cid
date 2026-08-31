#!/usr/bin/env python3
"""Validate data/characters/*.json (one person per file) and write .tres.

Run from repo root: python3 tools/import_characters.py
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCHEMA = ROOT / "data" / "schema" / "character.json"
DEFAULT_DATA = ROOT / "data" / "characters"
MEMBER_SCRIPT = "res://game/actors/mesnada/mesnada_member.gd"

PACKED_KEYS = frozenset({"characters", "members", "people", "roster", "pair"})


class CharacterImportError(Exception):
    pass


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _is_number(value: Any) -> bool:
    return _is_int(value) or isinstance(value, float)


def _type_ok(value: Any, expected: str) -> bool:
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return _is_int(value)
    if expected == "number":
        return _is_number(value)
    if expected == "null":
        return value is None
    return False


def _validate(instance: Any, schema: dict[str, Any], path: str) -> None:
    if "type" in schema:
        expected = schema["type"]
        types = expected if isinstance(expected, list) else [expected]
        if not any(_type_ok(instance, t) for t in types):
            raise CharacterImportError(
                f"{path}: expected {expected}, got {type(instance).__name__}"
            )
    if "enum" in schema and instance not in schema["enum"]:
        raise CharacterImportError(f"{path}: {instance!r} not in {schema['enum']}")
    if "pattern" in schema:
        import re

        if isinstance(instance, str) and re.fullmatch(schema["pattern"], instance) is None:
            raise CharacterImportError(f"{path}: {instance!r} does not match {schema['pattern']}")
    if _is_number(instance):
        if "minimum" in schema and instance < schema["minimum"]:
            raise CharacterImportError(f"{path}: {instance} < minimum {schema['minimum']}")
        if "maximum" in schema and instance > schema["maximum"]:
            raise CharacterImportError(f"{path}: {instance} > maximum {schema['maximum']}")
    if not isinstance(instance, dict):
        return
    for key in schema.get("required", []):
        if key not in instance:
            raise CharacterImportError(f"{path}: missing required {key}")
    props = schema.get("properties", {})
    additional = schema.get("additionalProperties", True)
    for key, value in instance.items():
        child = f"{path}.{key}"
        if key not in props:
            if additional is False:
                raise CharacterImportError(f"{child}: additional property not allowed")
            continue
        _validate(value, props[key], child)


def _reject_packed(data: Any, source: Path) -> None:
    if isinstance(data, list):
        raise CharacterImportError(
            f"{source}: packed list of {len(data)} people; one JSON file per id"
        )
    if not isinstance(data, dict):
        raise CharacterImportError(f"{source}: root must be one character object")
    for key, value in data.items():
        if key in PACKED_KEYS:
            raise CharacterImportError(f"{source}: packed key {key!r}; one person per file")
        if isinstance(value, dict) and "id" in value and "role" in value:
            raise CharacterImportError(
                f"{source}: nested person under {key!r}; never pack two people in one row"
            )
        if isinstance(value, list) and any(
            isinstance(item, dict) and "id" in item and "role" in item for item in value
        ):
            raise CharacterImportError(f"{source}: packed people list under {key!r}")


def load_schema(path: Path) -> dict[str, Any]:
    schema = json.loads(path.read_text(encoding="utf-8"))
    if schema.get("$id") != "mio-cid/character":
        raise CharacterImportError(f"{path}: $id must be mio-cid/character")
    return schema


def validate_character(data: Any, schema: dict[str, Any], source: Path) -> dict[str, Any]:
    _reject_packed(data, source)
    _validate(data, schema, str(source))
    char_id = data["id"]
    if source.stem != char_id:
        raise CharacterImportError(
            f"{source}: filename stem {source.stem!r} must equal id {char_id!r}"
        )
    return data


def iter_character_files(data_dir: Path) -> list[Path]:
    if not data_dir.is_dir():
        raise CharacterImportError(f"{data_dir}: missing characters directory")
    files = sorted(p for p in data_dir.glob("*.json") if p.is_file())
    if not files:
        raise CharacterImportError(f"{data_dir}: no character JSON files")
    return files


def load_characters(data_dir: Path, schema: dict[str, Any]) -> list[dict[str, Any]]:
    seen: dict[str, Path] = {}
    loaded: list[dict[str, Any]] = []
    for path in iter_character_files(data_dir):
        raw = json.loads(path.read_text(encoding="utf-8"))
        character = validate_character(raw, schema, path)
        char_id = character["id"]
        if char_id in seen:
            raise CharacterImportError(
                f"duplicate id {char_id!r} in {path} and {seen[char_id]}"
            )
        seen[char_id] = path
        loaded.append(character)
    return loaded


def _sn(value: Any) -> str:
    text = "" if value is None else str(value)
    return '&"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def _bool(value: Any) -> str:
    return "true" if bool(value) else "false"


def write_tres(character: dict[str, Any], out_path: Path) -> None:
    until = character.get("must_survive_until") or ""
    body = "\n".join(
        [
            "[gd_resource type=\"Resource\" script_class=\"MesnadaMember\" load_steps=2 format=3]",
            "",
            f'[ext_resource type="Script" path="{MEMBER_SCRIPT}" id="1"]',
            "",
            "[resource]",
            'script = ExtResource("1")',
            f"id = {_sn(character['id'])}",
            f"display_name_key = {_sn(character['display_name_key'])}",
            f"poem_formula_key = {_sn(character.get('poem_formula_key', ''))}",
            f"role = {_sn(character['role'])}",
            f"combat = {float(character['combat'])}",
            f"birth = {float(character['birth'])}",
            f"diplomacy = {float(character.get('diplomacy', 0.0))}",
            f"mesura_max = {float(character['mesura_max'])}",
            f"loyalty = {float(character['loyalty_0'])}",
            f"gift_bias = {_sn(character.get('gift_bias', ''))}",
            "alive = true",
            f"essential = {_bool(character['essential'])}",
            f"desertion_capable = {_bool(character['desertion_capable'])}",
            f"unkillable = {_bool(character['unkillable'])}",
            f"list_eligible = {_bool(character['list_eligible'])}",
            f"list_index = {int(character.get('list_index', -1))}",
            f"recruitable_beat = {_sn(character.get('recruitable_beat', ''))}",
            f"must_survive_until = {_sn(until)}",
            f"vo_id = {_sn(character.get('vo_id', character['id']))}",
            "will_swear_riepto = true",
            "",
        ]
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(body, encoding="utf-8")


def import_characters(
    data_dir: Path,
    schema_path: Path,
    out_dir: Path | None = None,
) -> list[dict[str, Any]]:
    schema = load_schema(schema_path)
    characters = load_characters(data_dir, schema)
    dest = out_dir if out_dir is not None else data_dir
    for character in characters:
        write_tres(character, dest / f"{character['id']}.tres")
    return characters


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--out-dir", type=Path, default=None)
    args = parser.parse_args(argv)
    try:
        characters = import_characters(args.data_dir, args.schema, args.out_dir)
    except (OSError, json.JSONDecodeError, CharacterImportError) as exc:
        print(f"import_characters: {exc}", file=sys.stderr)
        return 1
    dest = args.out_dir if args.out_dir is not None else args.data_dir
    print(f"import_characters: {len(characters)} characters → {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
