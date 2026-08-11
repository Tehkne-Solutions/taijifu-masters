#!/usr/bin/env python3
from pathlib import Path

PATH = Path("scripts/vertical_slice/first_playable.gd")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"AUDIO02_PATCH=BLOCKED {label} count={count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = PATH.read_text(encoding="utf-8")

    text = replace_once(
        text,
        "class_name FirstPlayableController\nextends Node2D\n\nconst FIGHTER_SCENE",
        "class_name FirstPlayableController\nextends Node2D\n\nsignal presentation_cue_requested(cue_id: StringName, intensity: float)\n\nconst FIGHTER_SCENE",
        "presentation_signal",
    )

    text = replace_once(
        text,
        "\t\tcenter_label.text = str(value)\n\t\tawait get_tree().create_timer(countdown_step_seconds, false).timeout",
        "\t\tcenter_label.text = str(value)\n\t\tpresentation_cue_requested.emit(&\"countdown\", clampf(float(value) / float(COUNTDOWN_SECONDS), 0.45, 1.0))\n\t\tawait get_tree().create_timer(countdown_step_seconds, false).timeout",
        "countdown_cue",
    )

    text = replace_once(
        text,
        "\tcenter_label.text = \"LUTEM\"\n\tawait get_tree().create_timer(fight_command_seconds, false).timeout",
        "\tcenter_label.text = \"LUTEM\"\n\tpresentation_cue_requested.emit(&\"fight\", 1.0)\n\tawait get_tree().create_timer(fight_command_seconds, false).timeout",
        "fight_cue",
    )

    text = replace_once(
        text,
        "\tvar reason_id := StringName(reason.to_lower())\n\t_telemetry.record_event(winner_profile_id, &\"match_won\", reason_id)",
        "\tvar reason_id := StringName(reason.to_lower())\n\tif reason_id == &\"ko\":\n\t\tpresentation_cue_requested.emit(&\"ko\", 1.0)\n\telif reason_id == &\"tempo\":\n\t\tpresentation_cue_requested.emit(&\"timeout\", 0.88)\n\tpresentation_cue_requested.emit(&\"round_win\" if player_won else &\"round_loss\", 1.0)\n\t_telemetry.record_event(winner_profile_id, &\"match_won\", reason_id)",
        "result_cues",
    )

    text = replace_once(
        text,
        "\tget_tree().paused = active\n\tif _state == MatchState.COUNTDOWN or _state == MatchState.BATTLE:",
        "\tget_tree().paused = active\n\tpresentation_cue_requested.emit(&\"ui_pause\" if active else &\"ui_resume\", 0.72)\n\tif _state == MatchState.COUNTDOWN or _state == MatchState.BATTLE:",
        "pause_resume_cues",
    )

    text = replace_once(
        text,
        "\t_feedback_submitted = true\n\t_last_telemetry_path = _telemetry.annotate_last_round({",
        "\t_feedback_submitted = true\n\tpresentation_cue_requested.emit(&\"ui_confirm\", 0.78)\n\t_last_telemetry_path = _telemetry.annotate_last_round({",
        "feedback_cue",
    )

    text = replace_once(
        text,
        "\tDisplayServer.clipboard_set(report)\n\thud_controller.set_report_status(",
        "\tDisplayServer.clipboard_set(report)\n\tpresentation_cue_requested.emit(&\"ui_confirm\", 0.72)\n\thud_controller.set_report_status(",
        "report_cue",
    )

    text = replace_once(
        text,
        "\t_telemetry.record_event(&\"p1\", &\"difficulty_changed\", difficulty_id)\n",
        "\t_telemetry.record_event(&\"p1\", &\"difficulty_changed\", difficulty_id)\n\tpresentation_cue_requested.emit(&\"ui_select\", 0.68)\n",
        "difficulty_cue",
    )

    PATH.write_text(text, encoding="utf-8")
    print("AUDIO02_PATCH=PASS")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
