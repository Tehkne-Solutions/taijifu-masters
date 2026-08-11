#!/usr/bin/env python3
from pathlib import Path

PATH = Path("scripts/runtime/impact_director.gd")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"VFX01_PATCH=BLOCKED {label} count={count}")
    return text.replace(old, new, 1)


def remove_block(text: str, start_marker: str, end_marker: str, label: str) -> str:
    start = text.find(start_marker)
    end = text.find(end_marker, start + 1)
    if start < 0 or end < 0 or end <= start:
        raise SystemExit(f"VFX01_PATCH=BLOCKED {label}")
    return text[:start] + text[end:]


def main() -> None:
    text = PATH.read_text(encoding="utf-8")

    text = replace_once(
        text,
        '@onready var camera: Camera2D = get_node("../Camera2D")\n\n',
        '',
        'camera_reference',
    )
    text = replace_once(
        text,
        'var _shake_time := 0.0\nvar _shake_duration := 0.0\nvar _shake_amplitude := 0.0\nvar _base_camera_offset := Vector2.ZERO\n',
        '',
        'shake_state',
    )
    text = replace_once(
        text,
        '\tz_index = 80\n\tif is_instance_valid(camera):\n\t\t_base_camera_offset = camera.offset\n\t_connect_fighters()',
        '\tz_index = 80\n\t_connect_fighters()',
        'ready_camera_state',
    )
    text = replace_once(
        text,
        '\t_update_bursts(delta)\n\t_update_camera_shake(delta)\n\tqueue_redraw()',
        '\t_update_bursts(delta)\n\tqueue_redraw()',
        'process_camera_shake',
    )
    text = replace_once(
        text,
        '\tvar text := _onomatopoeia(path_id, result_id, element_id)\n',
        '\t# Physical impact text belongs exclusively to FirstPlayableCombatFeedbackRuntime.\n\t# ImpactDirector keeps shapes/elemental feedback + hitstop only.\n\tvar text := ""\n',
        'physical_text_owner',
    )
    text = replace_once(
        text,
        '\t_append_burst(world_position, text, color, path_id, result_id, intensity, duration, element_id)\n\tvar shake_profile := _shake_profile(path_id, result_id, intensity)\n\t_start_shake(float(shake_profile[0]), float(shake_profile[1]))\n\tvar hitstop_profile := _hitstop_profile(path_id, result_id, intensity)',
        '\t_append_burst(world_position, text, color, path_id, result_id, intensity, duration, element_id)\n\tvar hitstop_profile := _hitstop_profile(path_id, result_id, intensity)',
        'impact_shake_dispatch',
    )
    text = replace_once(
        text,
        '\t\telement_id\n\t)\n\t_start_shake(0.10, 4.0)\n\nfunc _append_burst(',
        '\t\telement_id\n\t)\n\nfunc _append_burst(',
        'element_interaction_shake',
    )

    text = remove_block(text, 'func _update_camera_shake(delta: float) -> void:\n', 'func _apply_hitstop(duration: float, time_scale: float) -> void:\n', 'camera_shake_functions')

    old_draw = '''\t\tdraw_set_transform(center, 0.0, Vector2(scale, scale))\n\t\tvar text := String(burst["text"])\n\t\tvar font_size := int(22.0 + intensity * 18.0)\n\t\tvar shadow_color := Color(0.02, 0.02, 0.035, alpha * 0.90)\n\t\tdraw_string(font, Vector2(-font_size * 0.72 + 3.0, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow_color)\n\t\tdraw_string(font, Vector2(-font_size * 0.72, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color, alpha))\n\t\tif result_id == &"posture_break":\n\t\t\tdraw_arc(Vector2.ZERO, 34.0 + progress * 22.0, 0.0, TAU, 20, Color(color, alpha * 0.72), 4.0)\n\t\tdraw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)\n'''
    new_draw = '''\t\tvar text := String(burst["text"])\n\t\tif text != "":\n\t\t\tdraw_set_transform(center, 0.0, Vector2(scale, scale))\n\t\t\tvar font_size := int(22.0 + intensity * 18.0)\n\t\t\tvar shadow_color := Color(0.02, 0.02, 0.035, alpha * 0.90)\n\t\t\tdraw_string(font, Vector2(-font_size * 0.72 + 3.0, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow_color)\n\t\t\tdraw_string(font, Vector2(-font_size * 0.72, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color, alpha))\n\t\t\tdraw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)\n\t\tif result_id == &"posture_break":\n\t\t\tdraw_arc(center, (34.0 + progress * 22.0) * scale, 0.0, TAU, 20, Color(color, alpha * 0.72), 4.0)\n'''
    text = replace_once(text, old_draw, new_draw, 'physical_text_draw')

    text = remove_block(text, 'func _onomatopoeia(path_id: StringName, result_id: StringName, element_id: StringName) -> String:\n', 'func _impact_color(path_id: StringName, result_id: StringName, element_id: StringName) -> Color:\n', 'onomatopoeia_function')
    text = remove_block(text, 'func _shake_profile(path_id: StringName, result_id: StringName, intensity: float) -> Array[float]:\n', 'func _hitstop_profile(path_id: StringName, result_id: StringName, intensity: float) -> Array[float]:\n', 'shake_profile_function')

    signature = '''func presentation_signature() -> Dictionary:\n\treturn {\n\t\t"stage": "VFX-01",\n\t\t"world_space_impact_shapes": true,\n\t\t"elemental_shapes": true,\n\t\t"elemental_state_text": true,\n\t\t"elemental_interaction_text": true,\n\t\t"physical_impact_text_owner": &"FirstPlayableCombatFeedbackRuntime",\n\t\t"physical_impact_text_emitted_here": false,\n\t\t"camera_shake_owner": false,\n\t\t"camera_shake_delegated_to": &"FightCameraComposition",\n\t\t"hitstop_owner": true,\n\t\t"hitstop_visual_only": true,\n\t\t"damage_changes": false,\n\t\t"frame_data_changes": false,\n\t\t"ai_changes": false,\n\t\t"signature": "Tehkné Solutions"\n\t}\n\nfunc active_burst_count() -> int:\n\treturn _bursts.size()\n\nfunc last_burst_text() -> String:\n\tif _bursts.is_empty():\n\t\treturn ""\n\treturn String(_bursts.back().get("text", ""))\n\n'''
    text = replace_once(text, 'func _exit_tree() -> void:\n', signature + 'func _exit_tree() -> void:\n', 'presentation_signature')
    text = replace_once(
        text,
        '\t_hitstop_token += 1\n\tEngine.time_scale = 1.0\n\tif is_instance_valid(camera):\n\t\tcamera.offset = _base_camera_offset',
        '\t_hitstop_token += 1\n\tEngine.time_scale = 1.0',
        'exit_camera_reset',
    )

    PATH.write_text(text, encoding="utf-8")
    print("VFX01_PATCH=PASS")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
