from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "playtest" / "first_playable_pilot.py"
PLAN_PATH = ROOT / "playtest" / "pilots" / "pilot-09-r1" / "pilot-plan.json"
SPEC = importlib.util.spec_from_file_location("first_playable_pilot", MODULE_PATH)
pilot = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(pilot)


class OfficialPilotFixtureTests(unittest.TestCase):
    def test_official_plan_matches_generator_contract(self) -> None:
        actual = json.loads(PLAN_PATH.read_text(encoding="utf-8"))
        expected = pilot.build_plan(
            pilot_id="pilot-09-r1",
            participants=9,
            windows_share=0.6666667,
            matches_per_difficulty=2,
        )
        actual.pop("generated_at_utc", None)
        expected.pop("generated_at_utc", None)
        self.assertEqual(actual, expected)

    def test_templates_start_without_fabricated_results(self) -> None:
        observations = json.loads(
            (PLAN_PATH.parent / "pilot-observations.json").read_text(encoding="utf-8")
        )
        decisions = json.loads(
            (PLAN_PATH.parent / "pilot-decisions.json").read_text(encoding="utf-8")
        )
        self.assertEqual(observations["observations"], [])
        self.assertEqual(decisions["decisions"], [])


if __name__ == "__main__":
    unittest.main()
