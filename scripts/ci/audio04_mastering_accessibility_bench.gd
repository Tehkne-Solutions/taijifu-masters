extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const PREF_PATH := "user://taijifu_audio_accessibility.cfg"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(PREF_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PREF_PATH))
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-AUDIO-04")
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("AUDIO04_MASTERING=BLOCKED battle_scene")
		return
	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	get_root().add_child(battle)
	await create_timer(0.82).timeout
	for _frame in range(8):
		await process_frame

	var audio := battle.get_node_or_null("AudioDirector") as FirstPlayableAudioDirector
	if audio == null:
		_fail("AUDIO04_MASTERING=BLOCKED director", battle)
		return
	var signature := audio.presentation_signature()
	if String(signature.get("stage", "")) != "AUDIO-04":
		_fail("AUDIO04_MASTERING=BLOCKED stage", battle)
		return
	for flag in ["final_mastering", "soft_limiter", "accessibility_mix_controls", "persistent_mix_preferences", "event_consumer_only"]:
		if not bool(signature.get(flag, false)):
			_fail("AUDIO04_MASTERING=BLOCKED flag=%s" % flag, battle)
			return
	if not Array(signature.get("remaining_audio_scope", ["unexpected"])).is_empty():
		_fail("AUDIO04_MASTERING=BLOCKED remaining_scope", battle)
		return
	if absf(float(signature.get("master_ceiling", 0.0)) - 0.86) > 0.001:
		_fail("AUDIO04_MASTERING=BLOCKED ceiling_signature", battle)
		return

	var profiles := audio.accessibility_profiles()
	for expected in [&"standard", &"combat_focus", &"reduced_dynamics", &"mono_accessible"]:
		if not profiles.has(expected):
			_fail("AUDIO04_MASTERING=BLOCKED profile=%s" % expected, battle)
			return

	var p1_health := battle.player_one.health
	var p1_posture := battle.player_one.posture
	var p2_health := battle.player_two.health
	var p2_posture := battle.player_two.posture
	var time_before := battle._time_remaining

	audio.set_accessibility_profile(&"mono_accessible")
	battle.player_one.impact_resolved.emit(
		battle.player_one, battle.player_two, null, &"hit", 0.0, 0.0, 0.8, Vector2(120.0, 820.0)
	)
	if absf(audio.last_pan()) > 0.0001:
		_fail("AUDIO04_MASTERING=BLOCKED mono_pan=%.4f" % audio.last_pan(), battle)
		return

	audio.set_accessibility_profile(&"combat_focus")
	var combat_focus := audio.audio_mix_snapshot()
	if absf(float(combat_focus.get("profile_combat_gain", 0.0)) - 1.08) > 0.001:
		_fail("AUDIO04_MASTERING=BLOCKED combat_focus_gain", battle)
		return
	if absf(float(combat_focus.get("profile_ambience_gain", 0.0)) - 0.50) > 0.001:
		_fail("AUDIO04_MASTERING=BLOCKED ambience_duck", battle)
		return

	var policy := FirstPlayableAudioMixPolicy.new()
	policy.set_profile(&"reduced_dynamics", false)
	var quiet_shaped := policy.shape_cue_amplitude(0.05)
	var loud_shaped := policy.shape_cue_amplitude(0.40)
	if quiet_shaped <= 0.05 or loud_shaped >= 0.40:
		_fail("AUDIO04_MASTERING=BLOCKED reduced_dynamics quiet=%.3f loud=%.3f" % [quiet_shaped, loud_shaped], battle)
		return
	policy.set_profile(&"mono_accessible", false)
	if absf(policy.apply_pan(0.42)) > 0.0001:
		_fail("AUDIO04_MASTERING=BLOCKED policy_mono", battle)
		return
	policy.set_profile(&"standard", false)
	policy.reset_peak_observed()
	var limited := policy.master_frame(Vector2(4.0, -4.0), &"combat")
	if absf(limited.x) > 0.8601 or absf(limited.y) > 0.8601:
		_fail("AUDIO04_MASTERING=BLOCKED limiter frame=%s" % limited, battle)
		return
	if policy.peak_observed() <= 0.68 or policy.peak_observed() > 0.8601:
		_fail("AUDIO04_MASTERING=BLOCKED peak=%.4f" % policy.peak_observed(), battle)
		return

	audio.set_accessibility_profile(&"standard")
	var master_before := audio.audio_level(&"master")
	var master_down := audio.adjust_audio_level(&"master", -1)
	if master_down >= master_before or absf(master_down - 0.90) > 0.001:
		_fail("AUDIO04_MASTERING=BLOCKED master_adjust=%.3f" % master_down, battle)
		return
	audio.adjust_audio_level(&"master", 1)
	if not FileAccess.file_exists(PREF_PATH):
		_fail("AUDIO04_MASTERING=BLOCKED persistence_file", battle)
		return
	var reloaded := FirstPlayableAudioMixPolicy.new()
	reloaded.load_preferences()
	if reloaded.profile_id() != &"standard" or absf(reloaded.level(&"master") - 1.0) > 0.001:
		_fail("AUDIO04_MASTERING=BLOCKED persistence_reload", battle)
		return

	var hud := battle.hud_controller as FirstPlayableHudController
	if hud == null:
		_fail("AUDIO04_MASTERING=BLOCKED hud", battle)
		return
	var pause_content := battle.get_node_or_null("HUD/PauseOverlay/Panel/Content") as VBoxContainer
	if pause_content == null:
		_fail("AUDIO04_MASTERING=BLOCKED pause_content", battle)
		return
	for node_name in ["AudioAccessibilityTitle", "AudioProfileButton", "AudioMasterControls", "AudioChannelControls", "AudioMixStatus"]:
		if pause_content.get_node_or_null(node_name) == null:
			_fail("AUDIO04_MASTERING=BLOCKED hud_control=%s" % node_name, battle)
			return
	battle._set_paused(true)
	var profile_button := pause_content.get_node("AudioProfileButton") as Button
	var status_label := pause_content.get_node("AudioMixStatus") as Label
	if profile_button.text == "" or status_label.text.find("FX") < 0 or status_label.text.find("AMB") < 0:
		_fail("AUDIO04_MASTERING=BLOCKED hud_status", battle)
		return
	profile_button.pressed.emit()
	if audio.accessibility_profile() != &"combat_focus":
		_fail("AUDIO04_MASTERING=BLOCKED hud_profile_cycle=%s" % audio.accessibility_profile(), battle)
		return
	battle._set_paused(false)

	var synchronous_unchanged := (
		is_equal_approx(battle.player_one.health, p1_health)
		and is_equal_approx(battle.player_one.posture, p1_posture)
		and is_equal_approx(battle.player_two.health, p2_health)
		and is_equal_approx(battle.player_two.posture, p2_posture)
		and is_equal_approx(battle._time_remaining, time_before)
	)
	if not synchronous_unchanged:
		_fail("AUDIO04_MASTERING=BLOCKED gameplay_mutation", battle)
		return

	print("AUDIO04_LIMITER=PASS ceiling=0.86 peak=%.4f" % policy.peak_observed())
	print("AUDIO04_PROFILES=PASS count=4 mono=true reduced_dynamics=true combat_focus=true")
	print("AUDIO04_PERSISTENCE=PASS")
	print("AUDIO04_MIX_LEVELS=PASS master combat ambience ui")
	print("AUDIO04_PAUSE_UI=PASS")
	print("AUDIO04_ZERO_GAMEPLAY_MUTATION=PASS")
	print("AUDIO04_MASTERING=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(0)

func _fail(message: String, battle: Node = null) -> void:
	push_error(message)
	print(message)
	print("SIGNATURE=Tehkné Solutions")
	if is_instance_valid(battle):
		battle.queue_free()
	get_root().get_tree().paused = false
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions
