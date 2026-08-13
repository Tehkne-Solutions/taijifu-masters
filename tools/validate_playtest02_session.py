#!/usr/bin/env python3
import json
import sys
from pathlib import Path

SIGNATURE = "Tehkné Solutions"
ALLOWED_VERDICTS = {"PASS", "PASS_WITH_NOTES", "FAIL"}
REQUIRED_SCORES = [
    "movement_feel",
    "combat_clarity",
    "impact_feel",
    "camera_comfort",
    "ai_engagement",
    "difficulty_fairness",
    "visual_readability",
    "audio_feedback",
    "fun",
]
REQUIRED_NOTES = [
    "best_moment",
    "worst_moment",
    "most_confusing_moment",
    "one_change_before_next_slice",
]


def block(reason: str) -> int:
    print(f"PLAYTEST02_SESSION=BLOCKED reason={reason}")
    return 1


def main() -> int:
    if len(sys.argv) != 2:
        return block("usage_expected_single_json_path")

    path = Path(sys.argv[1])
    if not path.is_file():
        return block("session_file_missing")

    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception:
        return block("invalid_json")

    if data.get("signature") != SIGNATURE:
        return block("signature")
    if data.get("schema") != "tehkne/taijifu-playtest02-session/v1":
        return block("schema")
    if data.get("stage") != "PLAYTEST-02":
        return block("stage")
    if data.get("session_complete") is not True:
        return block("session_incomplete")
    if data.get("runtime_health_present") is not True:
        return block("runtime_health_missing")

    scores = data.get("scores")
    if not isinstance(scores, dict):
        return block("scores_missing")
    for key in REQUIRED_SCORES:
        value = scores.get(key)
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return block(f"score_missing_{key}")
        if value < 1 or value > 5:
            return block(f"score_out_of_range_{key}")

    notes = data.get("notes")
    if not isinstance(notes, dict):
        return block("notes_missing")
    for key in REQUIRED_NOTES:
        value = notes.get(key)
        if not isinstance(value, str) or not value.strip():
            return block(f"note_missing_{key}")

    verdict = data.get("human_verdict")
    if verdict not in ALLOWED_VERDICTS:
        return block("human_verdict_missing_or_invalid")

    print("PLAYTEST02_SESSION_STRUCTURE=PASS")
    print("PLAYTEST02_HUMAN_SCORES=PASS count=9")
    print("PLAYTEST02_HUMAN_NOTES=PASS count=4")
    print(f"PLAYTEST02_HUMAN_VERDICT={verdict}")
    print("PLAYTEST02_SESSION=PASS")
    print(f"SIGNATURE={SIGNATURE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
