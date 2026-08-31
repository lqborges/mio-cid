#!/usr/bin/env python3
"""Structural tests for PR-24 Murviedro + Valencia siege clock.

Run: python3 tests/unit/test_a2_siege.py
"""

from __future__ import annotations

import csv
import json
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from validate_graph import can_travel, load_graph, main as validate_main  # noqa: E402
from validate_graph import _validate_schema  # noqa: E402

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
    "corpse",
    "reconquista",
    "holy-war",
    "holy_war",
)

MURV = "content/chapters/a2_murviedro"
SIEGE = "content/chapters/a2_siege"
EVENT_TYPES = {"sally", "hunger", "deserter", "sermon", "parley", "parias"}


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _origin(scene: str, node_name: str) -> tuple[float, float, float]:
    marker = f'[node name="{node_name}"'
    start = scene.find(marker)
    if start < 0:
        raise AssertionError(f"missing node {node_name}")
    block = scene[start : start + 500]
    match = re.search(
        r"transform = Transform3D\(([^)]+)\)",
        block,
    )
    if match is None:
        raise AssertionError(f"{node_name} missing transform")
    nums = [float(part.strip()) for part in match.group(1).split(",")]
    if len(nums) != 12:
        raise AssertionError(f"{node_name} transform want 12 floats, got {len(nums)}")
    return nums[9], nums[10], nums[11]


def _subresource_size(scene: str, resource_id: str) -> tuple[float, float, float]:
    marker = f'id="{resource_id}"'
    start = scene.find(marker)
    if start < 0:
        raise AssertionError(f"missing subresource {resource_id}")
    block = scene[start : start + 240]
    match = re.search(r"size = Vector3\(([^)]+)\)", block)
    if match is None:
        raise AssertionError(f"{resource_id} missing Vector3 size")
    nums = [float(part.strip()) for part in match.group(1).split(",")]
    if len(nums) != 3:
        raise AssertionError(f"{resource_id} size want 3 floats")
    return nums[0], nums[1], nums[2]


def _aabb_overlap(
    a_min: tuple[float, float, float],
    a_max: tuple[float, float, float],
    b_min: tuple[float, float, float],
    b_max: tuple[float, float, float],
) -> bool:
    return (
        a_min[0] <= b_max[0]
        and a_max[0] >= b_min[0]
        and a_min[1] <= b_max[1]
        and a_max[1] >= b_min[1]
        and a_min[2] <= b_max[2]
        and a_max[2] >= b_min[2]
    )


def _zone_aabb(
    scene: str, node_name: str, shape_id: str
) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    origin = _origin(scene, node_name)
    size = _subresource_size(scene, shape_id)
    half = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
    return (
        (origin[0] - half[0], origin[1] - half[1], origin[2] - half[2]),
        (origin[0] + half[0], origin[1] + half[1], origin[2] + half[2]),
    )


class TestA2MurviedroAndSiegeClock(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        for rel in (
            f"{MURV}/world.tscn",
            f"{MURV}/world.gd",
            f"{MURV}/murviedro.dialogue",
            f"{MURV}/beats.json",
            f"{SIEGE}/world.tscn",
            f"{SIEGE}/world.gd",
            f"{SIEGE}/siege.dialogue",
            f"{SIEGE}/beats.json",
            f"{SIEGE}/storm_prompt.tscn",
            f"{SIEGE}/storm_prompt.gd",
            "data/siege/valencia_events.json",
            "data/schema/siege_events.json",
            "data/honor_events/siege.json",
            "data/towns/murviedro.json",
            "game/systems/siege/siege_calendar.gd",
            "content/art/characters/cid/cid.tscn",
            "content/art/characters/horse/horse.tscn",
            "content/art/characters/dummy/dummy.tscn",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)
        self.assertTrue((ROOT / "content/chapters/a2_jeronimo/world.tscn").is_file())
        self.assertFalse((ROOT / "content/chapters/a2_valencia_hub/world.tscn").is_file())

    def test_valencia_events_are_eight_authored_rows(self) -> None:
        payload = json.loads(_read("data/siege/valencia_events.json"))
        schema = json.loads(_read("data/schema/siege_events.json"))
        errors: list[str] = []
        _validate_schema(payload, schema, "valencia_events", errors)
        self.assertEqual(errors, [], errors)
        events = payload["events"]
        self.assertEqual(len(events), 8)
        self.assertEqual(payload["siege_days"], 270)
        self.assertGreaterEqual(payload["rest_skip_min_days"], 14)
        self.assertLessEqual(payload["rest_skip_max_days"], 28)
        self.assertLessEqual(payload["rest_skip_min_days"], payload["rest_skip_max_days"])
        self.assertFalse(payload["wall_storm_enabled"])
        seen_types = set()
        days = []
        ids = []
        for row in events:
            self.assertIn(row["type"], EVENT_TYPES, row["id"])
            seen_types.add(row["type"])
            self.assertGreaterEqual(row["day"], 0)
            self.assertLessEqual(row["day"], 270)
            days.append(row["day"])
            ids.append(row["id"])
            self.assertTrue(row["scene"])
            self.assertTrue(row["honor_event"])
        self.assertEqual(seen_types, EVENT_TYPES)
        self.assertEqual(days, sorted(days))
        self.assertEqual(len(set(ids)), 8)
        self.assertEqual(events[-1]["honor_event"], "valencia_held")

    def test_honor_events_live_in_json_not_gdscript(self) -> None:
        siege = json.loads(_read("data/honor_events/siege.json"))
        core = json.loads(_read("data/honor_events/core.json"))
        catalog = {row["id"]: row for row in siege["events"]}
        catalog.update({row["id"]: row for row in core["events"]})
        payload = json.loads(_read("data/siege/valencia_events.json"))
        for row in payload["events"]:
            honor_id = row["honor_event"]
            self.assertIn(honor_id, catalog, honor_id)
            event = catalog[honor_id]
            self.assertIn("deltas", event)
            self.assertFalse(event.get("hard_fail", False), honor_id)
        self.assertIn("murviedro_take", catalog)
        self.assertEqual(catalog["murviedro_take"]["beat"], "a2_murviedro")
        held = catalog["valencia_held"]
        self.assertEqual(held["deltas"]["honor"], 25)
        self.assertEqual(held["beat"], "a2_siege")
        self.assertIn("city", held["tags"])
        town = json.loads(_read("data/towns/murviedro.json"))
        self.assertFalse(town["keep_or_sell"])
        self.assertEqual(town["take_event_id"], "murviedro_take")

    def test_clock_is_campaign_clock_not_a_second_system(self) -> None:
        calendar = _read("game/systems/siege/siege_calendar.gd")
        self.assertRegex(calendar, re.compile(r"^class_name SiegeCalendar$", re.MULTILINE))
        self.assertIn("data/siege/valencia_events.json", calendar)
        self.assertNotIn("unfed_streak", calendar)
        self.assertNotIn("tick_night", calendar)
        self.assertNotIn("camp_night", calendar)
        self.assertNotIn("days_elapsed", calendar)
        clock = _read("game/autoload/campaign_clock.gd")
        self.assertIn("func set_segment_name", clock)
        self.assertIn('"siege"', clock)
        self.assertIn("func feeds_tonight() -> bool:", clock)
        self.assertIn("Segment.CAMP_NIGHT", clock)
        self.assertIn("Segment.REFUSE_48H", clock)
        self.assertIn("Segment.SIEGE", clock)
        body = re.search(
            r"func feeds_tonight\(\) -> bool:\n(?P<body>.*?)(?=\nfunc |\Z)",
            clock,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(body)
        feed_body = body.group("body")
        self.assertIn("CAMP_NIGHT", feed_body)
        self.assertIn("REFUSE_48H", feed_body)
        self.assertNotIn("SIEGE", feed_body)
        self.assertNotIn("LISTS_WAIT", feed_body)
        world = _read(f"{SIEGE}/world.gd")
        self.assertIn("CampaignClock", world)
        self.assertIn("advance_calendar", world)
        self.assertIn("set_segment_name", world)
        self.assertIn("siege", world)
        self.assertNotIn("camp_night(", world)
        self.assertNotIn("tick_night(", world)
        self.assertNotIn("class_name SiegeClock", world)
        self.assertNotIn("270", world)
        self.assertNotIn("28", world)
        autoloads = _read("project.godot")
        self.assertIn("CampaignClock", autoloads)
        self.assertNotIn("SiegeClock", autoloads)
        director = _read("game/chapters/beat_director.gd")
        self.assertIn('"siege_event"', director)
        self.assertIn('"clock_segment"', director)

    def test_murviedro_scene_is_coastal_field_take(self) -> None:
        scene = _read(f"{MURV}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("dummy.tscn", scene)
        self.assertIn("captain.tscn", scene)
        self.assertIn("hall_whisper.tscn", scene)
        self.assertIn("honor_meters.tscn", scene)
        self.assertIn("mesura_hud.tscn", scene)
        self.assertEqual(scene.count('type="DirectionalLight3D"'), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("shadow_enabled = false", scene)
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 8)
        self.assertIn("Sea", scene)
        self.assertIn("RoadCutZone", scene)
        self.assertIn("FieldZone", scene)
        self.assertIn("Garrison", scene)
        self.assertIn("Mesnada", scene)
        self.assertIn("Horse", scene)
        self.assertIn("PlaceName", scene)
        self.assertNotIn("KeepOrSell", scene)
        self.assertNotIn("StormZone", scene)
        field_at = scene.find('[node name="FieldZone"')
        road_at = scene.find('[node name="RoadCutZone"')
        self.assertGreaterEqual(field_at, 0)
        self.assertGreaterEqual(road_at, 0)
        self.assertIn("collision_mask = 130", scene[field_at : field_at + 280])
        self.assertIn("collision_mask = 130", scene[road_at : road_at + 280])
        self.assertNotIn("GPUParticles3D", scene)
        source = _read(f"{MURV}/world.gd")
        self.assertIn("func run_roads", source)
        self.assertIn("func run_take", source)
        self.assertIn("murviedro_take", source)
        self.assertIn("a2_siege", source)
        self.assertIn("func can_storm_wall", source)
        self.assertIn("return false", source)
        self.assertIn("lanza_body_limit", source)
        self.assertNotIn("keep_or_sell", source)
        self.assertNotIn("func _enter_tree", source)
        self.assertRegex(source, re.compile(r"^extends Node3D", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))

    def test_siege_scene_walls_and_storm_disabled(self) -> None:
        scene = _read(f"{SIEGE}/world.tscn")
        self.assertIn("cid.tscn", scene)
        self.assertIn("horse.tscn", scene)
        self.assertIn("dummy.tscn", scene)
        self.assertIn("storm_prompt.tscn", scene)
        self.assertEqual(scene.count('type="DirectionalLight3D"'), 1)
        self.assertNotIn("OmniLight3D", scene)
        self.assertNotIn("SpotLight3D", scene)
        self.assertIn("sdfgi_enabled = false", scene)
        self.assertIn("WallWest", scene)
        self.assertIn("WallEast", scene)
        self.assertIn("StormZone", scene)
        self.assertIn("RestZone", scene)
        self.assertIn("Host", scene)
        self.assertIn("MarketStall", scene)
        self.assertIn("ExtraA", scene)
        self.assertIn("StormPrompt", scene)
        self.assertGreaterEqual(scene.count('type="CSGBox3D"'), 8)
        storm_at = scene.find('[node name="StormZone"')
        rest_at = scene.find('[node name="RestZone"')
        self.assertGreaterEqual(storm_at, 0)
        self.assertGreaterEqual(rest_at, 0)
        self.assertIn("collision_mask = 130", scene[storm_at : storm_at + 280])
        self.assertIn("collision_mask = 130", scene[rest_at : rest_at + 280])
        host_at = scene.find('[node name="Host"')
        self.assertIn("visible = false", scene[host_at : host_at + 120])
        self.assertNotIn("GPUParticles3D", scene)
        source = _read(f"{SIEGE}/world.gd")
        self.assertIn("func can_storm_wall", source)
        self.assertIn("func try_storm_wall", source)
        self.assertIn("func rest_skip", source)
        self.assertIn("func run_calendar", source)
        self.assertIn("_reset_host_dummies", source)
        self.assertIn("revive", source)
        self.assertIn("wall_storm_enabled", source)
        dummy = _read("game/combat/dummy_enemy.gd")
        self.assertIn("func revive", dummy)
        rest = _origin(scene, "RestZone")
        self.assertGreaterEqual(rest[0], 3.0)
        storm = _origin(scene, "StormZone")
        gate = _origin(scene, "Gate")
        self.assertAlmostEqual(storm[2], gate[2], delta=1.0)
        stall = _origin(scene, "MarketStall")
        extra = _origin(scene, "ExtraA")
        self.assertGreater(stall[2], gate[2])
        self.assertGreater(extra[2], gate[2])
        calendar_src = _read("game/systems/siege/siege_calendar.gd")
        self.assertIn("rest_skip_max_days", calendar_src)
        self.assertIn("rest_skip_min_days", calendar_src)
        self.assertIn("siege_day", calendar_src)
        self.assertIn("a2_jeronimo", source)
        self.assertIn("current_scene != self", source)
        self.assertIn("collision_layer", source)
        self.assertIn("monitorable", source)
        self.assertNotIn("func _enter_tree", source)
        self.assertNotIn("camp_night(", source)
        runner = _read("game/autoload/chapter_runner.gd")
        self.assertIn("res://content/chapters/a2_murviedro/world.tscn", runner)
        self.assertIn("res://content/chapters/a2_siege/world.tscn", runner)
        self.assertIn('&"a2_murviedro"', runner)
        self.assertIn('&"a2_siege"', runner)

    def test_zones_do_not_overlap_spawn(self) -> None:
        for rel, zones in (
            (f"{MURV}/world.tscn", (("RoadCutZone", "Box_road"), ("FieldZone", "Box_field"))),
            (f"{SIEGE}/world.tscn", (("StormZone", "Box_storm"), ("RestZone", "Box_rest"))),
        ):
            scene = _read(rel)
            cid = _origin(scene, "Cid")
            horse = _origin(scene, "Horse")
            cid_radius = 0.4
            cid_height = 1.8
            cid_min = (cid[0] - cid_radius, cid[1], cid[2] - cid_radius)
            cid_max = (cid[0] + cid_radius, cid[1] + cid_height, cid[2] + cid_radius)
            horse_min = (horse[0] - 0.5, horse[1], horse[2] - 0.8)
            horse_max = (horse[0] + 0.5, horse[1] + 1.4, horse[2] + 0.8)
            for node_name, shape_id in zones:
                zmin, zmax = _zone_aabb(scene, node_name, shape_id)
                size = _subresource_size(scene, shape_id)
                origin = _origin(scene, node_name)
                self.assertFalse(
                    _aabb_overlap(cid_min, cid_max, zmin, zmax),
                    f"{rel} {node_name} {origin} size {size} overlaps Cid spawn {cid}",
                )
                self.assertFalse(
                    _aabb_overlap(horse_min, horse_max, zmin, zmax),
                    f"{rel} {node_name} overlaps Horse spawn {horse}",
                )

    def test_strings_csv_spanish(self) -> None:
        with (ROOT / "content/locales/strings.csv").open(
            encoding="utf-8", newline=""
        ) as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in (
            "a2_murviedro.roads",
            "a2_murviedro.field",
            "a2_murviedro.take_done",
            "a2_siege.camp",
            "a2_siege.storm_prompt",
            "a2_siege.choice_storm",
            "a2_siege.choice_wait",
            "a2_siege.storm_refused",
            "a2_siege.rest_skip",
            "a2_siege.city_opens",
            "location.murviedro",
            "location.valencia",
        ):
            self.assertIn(key, rows, key)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("Murviedro", rows["a2_murviedro.field"]["es"])
        self.assertIn("escala", rows["a2_murviedro.field"]["es"].lower())
        self.assertIn("Álvar", rows["a2_siege.storm_refused"]["es"])
        self.assertIn("hambre", rows["a2_siege.storm_refused"]["es"].lower())
        self.assertIn("Valencia", rows["a2_siege.city_opens"]["es"])
        poem = _read("content/locales/poem_formulas.csv")
        self.assertIn("a2_murviedro.place_name,Murviedro,", poem)
        self.assertIn("a2_siege.place_name,Valencia,", poem)

    def test_beats_graph_and_jeronimo_next(self) -> None:
        self.assertEqual(validate_main([]), 0)
        murv = json.loads(_read(f"{MURV}/beats.json"))
        self.assertEqual(murv["id"], "a2_murviedro")
        nexts = [step.get("next") for step in murv["steps"] if isinstance(step, dict)]
        self.assertIn("a2_siege", nexts)
        self.assertNotIn("a2_jeronimo", nexts)
        siege = json.loads(_read(f"{SIEGE}/beats.json"))
        self.assertEqual(siege["id"], "a2_siege")
        types = [step.get("type") for step in siege["steps"] if isinstance(step, dict)]
        self.assertIn("clock_segment", types)
        self.assertIn("siege_event", types)
        self.assertIn("honor_event", types)
        self.assertIn("travel_spawn", types)
        segments = [
            step.get("segment")
            for step in siege["steps"]
            if isinstance(step, dict)
        ]
        self.assertIn("siege", segments)
        nexts = [step.get("next") for step in siege["steps"] if isinstance(step, dict)]
        self.assertIn("a2_jeronimo", nexts)
        director = _read("game/chapters/beat_director.gd")
        for step_type in types:
            self.assertIn(f'"{step_type}"', director, step_type)
        graph = load_graph(ROOT / "data" / "chapters" / "graph.json")
        pairs = {(edge["from"], edge["to"]) for edge in graph["edges"]}
        self.assertIn(("a1_tevar", "a2_murviedro"), pairs)
        self.assertIn(("a2_murviedro", "a2_siege"), pairs)
        self.assertIn(("a2_siege", "a2_jeronimo"), pairs)
        self.assertNotIn(("a1_tevar", "a2_siege"), pairs)
        locked = ["hub_lock_cardena"]
        self.assertTrue(can_travel(graph, "a1_tevar", "a2_murviedro", locked))
        self.assertTrue(can_travel(graph, "a2_murviedro", "a2_siege", locked))
        self.assertTrue(can_travel(graph, "a2_siege", "a2_jeronimo", locked))
        self.assertFalse(can_travel(graph, "a1_tevar", "a2_siege", locked))
        self.assertFalse(can_travel(graph, "a2_murviedro", "a2_jeronimo", locked))

    def test_no_denylist_tokens(self) -> None:
        for rel in (
            f"{MURV}/world.gd",
            f"{MURV}/world.tscn",
            f"{MURV}/murviedro.dialogue",
            f"{MURV}/beats.json",
            f"{SIEGE}/world.gd",
            f"{SIEGE}/world.tscn",
            f"{SIEGE}/siege.dialogue",
            f"{SIEGE}/beats.json",
            f"{SIEGE}/storm_prompt.gd",
            "data/siege/valencia_events.json",
            "data/honor_events/siege.json",
            "game/systems/siege/siege_calendar.gd",
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
            for local in (
                Path("/home/lqborges/.local/bin/godot"),
                Path.home() / ".local/bin/godot",
                Path("/tmp/grok-lqborges/deps/godot-unz/Godot_v4.7.2-stable_linux.x86_64"),
            ):
                if local.is_file():
                    godot = str(local)
                    break
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
                "--audio-driver",
                "Dummy",
                "-s",
                "res://tests/unit/test_a2_siege.gd",
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
