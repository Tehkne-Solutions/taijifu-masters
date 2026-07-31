from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "playtest" / "first_playable_pilot.py"
SPEC = importlib.util.spec_from_file_location("first_playable_pilot", MODULE_PATH)
pilot = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(pilot)


def telemetry(session_id: str, feedback: str = "balanced") -> dict:
    return {
        "schema": pilot.TELEMETRY_SCHEMA,
        "version": 3,
        "session_id": session_id,
        "started_unix": 1785450000,
        "metadata": {
            "experience": "first_playable",
            "build_version": pilot.BUILD_VERSION,
            "platform": "Windows",
            "locale": "pt_BR",
            "privacy": "local_only",
            "signature": pilot.SIGNATURE,
        },
        "rounds": [
            {
                "round_index": 1,
                "duration_msec": 32000,
                "winner_profile_id": "p1",
                "metadata": {
                    "difficulty_id": "disciple",
                    "result_reason": "ko",
                    "player_won": True,
                    "balance_feedback": feedback,
                    "winner_character": "Lian Wu",
                    "p1_final": {"character": "Lian Wu", "health": 45},
                },
                "players": {"p1": {}, "p2": {}},
                "events": [],
            }
        ],
    }


def intake_for(plan: dict, participants: list[str]) -> dict:
    return {
        "schema": pilot.INTAKE_SCHEMA,
        "participant_session_counts": {participant: 1 for participant in participants},
    }


def empty_decisions(plan: dict) -> dict:
    return {
        "schema": pilot.DECISIONS_SCHEMA,
        "pilot_id": plan["pilot_id"],
        "decisions": [],
    }


class PilotPlanTests(unittest.TestCase):
    def test_plan_balances_platforms_and_starting_difficulties(self) -> None:
        plan = pilot.build_plan("pilot-001", 9)
        self.assertEqual(plan["participant_count"], 9)
        self.assertEqual(plan["platform_targets"], {"web": 3, "windows": 6})
        self.assertEqual(
            plan["starting_difficulty_distribution"],
            {"apprentice": 3, "disciple": 3, "master": 3},
        )
        ids = [item["participant_id"] for item in plan["participants"]]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(ids[0], "TJFP-001")
        self.assertEqual(ids[-1], "TJFP-009")


class PilotIntakeTests(unittest.TestCase):
    def test_intake_accepts_valid_and_rejects_duplicate_and_pii(self) -> None:
        plan = pilot.build_plan("pilot-001", 6)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            valid_path = root / "TJFP-001__session.json"
            duplicate_path = root / "TJFP-002__duplicate.json"
            pii_path = root / "TJFP-003__pii.json"
            valid_path.write_text(json.dumps(telemetry("session-001")), encoding="utf-8")
            duplicate_path.write_text(json.dumps(telemetry("session-001")), encoding="utf-8")
            pii_payload = telemetry("session-003")
            pii_payload["contact_email"] = "tester@example.com"
            pii_path.write_text(json.dumps(pii_payload), encoding="utf-8")

            manifest = pilot.build_intake_manifest([root], plan)
            self.assertEqual(manifest["inputs"]["candidate_files"], 3)
            self.assertEqual(manifest["inputs"]["accepted_files"], 1)
            self.assertEqual(manifest["inputs"]["rejected_files"], 2)
            reasons = " ".join(
                error for entry in manifest["rejected"] for error in entry["errors"]
            )
            self.assertIn("session_id duplicado", reasons)
            self.assertIn("possível PII detectada", reasons)
            self.assertEqual(
                valid_path.read_text(encoding="utf-8"),
                json.dumps(telemetry("session-001")),
            )

    def test_intake_rejects_report_without_anonymous_code(self) -> None:
        plan = pilot.build_plan("pilot-001", 6)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / "session.json"
            path.write_text(json.dumps(telemetry("session-001")), encoding="utf-8")
            manifest = pilot.build_intake_manifest([root], plan)
            self.assertEqual(manifest["inputs"]["accepted_files"], 0)
            self.assertIn("código TJFP-### ausente", manifest["rejected"][0]["errors"][0])


class PilotBacklogTests(unittest.TestCase):
    def test_triage_maps_blocker_to_p0_and_quantitative_signal_to_p1(self) -> None:
        plan = pilot.build_plan("pilot-001", 6)
        summary = {
            "schema": pilot.SUMMARY_SCHEMA,
            "totals": {"completed_rounds": 30, "feedback_coverage": 0.8},
            "by_difficulty": {
                "apprentice": {"rounds": 10},
                "disciple": {"rounds": 10},
                "master": {"rounds": 10},
            },
            "quality_signals": [
                {
                    "id": "abandonment_high",
                    "severity": "critical",
                    "message": "Abandono acima do limite.",
                }
            ],
        }
        observations = {
            "schema": pilot.OBSERVATIONS_SCHEMA,
            "observations": [
                {
                    "participant_id": "TJFP-001",
                    "title": "Partida trava na revanche",
                    "category": "soft_lock",
                    "description": "A tela fica bloqueada após clicar em revanche.",
                    "reproduction": "Concluir luta e clicar em revanche duas vezes.",
                    "severity": "blocker",
                    "platform": "windows",
                    "difficulty": "disciple",
                },
                {
                    "participant_id": "TJFP-002",
                    "title": "Partida trava na revanche",
                    "category": "soft_lock",
                    "description": "A revanche não inicia.",
                    "severity": "blocker",
                    "platform": "windows",
                    "difficulty": "disciple",
                },
            ],
        }
        backlog = pilot.build_backlog(
            summary,
            observations,
            plan,
            intake_for(
                plan,
                ["TJFP-001", "TJFP-002", "TJFP-003", "TJFP-004", "TJFP-005", "TJFP-006"],
            ),
            empty_decisions(plan),
        )
        self.assertEqual(backlog["counts"]["P0"], 1)
        self.assertEqual(backlog["counts"]["P1"], 1)
        p0 = next(item for item in backlog["items"] if item["priority"] == "P0")
        self.assertEqual(p0["occurrences"], 2)
        self.assertEqual(p0["participants"], ["TJFP-001", "TJFP-002"])
        self.assertFalse(backlog["completion_gate"]["passed"])

    def test_p1_decision_can_satisfy_decision_gate(self) -> None:
        plan = pilot.build_plan("pilot-001", 6)
        summary = {
            "schema": pilot.SUMMARY_SCHEMA,
            "totals": {"completed_rounds": 30, "feedback_coverage": 0.9},
            "by_difficulty": {
                "apprentice": {"rounds": 10},
                "disciple": {"rounds": 10},
                "master": {"rounds": 10},
            },
            "quality_signals": [
                {"id": "abandonment_high", "severity": "critical", "message": "Abandono alto."}
            ],
        }
        observations = {"schema": pilot.OBSERVATIONS_SCHEMA, "observations": []}
        decisions = {
            "schema": pilot.DECISIONS_SCHEMA,
            "decisions": [
                {
                    "backlog_item_id": "signal:abandonment_high",
                    "status": "accepted",
                    "rationale": "Correção agendada para a próxima build.",
                    "target_version": "0.2.2",
                }
            ],
        }
        backlog = pilot.build_backlog(
            summary,
            observations,
            plan,
            intake_for(plan, [f"TJFP-{index:03d}" for index in range(1, 7)]),
            decisions,
        )
        self.assertEqual(
            backlog["completion_gate"]["checks"]["p1_without_decision"]["actual"],
            0,
        )
        self.assertTrue(backlog["completion_gate"]["passed"])

    def test_observation_with_pii_is_rejected(self) -> None:
        plan = pilot.build_plan("pilot-001", 6)
        summary = {
            "schema": pilot.SUMMARY_SCHEMA,
            "totals": {"completed_rounds": 0, "feedback_coverage": 0.0},
            "by_difficulty": {},
            "quality_signals": [],
        }
        observations = {
            "schema": pilot.OBSERVATIONS_SCHEMA,
            "observations": [
                {
                    "participant_id": "TJFP-001",
                    "title": "Contato tester@example.com",
                    "category": "clarity",
                    "description": "Texto contém e-mail.",
                    "severity": "minor",
                }
            ],
        }
        backlog = pilot.build_backlog(
            summary,
            observations,
            plan,
            intake_for(plan, ["TJFP-001"]),
            empty_decisions(plan),
        )
        self.assertEqual(backlog["valid_observations"], 0)
        self.assertEqual(len(backlog["rejected_observations"]), 1)


if __name__ == "__main__":
    unittest.main()
