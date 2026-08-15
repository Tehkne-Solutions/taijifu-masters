#!/usr/bin/env python3
"""Contract tests for the active First Playable pilot r2.

Signature: Tehkné Solutions
"""
from __future__ import annotations

import importlib.util
import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACTIVE_PILOT = "pilot-09-r2"
ACTIVE_VERSION = "0.2.3-playtest"


def load_json(path: Path) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise AssertionError(f"{path}: JSON root must be an object")
    return payload


def load_hardened_cli():
    module_dir = ROOT / "tools" / "playtest"
    module_path = module_dir / "run_first_playable_pilot.py"
    sys.path.insert(0, str(module_dir))
    try:
        spec = importlib.util.spec_from_file_location(
            "run_first_playable_pilot_r2", module_path
        )
        if spec is None or spec.loader is None:
            raise AssertionError("Could not load hardened pilot CLI")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        sys.path.remove(str(module_dir))


class FirstPlayablePilotR2Tests(unittest.TestCase):
    def test_project_and_runtime_point_to_r2(self) -> None:
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        version_match = re.search(r'^config/version="([^"]+)"$', project, re.MULTILINE)
        self.assertIsNotNone(version_match)
        self.assertEqual(version_match.group(1), ACTIVE_VERSION)

        session = (
            ROOT / "scripts" / "vertical_slice" / "first_playable_session.gd"
        ).read_text(encoding="utf-8")
        self.assertIn(f'const PILOT_ID := "{ACTIVE_PILOT}"', session)
        self.assertIn('const PARTICIPANT_PREFIX := "TJFP-"', session)
        self.assertIn("static func begin_pilot_session", session)
        self.assertIn("pilot_enforcement_enabled", session)

        telemetry = (
            ROOT / "scripts" / "telemetry" / "match_telemetry.gd"
        ).read_text(encoding="utf-8")
        self.assertIn('"participant_code"', telemetry)
        self.assertIn('"pilot_id"', telemetry)
        self.assertIn('return "%s__" % participant_code', telemetry)
        self.assertIn('"pilot_sequence_valid"', telemetry)
        self.assertIn('CANONICAL_FIRST_PLAYABLE_ARENA := "Mountain Dojo Night"', telemetry)

        menu = (
            ROOT / "scripts" / "vertical_slice" / "first_playable_menu.gd"
        ).read_text(encoding="utf-8")
        self.assertNotIn('DEFAULT_PARTICIPANT_CODE := "TJFP-001"', menu)
        self.assertIn('"participant_code_auto_assigned": false', menu)
        self.assertIn("FirstPlayableSession.begin_pilot_session", menu)

        pickups = (
            ROOT / "scripts" / "runtime" / "procedural_arena_pickup_runtime.gd"
        ).read_text(encoding="utf-8")
        self.assertIn("_fighters.clear()", pickups)
        self.assertIn("_collect_fighters(current_scene, found)", pickups)
        self.assertNotIn("_collect_fighters(get_tree().root, found)", pickups)

    def test_active_fixture_is_complete_and_anonymous(self) -> None:
        pilot_dir = ROOT / "playtest" / "pilots" / ACTIVE_PILOT
        plan = load_json(pilot_dir / "pilot-plan.json")
        observations = load_json(pilot_dir / "pilot-observations.json")
        decisions = load_json(pilot_dir / "pilot-decisions.json")

        self.assertEqual(plan["pilot_id"], ACTIVE_PILOT)
        self.assertEqual(plan["build_version"], ACTIVE_VERSION)
        self.assertEqual(plan["signature"], "Tehkné Solutions")
        self.assertEqual(plan["participant_count"], 9)
        self.assertEqual(plan["expected_total_matches"], 54)
        self.assertEqual(plan["platform_targets"], {"web": 3, "windows": 6})
        self.assertEqual(
            plan["starting_difficulty_distribution"],
            {"apprentice": 3, "disciple": 3, "master": 3},
        )

        participants = plan["participants"]
        participant_ids = [item["participant_id"] for item in participants]
        self.assertEqual(len(participant_ids), 9)
        self.assertEqual(len(set(participant_ids)), 9)
        self.assertEqual(participant_ids[0], "TJFP-001")
        self.assertEqual(participant_ids[-1], "TJFP-009")
        for item in participants:
            self.assertRegex(item["participant_id"], r"^TJFP-\d{3}$")
            self.assertEqual(
                item["report_filename_prefix"],
                f"{item['participant_id']}__",
            )
            self.assertIn(
                "download_or_locate_local_json",
                item["required_checks"],
            )

        self.assertEqual(observations["pilot_id"], ACTIVE_PILOT)
        self.assertEqual(observations["build_version"], ACTIVE_VERSION)
        self.assertEqual(observations["observations"], [])
        self.assertEqual(decisions["pilot_id"], ACTIVE_PILOT)
        self.assertEqual(decisions["build_version"], ACTIVE_VERSION)
        self.assertEqual(decisions["decisions"], [])

    def test_hardened_cli_resolves_project_version(self) -> None:
        cli = load_hardened_cli()
        self.assertEqual(cli.project_build_version(), ACTIVE_VERSION)

    def test_r1_fixture_remains_historical(self) -> None:
        historical = load_json(
            ROOT / "playtest" / "pilots" / "pilot-09-r1" / "pilot-plan.json"
        )
        self.assertEqual(historical["pilot_id"], "pilot-09-r1")
        self.assertEqual(historical["build_version"], "0.2.1-playtest")


if __name__ == "__main__":
    unittest.main()
