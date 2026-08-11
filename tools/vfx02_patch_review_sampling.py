#!/usr/bin/env python3
from pathlib import Path

PATH = Path("scripts/ci/vfx02_canonical_impact_readability_review.gd")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"VFX02_SAMPLING_PATCH=BLOCKED {label} count={count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    text = replace_once(
        text,
        '''\tbattle.player_one.impact_resolved.emit(\n\t\tbattle.player_two,\n\t\tbattle.player_one,\n\t\ttechnique,\n\t\tstate_id,\n\t\t0.0,\n\t\t0.0,\n\t\t0.86,\n\t\tbattle.player_two.global_position + Vector2(0.0, -38.0)\n\t)\n\tawait process_frame\n\tvar layer := feedback.get_node_or_null("CombatFeedbackLayer") as CanvasLayer\n''',
        '''\tbattle.player_one.impact_resolved.emit(\n\t\tbattle.player_two,\n\t\tbattle.player_one,\n\t\ttechnique,\n\t\tstate_id,\n\t\t0.0,\n\t\t0.0,\n\t\t0.86,\n\t\tbattle.player_two.global_position + Vector2(0.0, -38.0)\n\t)\n\t# Camera punch and hitstop are dispatched synchronously by the impact signal.\n\t# Sample them before the next frame, where SHAKE_DECAY may already reduce strength.\n\tvar shake_strength := float(composition.get("_shake_strength"))\n\tvar time_scale_immediate := Engine.time_scale\n\tawait process_frame\n\tvar layer := feedback.get_node_or_null("CombatFeedbackLayer") as CanvasLayer\n''',
        "synchronous_sampling",
    )
    text = replace_once(
        text,
        '''\tvar shake_strength := float(composition.get("_shake_strength"))\n\tvar camera := battle.camera as Camera2D\n''',
        '''\tvar camera := battle.camera as Camera2D\n''',
        "duplicate_shake_declaration",
    )
    text = replace_once(
        text,
        '''\tvar time_scale_immediate := Engine.time_scale\n\tif time_scale_immediate >= 0.99:\n''',
        '''\tif time_scale_immediate >= 0.99:\n''',
        "duplicate_time_scale_declaration",
    )
    PATH.write_text(text, encoding="utf-8")
    print("VFX02_SAMPLING_PATCH=PASS")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
