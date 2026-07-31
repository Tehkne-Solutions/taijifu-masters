from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_DIR = ROOT / "tools" / "playtest"
sys.path.insert(0, str(MODULE_DIR))
SPEC = importlib.util.spec_from_file_location(
    "run_first_playable_pilot", MODULE_DIR / "run_first_playable_pilot.py"
)
guard = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(guard)
core = guard.core


class PilotGuardTests(unittest.TestCase):
    def test_intake_manifest_removes_absolute_paths(self) -> None:
        manifest = {
            "accepted": [
                {
                    "source_path": "/home/person/private/TJFP-001__session.json",
                    "source_name": "TJFP-001__session.json",
                }
            ],
            "rejected": [],
            "privacy": "source_files_unchanged_manifest_only",
        }
        sanitized = guard.sanitize_intake_manifest(manifest)
        entry = sanitized["accepted"][0]
        self.assertNotIn("source_path", entry)
        self.assertEqual(entry["source_reference"], "TJFP-001__session.json")
        self.assertNotIn("/home/person", str(sanitized))

    def test_context_mismatch_is_rejected(self) -> None:
        plan = {"pilot_id": "pilot-09-r1", "build_version": "0.2.1-playtest"}
        intake = {
            "pilot_id": "pilot-different",
            "build_version": "0.2.1-playtest",
        }
        with self.assertRaisesRegex(ValueError, "pilot_id"):
            guard.validate_context(plan, intake=intake)

    def test_resolved_p0_does_not_remain_open(self) -> None:
        backlog = {
            "items": [
                {
                    "id": "observation:soft_lock:abc",
                    "priority": "P0",
                    "resolved": True,
                }
            ],
            "rejected_observations": [],
            "decision_warnings": [],
            "unknown_decision_ids": [],
            "completion_gate": {
                "checks": {
                    "open_p0_allowed": {
                        "required": 0,
                        "actual": 1,
                        "passed": False,
                    }
                }
            },
        }
        hardened = guard.harden_backlog_gate(backlog)
        self.assertEqual(hardened["open_counts"]["P0"], 0)
        self.assertTrue(hardened["completion_gate"]["passed"])

    def test_rejected_observation_blocks_gate(self) -> None:
        backlog = {
            "items": [],
            "rejected_observations": [{"index": 0, "errors": ["PII"]}],
            "decision_warnings": [],
            "unknown_decision_ids": [],
            "completion_gate": {"checks": {}},
        }
        hardened = guard.harden_backlog_gate(backlog)
        self.assertFalse(hardened["completion_gate"]["passed"])
        self.assertEqual(
            hardened["completion_gate"]["checks"]["rejected_observations"]["actual"],
            1,
        )


if __name__ == "__main__":
    unittest.main()
