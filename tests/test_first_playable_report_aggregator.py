from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "playtest" / "aggregate_first_playable_reports.py"
SPEC = importlib.util.spec_from_file_location("first_playable_aggregator", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
aggregator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(aggregator)


def event(event_id: str) -> dict:
    return {
        "at_msec": 10,
        "profile_id": "p1",
        "event_id": event_id,
        "value_id": "",
        "amount": 1.0,
    }


def round_data(
    difficulty: str,
    winner: str,
    feedback: str | None,
    duration_seconds: float,
    *,
    reason: str = "ko",
    rematch: bool = False,
    pauses: int = 0,
) -> dict:
    metadata = {
        "difficulty_id": difficulty,
        "difficulty_label": difficulty.upper(),
        "result_reason": reason,
        "player_won": winner == "p1",
        "elapsed_seconds": duration_seconds,
        "rematch_requested": rematch,
    }
    if feedback is not None:
        metadata["balance_feedback"] = feedback
    return {
        "round_index": 1,
        "duration_msec": int(duration_seconds * 1000),
        "winner_profile_id": winner,
        "metadata": metadata,
        "players": {"p1": {}, "p2": {}},
        "events": [event("pause") for _ in range(pauses)]
        + [event("resume") for _ in range(pauses)],
    }


def session(session_id: str, platform: str, rounds: list[dict]) -> dict:
    return {
        "schema": aggregator.TELEMETRY_SCHEMA,
        "version": 3,
        "session_id": session_id,
        "started_unix": 1785450000,
        "updated_unix": 1785450100,
        "metadata": {
            "experience": "first_playable",
            "build_version": "0.2.0-first-playable",
            "platform": platform,
            "locale": "pt_BR",
            "privacy": "local_only",
            "signature": "Tehkné Solutions",
        },
        "rounds": rounds,
    }


class FirstPlayableAggregatorTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.input_dir = self.root / "reports"
        self.output_dir = self.root / "summary"
        self.input_dir.mkdir()

        apprentice = session(
            "apprentice-session",
            "Windows",
            [
                round_data("apprentice", "p2", "too_hard", 48.0, pauses=1),
                round_data("apprentice", "p2", "too_hard", 52.0),
                round_data("apprentice", "p1", "balanced", 44.0),
            ],
        )
        disciple = session(
            "disciple-session",
            "Web",
            [
                round_data("disciple", "p1", "balanced", 61.0, rematch=True),
                round_data("disciple", "p2", "balanced", 67.0),
            ],
        )
        master = session(
            "master-session",
            "Windows",
            [
                round_data("master", "p1", "too_easy", 38.0),
                round_data("master", "p1", "too_easy", 41.0),
                round_data("master", "p1", "too_easy", 43.0),
                round_data(
                    "master",
                    "",
                    None,
                    12.0,
                    reason="abandoned",
                ),
            ],
        )
        for filename, payload in (
            ("apprentice.json", apprentice),
            ("disciple.json", disciple),
            ("master.json", master),
        ):
            (self.input_dir / filename).write_text(
                json.dumps(payload, ensure_ascii=False), encoding="utf-8"
            )
        (self.input_dir / "invalid.json").write_text(
            '{"schema": "legacy", "rounds": []}', encoding="utf-8"
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_aggregates_sessions_and_generates_actionable_signals(self) -> None:
        exit_code = aggregator.run(
            [str(self.input_dir), "--output-dir", str(self.output_dir)]
        )
        self.assertEqual(exit_code, 0)

        json_path = self.output_dir / aggregator.JSON_OUTPUT_NAME
        markdown_path = self.output_dir / aggregator.MARKDOWN_OUTPUT_NAME
        self.assertTrue(json_path.is_file())
        self.assertTrue(markdown_path.is_file())

        summary = json.loads(json_path.read_text(encoding="utf-8"))
        self.assertEqual(summary["schema"], aggregator.SUMMARY_SCHEMA)
        self.assertEqual(summary["signature"], "Tehkné Solutions")
        self.assertEqual(summary["inputs"]["candidate_json_files"], 4)
        self.assertEqual(summary["inputs"]["valid_sessions"], 3)
        self.assertEqual(summary["inputs"]["invalid_or_ignored_files"], 1)
        self.assertEqual(summary["totals"]["rounds"], 9)
        self.assertEqual(summary["totals"]["abandoned_rounds"], 1)
        self.assertAlmostEqual(summary["totals"]["abandonment_rate"], 1 / 9, places=4)
        self.assertEqual(summary["totals"]["pauses"], 1)
        self.assertEqual(summary["totals"]["resumes"], 1)
        self.assertEqual(summary["totals"]["rematches"], 1)

        apprentice = summary["by_difficulty"]["apprentice"]
        self.assertEqual(apprentice["rounds"], 3)
        self.assertEqual(apprentice["player_wins"], 1)
        self.assertEqual(apprentice["feedback"]["too_hard"], 2)
        self.assertEqual(apprentice["median_duration_seconds"], 48.0)

        disciple = summary["by_difficulty"]["disciple"]
        self.assertEqual(disciple["rematches"], 1)
        self.assertEqual(disciple["feedback"]["balanced"], 2)

        master = summary["by_difficulty"]["master"]
        self.assertEqual(master["player_wins"], 3)
        self.assertEqual(master["feedback"]["too_easy"], 3)
        self.assertEqual(master["abandoned_rounds"], 1)

        signal_ids = {signal["id"] for signal in summary["quality_signals"]}
        self.assertIn("sample_size_low", signal_ids)
        self.assertIn("apprentice_too_hard", signal_ids)
        self.assertIn("master_too_easy", signal_ids)
        self.assertNotIn("abandonment_high", signal_ids)
        self.assertTrue(any("schema incompatível" in item for item in summary["warnings"]))

        markdown = markdown_path.read_text(encoding="utf-8")
        self.assertIn("## Por dificuldade", markdown)
        self.assertIn("Aprendiz", markdown)
        self.assertIn("Mestre", markdown)
        self.assertIn("Tehkné Solutions", markdown)

    def test_fail_on_invalid_returns_nonzero_but_keeps_outputs(self) -> None:
        exit_code = aggregator.run(
            [
                str(self.input_dir),
                "--output-dir",
                str(self.output_dir),
                "--fail-on-invalid",
            ]
        )
        self.assertEqual(exit_code, 3)
        self.assertTrue((self.output_dir / aggregator.JSON_OUTPUT_NAME).is_file())
        self.assertTrue((self.output_dir / aggregator.MARKDOWN_OUTPUT_NAME).is_file())

    def test_returns_error_when_no_valid_session_exists(self) -> None:
        empty_dir = self.root / "empty"
        empty_dir.mkdir()
        (empty_dir / "wrong.json").write_text("[]", encoding="utf-8")
        exit_code = aggregator.run(
            [str(empty_dir), "--output-dir", str(self.output_dir)]
        )
        self.assertEqual(exit_code, 2)
        self.assertFalse((self.output_dir / aggregator.JSON_OUTPUT_NAME).exists())


if __name__ == "__main__":
    unittest.main()
