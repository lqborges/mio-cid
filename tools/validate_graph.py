#!/usr/bin/env python3
"""Validate data/chapters/graph.json against the campaign bible.

Run from repo root: python3 tools/validate_graph.py
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GRAPH = ROOT / "data" / "chapters" / "graph.json"
DEFAULT_SCHEMA = ROOT / "data" / "schema" / "chapter_graph.json"

BIBLE_ACT1 = [
    "a1_vivar",
    "a1_burgos",
    "a1_arcas",
    "a1_cardena",
    "a1_navapalos",
    "a1_castejon",
    "a1_alcocer",
    "a1_embassy1",
    "a1_poyo",
    "a1_tevar",
]
BIBLE_ACT2 = [
    "a2_murviedro",
    "a2_siege",
    "a2_jeronimo",
    "a2_embassy2",
    "a2_yusuf",
    "a2_embassy3",
    "a2_repay_raquel",
    "a2_tagus",
    "a2_bodas",
]
BIBLE_ACT3 = [
    "a3_leon",
    "a3_bucar",
    "a3_despedida",
    "a3_corpes",
    "a3_querella",
    "a3_toledo",
    "a3_valencia_wait",
    "a3_carrion",
    "a3_pentecost",
]
BIBLE_IDS = BIBLE_ACT1 + BIBLE_ACT2 + BIBLE_ACT3

# Allowed only while the beat folder is missing. Once content/chapters/<id>/
# exists, the flag must be produced by beats.json, dialogue, or set_flags.
STAGED_PRODUCERS = {
    "vivar_seen": "a1_vivar",
    "burgos_shutters_seen": "a1_burgos",
    "embassy3_done": "a2_embassy3",
}
ACT2_BEFORE_JOIN = BIBLE_ACT2[:6]  # through a2_embassy3; Tagus is the only branch

TAGUS_EDGES = [
    {
        "from": "a2_embassy3",
        "to": "a2_repay_raquel",
        "req_flags": ["embassy3_done", "arcas_cheated"],
        "forbid_flags": [],
    },
    {
        "from": "a2_embassy3",
        "to": "a2_tagus",
        "req_flags": ["embassy3_done"],
        "forbid_flags": ["arcas_cheated"],
    },
    {
        "from": "a2_repay_raquel",
        "to": "a2_tagus",
        "req_flags": ["repay_done"],
        "forbid_flags": [],
    },
]

DENY_PATTERNS = [
    re.compile(r"santa[-\s_]*gadea", re.IGNORECASE),
    re.compile(r"jimena.{0,24}father", re.IGNORECASE),
    re.compile(r"father.{0,24}jimena", re.IGNORECASE),
    re.compile(r"corpse[-\s_]*horse", re.IGNORECASE),
    re.compile(r"corpse.{0,40}babieca", re.IGNORECASE),
    re.compile(r"dead\s+cid.{0,40}(horse|babieca)", re.IGNORECASE),
    re.compile(r"puy[-\s_]*du[-\s_]*fou", re.IGNORECASE),
    re.compile(r"stornetta", re.IGNORECASE),
    re.compile(r"espadero", re.IGNORECASE),
    re.compile(r"flute.{0,20}babieca", re.IGNORECASE),
]

TOLEDO_ASKS = ("toledo_ask1_swords", "toledo_ask2_dowry", "toledo_ask3_riepto")


class GraphError(Exception):
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


def _validate_schema(instance: Any, schema: dict[str, Any], path: str, errors: list[str]) -> None:
    if "type" in schema:
        expected = schema["type"]
        types = expected if isinstance(expected, list) else [expected]
        if not any(_type_ok(instance, t) for t in types):
            errors.append(f"{path}: expected {expected}, got {type(instance).__name__}")
            return
    if "enum" in schema and instance not in schema["enum"]:
        errors.append(f"{path}: {instance!r} not in {schema['enum']}")
    if "pattern" in schema and isinstance(instance, str):
        if re.fullmatch(schema["pattern"], instance) is None:
            errors.append(f"{path}: {instance!r} does not match {schema['pattern']}")
    if isinstance(instance, str) and "minLength" in schema and len(instance) < schema["minLength"]:
        errors.append(f"{path}: shorter than minLength {schema['minLength']}")
    if _is_number(instance):
        if "minimum" in schema and instance < schema["minimum"]:
            errors.append(f"{path}: {instance} < minimum {schema['minimum']}")
        if "maximum" in schema and instance > schema["maximum"]:
            errors.append(f"{path}: {instance} > maximum {schema['maximum']}")
    if isinstance(instance, list):
        if "minItems" in schema and len(instance) < schema["minItems"]:
            errors.append(f"{path}: fewer than minItems {schema['minItems']}")
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for i, item in enumerate(instance):
                _validate_schema(item, item_schema, f"{path}[{i}]", errors)
        return
    if not isinstance(instance, dict):
        return
    for key in schema.get("required", []):
        if key not in instance:
            errors.append(f"{path}: missing required {key}")
    props = schema.get("properties", {})
    additional = schema.get("additionalProperties", True)
    for key, value in instance.items():
        child = f"{path}.{key}"
        if key not in props:
            if additional is False:
                errors.append(f"{child}: additional property not allowed")
            continue
        _validate_schema(value, props[key], child, errors)


def _as_str_list(raw: Any) -> list[str]:
    if not isinstance(raw, list):
        return []
    return [str(item) for item in raw if item is not None]


def _edge_key(edge: dict[str, Any]) -> tuple[str, str]:
    return (str(edge.get("from", "")), str(edge.get("to", "")))


def _flag_list(edge: dict[str, Any], key: str) -> list[str]:
    return _as_str_list(edge.get(key, []))


def _nodes_by_id(graph: dict[str, Any]) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for node in graph.get("nodes", []):
        if isinstance(node, dict) and node.get("id"):
            out[str(node["id"])] = node
    return out


def _locked_act1_ids(graph: dict[str, Any]) -> list[str]:
    ids: list[str] = []
    for node in graph.get("nodes", []):
        if not isinstance(node, dict):
            continue
        if int(node.get("act", 0)) == 1 and not bool(node.get("reorderable", False)):
            ids.append(str(node["id"]))
    return ids


def _edge_open(graph: dict[str, Any], from_id: str, to_id: str, flags: Iterable[str]) -> bool:
    have = {str(flag) for flag in flags}
    for edge in graph.get("edges", []):
        if not isinstance(edge, dict):
            continue
        if str(edge.get("from")) != from_id or str(edge.get("to")) != to_id:
            continue
        if any(flag not in have for flag in _flag_list(edge, "req_flags")):
            continue
        if any(flag in have for flag in _flag_list(edge, "forbid_flags")):
            continue
        return True
    return False


def _hub_lock_flag(to_id: str) -> str:
    parts = to_id.split("_", 1)
    if len(parts) != 2 or not parts[1]:
        return ""
    return f"hub_lock_{parts[1]}"


def can_travel(graph: dict[str, Any], from_id: str, to_id: str, flags: Iterable[str]) -> bool:
    have = {str(flag) for flag in flags}
    lock = _hub_lock_flag(to_id)
    if lock and lock in have:
        return False
    nodes = _nodes_by_id(graph)
    dest = nodes.get(to_id)
    src = nodes.get(from_id)
    if dest is not None and int(dest.get("act", 0)) == 1 and not bool(dest.get("reorderable", False)):
        if src is not None and int(src.get("act", 0)) == 1 and bool(src.get("reorderable", False)):
            return _edge_open(graph, from_id, to_id, flags)
        locked = _locked_act1_ids(graph)
        try:
            from_i = locked.index(from_id)
            to_i = locked.index(to_id)
        except ValueError:
            return False
        if to_i != from_i + 1:
            return False
    return _edge_open(graph, from_id, to_id, flags)


def collect_real_producers(root: Path, graph: dict[str, Any]) -> set[str]:
    produced: set[str] = set()
    for edge in graph.get("edges", []):
        if isinstance(edge, dict):
            produced.update(_flag_list(edge, "set_flags"))
    events_dir = root / "data" / "honor_events"
    if events_dir.is_dir():
        for path in events_dir.glob("*.json"):
            raw = json.loads(path.read_text(encoding="utf-8"))
            rows: list[Any]
            if isinstance(raw, list):
                rows = raw
            elif isinstance(raw, dict):
                events = raw.get("events", [])
                rows = events if isinstance(events, list) else []
            else:
                rows = []
            for row in rows:
                if isinstance(row, dict):
                    produced.update(_as_str_list(row.get("flags_set", [])))
    chapters = root / "content" / "chapters"
    if chapters.is_dir():
        for path in chapters.glob("**/beats.json"):
            raw = json.loads(path.read_text(encoding="utf-8"))
            steps = raw.get("steps", []) if isinstance(raw, dict) else raw
            if not isinstance(steps, list):
                continue
            for step in steps:
                if isinstance(step, dict):
                    produced.update(_as_str_list(step.get("set_flags", [])))
        for path in chapters.glob("**/*.dialogue"):
            text = path.read_text(encoding="utf-8")
            for match in re.finditer(r"flag_set\s*[:=]\s*\[([^\]]*)\]", text):
                inner = match.group(1)
                produced.update(item.strip().strip("\"'") for item in inner.split(",") if item.strip())
    return {flag for flag in produced if flag}


def collect_producers(root: Path, graph: dict[str, Any]) -> set[str]:
    produced = collect_real_producers(root, graph)
    chapters = root / "content" / "chapters"
    for flag, beat_id in STAGED_PRODUCERS.items():
        beat_dir = chapters / beat_id
        if beat_dir.is_dir():
            continue
        produced.add(flag)
    return produced


def _denylist_hits(text: str) -> list[str]:
    hits: list[str] = []
    for pattern in DENY_PATTERNS:
        found = pattern.search(text)
        if found:
            hits.append(found.group(0))
    return hits


def _load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _honor_event_ids(root: Path) -> list[str]:
    path = root / "data" / "honor_events" / "core.json"
    if not path.is_file():
        return []
    raw = _load_json(path)
    rows = raw.get("events", []) if isinstance(raw, dict) else raw
    ids: list[str] = []
    if isinstance(rows, list):
        for row in rows:
            if isinstance(row, dict) and row.get("id"):
                ids.append(str(row["id"]))
    return ids


def validate_graph(
    graph: dict[str, Any],
    *,
    schema: dict[str, Any] | None = None,
    root: Path = ROOT,
    source: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    label = str(source) if source is not None else "graph"
    if schema is not None:
        if schema.get("$id") != "mio-cid/chapter_graph":
            errors.append(f"{schema.get('$id')!r}: $id must be mio-cid/chapter_graph")
        _validate_schema(graph, schema, label, errors)
    nodes = _nodes_by_id(graph)
    if len(nodes) != len(graph.get("nodes", [])):
        errors.append(f"{label}: duplicate node ids")
    missing = [beat_id for beat_id in BIBLE_IDS if beat_id not in nodes]
    if missing:
        errors.append(f"{label}: missing bible ids: {', '.join(missing)}")
    for beat_id, expected_act in (
        [(bid, 1) for bid in BIBLE_ACT1]
        + [(bid, 2) for bid in BIBLE_ACT2]
        + [(bid, 3) for bid in BIBLE_ACT3]
    ):
        node = nodes.get(beat_id)
        if node is None:
            continue
        if int(node.get("act", 0)) != expected_act:
            errors.append(f"{label}: {beat_id} act want {expected_act} got {node.get('act')}")
        if expected_act == 1 and bool(node.get("reorderable", False)):
            errors.append(f"{label}: {beat_id} must not be reorderable")
    locked = _locked_act1_ids(graph)
    if locked != BIBLE_ACT1:
        errors.append(f"{label}: Act I locked order {locked} != {BIBLE_ACT1}")
    edges = [edge for edge in graph.get("edges", []) if isinstance(edge, dict)]
    edge_pairs = [_edge_key(edge) for edge in edges]
    for from_id, to_id in zip(BIBLE_ACT1, BIBLE_ACT1[1:]):
        if (from_id, to_id) not in edge_pairs:
            errors.append(f"{label}: missing Act I edge {from_id} -> {to_id}")
    for from_id, to_id in zip(ACT2_BEFORE_JOIN, ACT2_BEFORE_JOIN[1:]):
        if (from_id, to_id) not in edge_pairs:
            errors.append(f"{label}: missing Act II spine {from_id} -> {to_id}")
    for from_id, to_id in (
        ("a1_tevar", "a2_murviedro"),
        ("a2_tagus", "a2_bodas"),
        ("a2_bodas", "a3_leon"),
    ):
        if (from_id, to_id) not in edge_pairs:
            errors.append(f"{label}: missing spine {from_id} -> {to_id}")
    for from_id, to_id in zip(BIBLE_ACT3, BIBLE_ACT3[1:]):
        if (from_id, to_id) not in edge_pairs:
            errors.append(f"{label}: missing Act III spine {from_id} -> {to_id}")
    locked_set = set(BIBLE_ACT1)
    for from_id, to_id in edge_pairs:
        if from_id in locked_set and to_id in locked_set:
            try:
                span = BIBLE_ACT1.index(to_id) - BIBLE_ACT1.index(from_id)
            except ValueError:
                span = 0
            if span != 1:
                errors.append(f"{label}: Act I skip/back edge {from_id} -> {to_id}")
        if from_id not in nodes:
            errors.append(f"{label}: edge from unknown {from_id}")
        if to_id not in nodes:
            errors.append(f"{label}: edge to unknown {to_id}")
    for spec in TAGUS_EDGES:
        match = next((edge for edge in edges if _edge_key(edge) == (spec["from"], spec["to"])), None)
        if match is None:
            errors.append(f"{label}: missing Tagus edge {spec['from']} -> {spec['to']}")
            continue
        if _flag_list(match, "req_flags") != spec["req_flags"]:
            errors.append(
                f"{label}: {spec['from']}->{spec['to']} req_flags "
                f"{_flag_list(match, 'req_flags')} != {spec['req_flags']}"
            )
        if _flag_list(match, "forbid_flags") != spec["forbid_flags"]:
            errors.append(
                f"{label}: {spec['from']}->{spec['to']} forbid_flags "
                f"{_flag_list(match, 'forbid_flags')} != {spec['forbid_flags']}"
            )
    tagus_from = {(fr, to) for fr, to in edge_pairs if to == "a2_tagus"}
    allowed_tagus = {("a2_embassy3", "a2_tagus"), ("a2_repay_raquel", "a2_tagus")}
    extra_tagus = tagus_from - allowed_tagus
    if extra_tagus:
        errors.append(f"{label}: extra Tagus incoming {sorted(extra_tagus)}")
    repay_in = {(fr, to) for fr, to in edge_pairs if to == "a2_repay_raquel"}
    if repay_in != {("a2_embassy3", "a2_repay_raquel")}:
        errors.append(f"{label}: a2_repay_raquel incoming must be only from a2_embassy3")
    producers = collect_producers(root, graph)
    real_producers = collect_real_producers(root, graph)
    chapters = root / "content" / "chapters"
    for flag, beat_id in STAGED_PRODUCERS.items():
        if (chapters / beat_id).is_dir() and flag not in real_producers:
            errors.append(f"{label}: staged req_flag {flag!r} missing producer in {beat_id}")
    v1_cut_ids = {
        str(node.get("id", ""))
        for node in graph.get("nodes", [])
        if isinstance(node, dict) and bool(node.get("v1_cut"))
    }
    for edge in edges:
        if str(edge.get("to", "")) in v1_cut_ids:
            continue
        for flag in _flag_list(edge, "req_flags"):
            if flag not in producers:
                errors.append(f"{label}: req_flag {flag!r} has no producer")
    tevar_out = [edge for edge in edges if str(edge.get("from")) == "a1_tevar"]
    if not tevar_out:
        errors.append(f"{label}: a1_tevar has no exit")
    for edge in tevar_out:
        if "colada_acquired" not in _flag_list(edge, "set_flags"):
            errors.append(f"{label}: {edge.get('from')}->{edge.get('to')} must set colada_acquired")
    avengalvon = root / "data" / "characters" / "avengalvon.json"
    if avengalvon.is_file():
        person = _load_json(avengalvon)
        until = str(person.get("must_survive_until", "")) if isinstance(person, dict) else ""
        if until != "a3_despedida":
            errors.append(f"{avengalvon}: must_survive_until want a3_despedida got {until!r}")
        if until and until not in nodes:
            errors.append(f"{avengalvon}: must_survive_until {until!r} is not a graph node")
    honor_ids = _honor_event_ids(root)
    if honor_ids:
        positions = [honor_ids.index(ask) for ask in TOLEDO_ASKS if ask in honor_ids]
        if len(positions) != len(TOLEDO_ASKS):
            missing_asks = [ask for ask in TOLEDO_ASKS if ask not in honor_ids]
            errors.append(f"{label}: missing Toledo asks {missing_asks}")
        elif positions != sorted(positions):
            errors.append(f"{label}: Toledo asks are out of poem order")
    graph_text = json.dumps(graph, ensure_ascii=False)
    if source is not None and source.is_file():
        graph_text = source.read_text(encoding="utf-8")
    for hit in _denylist_hits(graph_text):
        errors.append(f"{label}: denylist token {hit!r}")
    return errors


def load_schema(path: Path) -> dict[str, Any]:
    schema = _load_json(path)
    if not isinstance(schema, dict):
        raise GraphError(f"{path}: schema must be an object")
    return schema


def load_graph(path: Path) -> dict[str, Any]:
    data = _load_json(path)
    if not isinstance(data, dict):
        raise GraphError(f"{path}: graph must be an object")
    return data


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--graph", type=Path, default=DEFAULT_GRAPH)
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args(argv)
    try:
        schema = load_schema(args.schema)
        graph = load_graph(args.graph)
        errors = validate_graph(graph, schema=schema, root=args.root, source=args.graph)
    except (OSError, json.JSONDecodeError, GraphError) as exc:
        print(f"validate_graph: {exc}", file=sys.stderr)
        return 1
    if errors:
        for error in errors:
            print(f"validate_graph: {error}", file=sys.stderr)
        return 1
    print("validate_graph: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
