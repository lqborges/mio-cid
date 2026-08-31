#!/usr/bin/env python3
"""Structural tests for PR-05 SaveService. Run: python3 tests/unit/test_save_hmac.py

gdUnit4 is not vendored yet. This runner plus tests/unit/test_save_hmac.gd
(headless SceneTree) cover HMAC envelope rules until gdUnit4 v6.2.1 is vendored.
"""

from __future__ import annotations

import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DENY = (
    "steam_id",
    "steamid",
    "HTTPRequest",
    "screenshot",
    "cloud_save",
    "Crashlytics",
    "Sentry",
)


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class TestSaveHmac(unittest.TestCase):
    def test_save_service_has_no_class_name(self) -> None:
        source = _read("game/autoload/save_service.gd")
        self.assertRegex(source, re.compile(r"^extends Node$", re.MULTILINE))
        self.assertIsNone(re.search(r"^class_name\s", source, re.MULTILINE))
        self.assertIn("HMACContext", source)
        self.assertIn("HashingContext.HASH_SHA256", source)
        self.assertIn("user://saves", source)
        self.assertIn("FileAccess.open_compressed", source)
        self.assertIn("COMPRESSION_GZIP", source)
        self.assertIn("dir.rename", source)
        self.assertIn("func autosave_chapter(", source)
        self.assertIn("func migrate(", source)

    def test_hmac_is_outside_payload(self) -> None:
        source = _read("game/autoload/save_service.gd")
        self.assertIn('body.erase("hmac")', source)
        self.assertIn('"payload": body', source)
        self.assertIn('"hmac": hmac_hex(body)', source)
        self.assertIn("func hmac_hex(payload: Dictionary) -> String:", source)
        # Digest is a sibling of payload, never a field hashed inside it.
        envelope = re.search(
            r"return \{\s*\"payload\": body,\s*\"hmac\": hmac_hex\(body\),\s*\}",
            source,
            flags=re.MULTILINE,
        )
        self.assertIsNotNone(envelope, "envelope must be {payload, hmac}")
        gd_test = _read("tests/unit/test_save_hmac.gd")
        self.assertIn("hmac must live outside payload", gd_test)
        self.assertIn('payload.has("hmac")', gd_test)

    def test_no_cloud_pii_or_screenshots(self) -> None:
        source = _read("game/autoload/save_service.gd")
        lowered = source.lower()
        for token in DENY:
            self.assertNotIn(token.lower(), lowered, token)
        self.assertNotIn("OS.get_unique_id", source)
        self.assertIn("Never phone home", source)
        self.assertIn("Never a Steam ID", source)

    def test_telemetry_stub_is_opt_in_first_party(self) -> None:
        path = ROOT / "docs" / "telemetry.md"
        self.assertTrue(path.is_file())
        text = path.read_text(encoding="utf-8").lower()
        self.assertIn("opt-in", text)
        self.assertIn("https://telemetry.mio-cid.example/v1/chapter", text)
        self.assertTrue("or none" in text or "compiled out" in text)
        self.assertIn("no steam id", text)
        self.assertIn("no third-party", text)
        self.assertNotIn("sentry", text)
        self.assertNotIn("crashlytics", text)

    def test_event_bus_no_longer_treats_save_as_stub(self) -> None:
        source = _read("tests/unit/test_event_bus.py")
        stubs_block = source.split("STUBS = {", 1)[1].split("}", 1)[0]
        self.assertNotIn("SaveService", stubs_block)

    def test_godot_headless_save_hmac_if_available(self) -> None:
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
                "res://tests/unit/test_save_hmac.gd",
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
