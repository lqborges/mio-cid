#!/usr/bin/env python3
"""Structural tests for PR-34 SpeechTrial runtime.

Run: python3 tests/unit/test_speech_trial.py
"""

from __future__ import annotations

import csv
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PUY_DENY = ("puy", "babieca", "santa_gadea", "espadero", "stornetta", "flute")
CHROME_KEYS = (
    "speech.ui.retry",
    "speech.ui.skip_blocked",
    "speech.ui.steel",
    "speech.ui.won",
    "speech.ui.failed",
)


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestSpeechResources(unittest.TestCase):
    def test_speech_line_fields(self) -> None:
        source = _read("game/systems/speech/speech_line.gd")
        self.assertRegex(source, re.compile(r"^class_name SpeechLine$", re.MULTILINE))
        self.assertIn("@export var legal: float = 0.0", source)
        self.assertIn("@export var mesura: float = 0.0", source)
        self.assertIn("@export var ira: float = 0.0", source)
        self.assertIn("@export var tags: PackedStringArray", source)
        self.assertIn("@export var vo_id: StringName", source)
        self.assertIn("func has_tag", source)
        self.assertNotIn("win_threshold", source)
        self.assertNotIn("counts_toward_win", source)

    def test_speech_ask_counts_toward_win_not_threshold(self) -> None:
        source = _read("game/systems/speech/speech_ask.gd")
        self.assertRegex(source, re.compile(r"^class_name SpeechAsk$", re.MULTILINE))
        self.assertIn("@export var counts_toward_win: bool = true", source)
        self.assertIn("Array[SpeechLine]", source)
        self.assertIn("func get_line", source)
        self.assertNotIn("win_threshold", source)
        self.assertNotIn("assert", source)

    def test_win_threshold_lives_on_trial(self) -> None:
        source = _read("game/systems/speech/speech_trial.gd")
        self.assertRegex(source, re.compile(r"^class_name SpeechTrial$", re.MULTILINE))
        self.assertIn("@export var win_threshold: float = 12.0", source)
        self.assertIn("extends Node", source)
        ask = _read("game/systems/speech/speech_ask.gd")
        self.assertNotIn("win_threshold", ask)
        line = _read("game/systems/speech/speech_line.gd")
        self.assertNotIn("win_threshold", line)


class TestSpeechTrialRules(unittest.TestCase):
    def test_retry_does_not_commit(self) -> None:
        source = _read("game/systems/speech/speech_trial.gd")
        self.assertIn("var net := line.legal - line.ira", source)
        self.assertIn("if net < 0.0:", source)
        self.assertIn("ask_retry.emit(_index)", source)
        retry_block = source.split("if net < 0.0:", 1)[1].split("if ask.counts_toward_win:", 1)[0]
        self.assertIn("return", retry_block)
        self.assertNotIn("legal_score +=", retry_block)
        self.assertNotIn("_index +=", retry_block)

    def test_ask_order_locked(self) -> None:
        source = _read("game/systems/speech/speech_trial.gd")
        self.assertIn("if ask_index != _index", source)
        self.assertIn("skip_blocked.emit()", source)
        self.assertNotIn("assert(", source)
        self.assertNotIn("assert ", source)

    def test_skip_to_riepto_is_mesura_fail(self) -> None:
        source = _read("game/systems/speech/speech_trial.gd")
        self.assertIn('has_tag(&"skip_to_riepto")', source)
        self.assertIn("third_ask_allowed = false", source)
        self.assertIn("skip_blocked.emit()", source)
        self.assertIn("elif _index == 2 and not third_ask_allowed:", source)
        self.assertIn("trial_failed.emit()", source)

    def test_steel_in_hall_fails(self) -> None:
        source = _read("game/systems/speech/speech_trial.gd")
        self.assertIn('has_tag(&"draw_steel")', source)
        self.assertIn("steel_drawn_fail.emit()", source)
        self.assertIn('STEEL_FAIL := &"steel_in_cortes"', source)
        self.assertIn("hard_fail.emit", source)
        self.assertIn("trial_failed.emit()", source)
        self.assertIn("_event_bus()", source)

    def test_not_an_autoload(self) -> None:
        project = _read("project.godot")
        self.assertNotIn("speech_trial.gd", project)
        self.assertNotIn("SpeechTrial=", project)
        autoload = _read("game/autoload/event_bus.gd")
        self.assertIsNone(re.search(r"^class_name\s", autoload, re.MULTILINE))

    def test_garcia_is_separate_in_tests(self) -> None:
        gd = _read("tests/unit/test_speech_trial.gd")
        self.assertIn("pressed.emit()", gd)
        self.assertIn("_test_press_line_does_not_free_emitter", gd)
        self.assertIn("garcia_preliminary", gd)
        self.assertIn("_garcia_trial", gd)
        self.assertIn("counts_toward_win", gd)
        self.assertIn("must not share _index or legal_score", gd)
        self.assertNotIn("content/chapters/a3_toledo", gd)
        self.assertNotIn("querella.json", gd)


class TestSpeechUI(unittest.TestCase):
    def test_scene_is_control_without_timer(self) -> None:
        tscn = _read("game/ui/speech_trial.tscn")
        self.assertIn('[node name="SpeechTrialUI" type="Control"]', tscn)
        self.assertNotIn("Timer", tscn)
        self.assertNotIn("TextureRect", tscn)
        self.assertNotIn("Texture2D", tscn)
        self.assertIn("PromptEn", tscn)
        self.assertIn("StatusEn", tscn)
        ui = _read("game/ui/speech_trial.gd")
        self.assertRegex(ui, re.compile(r"^class_name SpeechTrialUI$", re.MULTILINE))
        self.assertIn("text_in", ui)
        self.assertIn("_loc_es", ui)
        self.assertIn("_loc_en", ui)
        self.assertIn('call("text_in", key, "es")', ui)
        self.assertIn('call("text_in", key, "en")', ui)
        self.assertIn("child.queue_free()", ui)
        self.assertNotIn("child.free()", ui)
        self.assertNotIn("Timer", ui)
        self.assertNotIn("create_timer", ui)

    def test_chrome_keys_have_spanish_and_english(self) -> None:
        path = ROOT / "content/locales/strings.csv"
        with path.open(encoding="utf-8", newline="") as handle:
            rows = {row["key"]: row for row in csv.DictReader(handle)}
        for key in CHROME_KEYS:
            self.assertIn(key, rows)
            self.assertTrue(rows[key]["es"].strip(), key)
            self.assertTrue(rows[key]["en"].strip(), key)
        self.assertIn("taberna", rows["speech.ui.retry"]["es"])
        self.assertIn("tavern", rows["speech.ui.retry"]["en"])
        self.assertIn("riepto", rows["speech.ui.skip_blocked"]["es"])
        self.assertIn("mesura", rows["speech.ui.skip_blocked"]["es"])

    def test_querella_still_ships(self) -> None:
        self.assertTrue((ROOT / "data/speech/querella.json").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_valencia_wait/world.tscn").is_file())
        self.assertTrue((ROOT / "content/chapters/a3_carrion/world.tscn").is_file())

    def test_denylist(self) -> None:
        files = [
            "game/systems/speech/speech_trial.gd",
            "game/systems/speech/speech_ask.gd",
            "game/systems/speech/speech_line.gd",
            "game/ui/speech_trial.gd",
            "game/ui/speech_trial.tscn",
            "tests/unit/test_speech_trial.gd",
            "content/locales/strings.csv",
        ]
        for rel in files:
            lowered = _read(rel).lower()
            for token in PUY_DENY:
                self.assertNotIn(token, lowered, rel)

    def test_loc_text_in_for_subtitles(self) -> None:
        source = _read("game/autoload/loc.gd")
        self.assertIn("func text_in(key: String, loc: String) -> String:", source)
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))


class TestHeadless(unittest.TestCase):
    def test_godot_headless_speech_trial_if_available(self) -> None:
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
                "res://tests/unit/test_speech_trial.gd",
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
