#!/usr/bin/env python3
from pathlib import Path

AUDIO = Path("scripts/vertical_slice/first_playable_audio_director.gd")
HUD = Path("scripts/vertical_slice/first_playable_hud_controller.gd")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"AUDIO04_PATCH=BLOCKED {label} count={count}")
    return text.replace(old, new, 1)


def patch_audio() -> None:
    text = AUDIO.read_text(encoding="utf-8")
    text = replace_once(
        text,
        'signal ambience_state_changed(state_id: StringName, target_level: float)\n\nconst CONNECT_INTERVAL',
        'signal ambience_state_changed(state_id: StringName, target_level: float)\n\nconst MIX_POLICY_SCRIPT := preload("res://scripts/vertical_slice/first_playable_audio_mix_policy.gd")\n\nconst CONNECT_INTERVAL',
        "audio_policy_preload",
    )
    text = replace_once(
        text,
        'var _pre_pause_ambience_state: StringName = &"pre_fight"\n\nfunc _ready() -> void:\n\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n\t_install_combat_player()',
        'var _pre_pause_ambience_state: StringName = &"pre_fight"\nvar _mix_policy: FirstPlayableAudioMixPolicy\n\nfunc _ready() -> void:\n\tprocess_mode = Node.PROCESS_MODE_ALWAYS\n\t_mix_policy = MIX_POLICY_SCRIPT.new() as FirstPlayableAudioMixPolicy\n\t_mix_policy.load_preferences()\n\t_install_combat_player()',
        "audio_policy_ready",
    )
    text = replace_once(text, '"stage": "AUDIO-03",', '"stage": "AUDIO-04",', "audio_stage")
    text = replace_once(
        text,
        '"ambience_single_owner": true,\n\t\t"mix_rate_hz": int(MIX_RATE),',
        '"ambience_single_owner": true,\n\t\t"final_mastering": true,\n\t\t"soft_limiter": true,\n\t\t"master_ceiling": _mix_policy.master_ceiling(),\n\t\t"accessibility_mix_controls": true,\n\t\t"persistent_mix_preferences": true,\n\t\t"accessibility_profiles": ["standard", "combat_focus", "reduced_dynamics", "mono_accessible"],\n\t\t"mix_rate_hz": int(MIX_RATE),',
        "audio_signature_mastering",
    )
    text = replace_once(
        text,
        '"remaining_audio_scope": ["final_mastering", "accessibility_mix_controls"],',
        '"remaining_audio_scope": [],',
        "audio_remaining_scope",
    )
    wrapper = '''func audio_mix_snapshot() -> Dictionary:\n\treturn _mix_policy.snapshot() if _mix_policy != null else {}\n\nfunc accessibility_profile() -> StringName:\n\treturn _mix_policy.profile_id() if _mix_policy != null else &"standard"\n\nfunc accessibility_profiles() -> Array[StringName]:\n\treturn _mix_policy.profile_ids() if _mix_policy != null else []\n\nfunc set_accessibility_profile(profile_id: StringName) -> bool:\n\treturn _mix_policy.set_profile(profile_id, true) if _mix_policy != null else false\n\nfunc cycle_accessibility_profile() -> StringName:\n\treturn _mix_policy.cycle_profile() if _mix_policy != null else &"standard"\n\nfunc audio_level(channel_id: StringName) -> float:\n\treturn _mix_policy.level(channel_id) if _mix_policy != null else 1.0\n\nfunc adjust_audio_level(channel_id: StringName, direction: int) -> float:\n\treturn _mix_policy.adjust_level_step(channel_id, direction) if _mix_policy != null else 1.0\n\nfunc reset_master_peak() -> void:\n\tif _mix_policy != null:\n\t\t_mix_policy.reset_peak_observed()\n\nfunc master_peak_observed() -> float:\n\treturn _mix_policy.peak_observed() if _mix_policy != null else 0.0\n\n'''
    text = replace_once(
        text,
        'func _connect_parent_presentation() -> void:\n',
        wrapper + 'func _connect_parent_presentation() -> void:\n',
        "audio_public_mix_api",
    )
    text = replace_once(
        text,
        '\t_last_pan = clampf(pan, -MAX_WORLD_PAN, MAX_WORLD_PAN)\n\t_cue_counts[cue_id] = cue_count(cue_id) + 1',
        '\t_last_pan = _mix_policy.apply_pan(clampf(pan, -MAX_WORLD_PAN, MAX_WORLD_PAN))\n\t_cue_counts[cue_id] = cue_count(cue_id) + 1',
        "audio_accessible_pan",
    )
    text = replace_once(
        text,
        '\tvar amplitude := float(recipe["amplitude"]) * lerpf(0.72, 1.0, intensity)\n\t_emit_layered(',
        '\tvar amplitude := float(recipe["amplitude"]) * lerpf(0.72, 1.0, intensity)\n\tamplitude = _mix_policy.shape_cue_amplitude(amplitude)\n\tvar channel_id: StringName = &"ui" if cue_id in [CUE_UI_PAUSE, CUE_UI_RESUME, CUE_UI_SELECT, CUE_UI_CONFIRM] else &"combat"\n\t_emit_layered(',
        "audio_amplitude_shape",
    )
    text = replace_once(
        text,
        '\t\tfloat(recipe["decay_power"]),\n\t\t_last_pan\n\t)',
        '\t\tfloat(recipe["decay_power"]),\n\t\t_last_pan,\n\t\tchannel_id\n\t)',
        "audio_channel_call",
    )
    text = replace_once(
        text,
        '\tdecay_power: float,\n\tpan: float\n) -> void:',
        '\tdecay_power: float,\n\tpan: float,\n\tchannel_id: StringName\n) -> void:',
        "audio_channel_signature",
    )
    text = replace_once(
        text,
        '\t\t_playback.push_frame(Vector2(sample * left_gain, sample * right_gain))',
        '\t\tvar mastered := _mix_policy.master_frame(Vector2(sample * left_gain, sample * right_gain), channel_id)\n\t\t_playback.push_frame(mastered)',
        "audio_master_combat_frame",
    )
    text = replace_once(
        text,
        '\t\t_ambience_playback.push_frame(Vector2(clampf(left, -0.40, 0.40), clampf(right, -0.40, 0.40)))',
        '\t\tvar mastered := _mix_policy.master_frame(Vector2(clampf(left, -0.40, 0.40), clampf(right, -0.40, 0.40)), &"ambience")\n\t\t_ambience_playback.push_frame(mastered)',
        "audio_master_ambience_frame",
    )
    AUDIO.write_text(text, encoding="utf-8")


def patch_hud() -> None:
    text = HUD.read_text(encoding="utf-8")
    text = replace_once(
        text,
        'var _qa_visible := false\n\nfunc _ready() -> void:',
        'var _qa_visible := false\nvar _audio_profile_button: Button\nvar _audio_status: Label\nvar _audio_master_label: Label\nvar _audio_mix_buttons: Array[Button] = []\n\nfunc _ready() -> void:',
        "hud_audio_vars",
    )
    text = replace_once(
        text,
        '\t_build_playtest_controls()\n\tFirstPlayableHudSkin.apply(self)',
        '\t_build_playtest_controls()\n\t_build_audio_accessibility_controls()\n\tFirstPlayableHudSkin.apply(self)',
        "hud_build_audio",
    )
    text = replace_once(
        text,
        '\tif active:\n\t\tresume_button.grab_focus()\n',
        '\tif active:\n\t\t_refresh_audio_accessibility_controls()\n\t\tresume_button.grab_focus()\n',
        "hud_refresh_pause",
    )
    text = replace_once(
        text,
        '\t\t"gamepad_focus_supported": true,\n\t\t"final_skin": FirstPlayableHudSkin.presentation_signature()',
        '\t\t"gamepad_focus_supported": true,\n\t\t"audio_accessibility_controls": true,\n\t\t"audio_profile_control": true,\n\t\t"audio_master_control": true,\n\t\t"audio_channel_controls": ["combat", "ambience", "ui"],\n\t\t"final_skin": FirstPlayableHudSkin.presentation_signature()',
        "hud_signature",
    )
    methods = '''func _build_audio_accessibility_controls() -> void:\n\tvar content := get_node_or_null("../HUD/PauseOverlay/Panel/Content") as VBoxContainer\n\tvar panel := get_node_or_null("../HUD/PauseOverlay/Panel") as PanelContainer\n\tif content == null or panel == null:\n\t\treturn\n\tpanel.offset_top = 112.0\n\tpanel.offset_bottom = 608.0\n\n\tvar title := Label.new()\n\ttitle.name = "AudioAccessibilityTitle"\n\ttitle.custom_minimum_size = Vector2(0.0, 28.0)\n\ttitle.text = "ÁUDIO & ACESSIBILIDADE"\n\ttitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\ttitle.add_theme_font_size_override("font_size", 12)\n\tcontent.add_child(title)\n\n\t_audio_profile_button = Button.new()\n\t_audio_profile_button.name = "AudioProfileButton"\n\t_audio_profile_button.custom_minimum_size = Vector2(0.0, 38.0)\n\t_audio_profile_button.pressed.connect(_on_audio_profile_cycle)\n\tcontent.add_child(_audio_profile_button)\n\n\t_audio_master_label = Label.new()\n\t_audio_master_label.name = "AudioMasterLabel"\n\t_audio_master_label.custom_minimum_size = Vector2(0.0, 22.0)\n\t_audio_master_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\t_audio_master_label.add_theme_font_size_override("font_size", 10)\n\tcontent.add_child(_audio_master_label)\n\n\tvar master_row := HBoxContainer.new()\n\tmaster_row.name = "AudioMasterControls"\n\tmaster_row.alignment = BoxContainer.ALIGNMENT_CENTER\n\tmaster_row.add_theme_constant_override("separation", 8)\n\tcontent.add_child(master_row)\n\t_add_audio_adjust_button(master_row, "MasterDown", "VOLUME −", &"master", -1)\n\t_add_audio_adjust_button(master_row, "MasterUp", "VOLUME +", &"master", 1)\n\n\tvar mix_row := HBoxContainer.new()\n\tmix_row.name = "AudioChannelControls"\n\tmix_row.alignment = BoxContainer.ALIGNMENT_CENTER\n\tmix_row.add_theme_constant_override("separation", 4)\n\tcontent.add_child(mix_row)\n\t_add_audio_adjust_button(mix_row, "CombatDown", "FX−", &"combat", -1, 54.0)\n\t_add_audio_adjust_button(mix_row, "CombatUp", "FX+", &"combat", 1, 54.0)\n\t_add_audio_adjust_button(mix_row, "AmbienceDown", "AMB−", &"ambience", -1, 58.0)\n\t_add_audio_adjust_button(mix_row, "AmbienceUp", "AMB+", &"ambience", 1, 58.0)\n\t_add_audio_adjust_button(mix_row, "UiDown", "UI−", &"ui", -1, 54.0)\n\t_add_audio_adjust_button(mix_row, "UiUp", "UI+", &"ui", 1, 54.0)\n\n\t_audio_status = Label.new()\n\t_audio_status.name = "AudioMixStatus"\n\t_audio_status.custom_minimum_size = Vector2(0.0, 30.0)\n\t_audio_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\t_audio_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER\n\t_audio_status.add_theme_font_size_override("font_size", 9)\n\tcontent.add_child(_audio_status)\n\n\tcontent.move_child(resume_button, content.get_child_count() - 2)\n\tcontent.move_child(pause_menu_button, content.get_child_count() - 1)\n\t_refresh_audio_accessibility_controls()\n\nfunc _add_audio_adjust_button(parent: HBoxContainer, node_name: String, label: String, channel_id: StringName, direction: int, width: float = 130.0) -> void:\n\tvar button := Button.new()\n\tbutton.name = node_name\n\tbutton.custom_minimum_size = Vector2(width, 32.0)\n\tbutton.text = label\n\tbutton.add_theme_font_size_override("font_size", 9)\n\tbutton.pressed.connect(_on_audio_level_adjust.bind(channel_id, direction))\n\tparent.add_child(button)\n\t_audio_mix_buttons.append(button)\n\nfunc _audio_director() -> FirstPlayableAudioDirector:\n\tvar match_controller := get_parent()\n\tif match_controller == null:\n\t\treturn null\n\treturn match_controller.get_node_or_null("AudioDirector") as FirstPlayableAudioDirector\n\nfunc _on_audio_profile_cycle() -> void:\n\tvar audio := _audio_director()\n\tif audio == null:\n\t\treturn\n\taudio.cycle_accessibility_profile()\n\t_refresh_audio_accessibility_controls()\n\nfunc _on_audio_level_adjust(channel_id: StringName, direction: int) -> void:\n\tvar audio := _audio_director()\n\tif audio == null:\n\t\treturn\n\taudio.adjust_audio_level(channel_id, direction)\n\t_refresh_audio_accessibility_controls()\n\nfunc _refresh_audio_accessibility_controls() -> void:\n\tvar audio := _audio_director()\n\tif audio == null or not is_instance_valid(_audio_profile_button) or not is_instance_valid(_audio_status):\n\t\treturn\n\t_audio_profile_button.text = "PERFIL: %s" % _audio_profile_label(audio.accessibility_profile())\n\t_audio_master_label.text = "VOLUME GERAL • %d%%" % int(round(audio.audio_level(&"master") * 100.0))\n\t_audio_status.text = "FX %d%%  •  AMB %d%%  •  UI %d%%" % [\n\t\tint(round(audio.audio_level(&"combat") * 100.0)),\n\t\tint(round(audio.audio_level(&"ambience") * 100.0)),\n\t\tint(round(audio.audio_level(&"ui") * 100.0)),\n\t]\n\nfunc _audio_profile_label(profile_id: StringName) -> String:\n\tmatch profile_id:\n\t\t&"combat_focus": return "FOCO EM COMBATE"\n\t\t&"reduced_dynamics": return "DINÂMICA REDUZIDA"\n\t\t&"mono_accessible": return "MONO ACESSÍVEL"\n\t\t_: return "PADRÃO"\n\n'''
    text = replace_once(
        text,
        'func _build_playtest_controls() -> void:\n',
        methods + 'func _build_playtest_controls() -> void:\n',
        "hud_audio_methods",
    )
    HUD.write_text(text, encoding="utf-8")


def main() -> None:
    patch_audio()
    patch_hud()
    print("AUDIO04_PATCH=PASS")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
