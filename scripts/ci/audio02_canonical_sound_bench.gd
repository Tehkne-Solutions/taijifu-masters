extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const EXPECTED_CANONICAL_CUES: Array[StringName] = [
	&"hit",
	&"evade",
	&"block",
	&"parry",
	&"posture_break",
	&"countdown",
	&"fight",
	&"ko",
	&"timeout",
	&"round_win",
	&"round_loss",
	&"ui_pause",
	&"ui_resume",
	&"ui_select",
	&"ui_confirm",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-AUDIO-02")
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED battle_scene")
		return

	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	get_root().add_child(battle)
	await create_timer(0.85).timeout
	for _frame in range(6):
		await process_frame

	var audio := battle.get_node_or_null("AudioDirector") as FirstPlayableAudioDirector
	if audio == null:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED director", battle)
		return
	if not audio.presentation_connected():
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED presentation_connection", battle)
		return
	if audio.connected_fighter_count() != 2:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED fighter_connections=%d" % audio.connected_fighter_count(), battle)
		return

	var signature := audio.presentation_signature()
	if String(signature.get("stage", "")) != "AUDIO-02":
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED stage", battle)
		return
	for required_flag in [
		"canonical_sound_design",
		"procedural_layering",
		"deterministic_recipes",
		"stereo_spatialization",
		"event_consumer_only",
	]:
		if not bool(signature.get(required_flag, false)):
			_fail("AUDIO02_CANONICAL_SOUND=BLOCKED flag=%s" % required_flag, battle)
			return
	if bool(signature.get("gameplay_timing_owner", true)) or bool(signature.get("damage_owner", true)) or bool(signature.get("ai_owner", true)):
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED gameplay_owner", battle)
		return
	if int(signature.get("mix_rate_hz", 0)) != 44100:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED mix_rate_signature", battle)
		return

	var player := audio.get_node_or_null("CombatAudioPlayer") as AudioStreamPlayer
	if player == null or not (player.stream is AudioStreamGenerator):
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED generator", battle)
		return
	var generator := player.stream as AudioStreamGenerator
	if not is_equal_approx(generator.mix_rate, 44100.0):
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED mix_rate_runtime=%.1f" % generator.mix_rate, battle)
		return

	var canonical := audio.canonical_cue_ids()
	if canonical.size() != EXPECTED_CANONICAL_CUES.size():
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED cue_count=%d" % canonical.size(), battle)
		return
	for cue_id in EXPECTED_CANONICAL_CUES:
		if not canonical.has(cue_id):
			_fail("AUDIO02_CANONICAL_SOUND=BLOCKED missing_cue=%s" % cue_id, battle)
			return
		var recipe := audio.cue_recipe(cue_id)
		var frequencies: Array = recipe.get("frequencies", [])
		if frequencies.size() < 2:
			_fail("AUDIO02_CANONICAL_SOUND=BLOCKED recipe_layers=%s" % cue_id, battle)
			return
		if float(recipe.get("duration", 0.0)) <= 0.0 or float(recipe.get("amplitude", 0.0)) <= 0.0:
			_fail("AUDIO02_CANONICAL_SOUND=BLOCKED recipe_energy=%s" % cue_id, battle)
			return

	if audio.cue_count(&"countdown") != 3:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED countdown_count=%d" % audio.cue_count(&"countdown"), battle)
		return
	if audio.cue_count(&"fight") != 1:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED fight_count=%d" % audio.cue_count(&"fight"), battle)
		return

	var p1_health_before := battle.player_one.health
	var p1_posture_before := battle.player_one.posture
	var p2_health_before := battle.player_two.health
	var p2_posture_before := battle.player_two.posture
	var time_before := battle._time_remaining

	battle.player_one.impact_resolved.emit(
		battle.player_one,
		battle.player_two,
		null,
		&"hit",
		0.0,
		0.0,
		0.74,
		Vector2(120.0, 820.0)
	)
	var left_pan := audio.last_pan()
	battle.player_one.impact_resolved.emit(
		battle.player_one,
		battle.player_two,
		null,
		&"hit",
		0.0,
		0.0,
		0.74,
		Vector2(2680.0, 820.0)
	)
	var right_pan := audio.last_pan()
	if left_pan >= -0.05 or right_pan <= 0.05:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED spatial_pan left=%.3f right=%.3f" % [left_pan, right_pan], battle)
		return

	var gameplay_unchanged := (
		is_equal_approx(battle.player_one.health, p1_health_before)
		and is_equal_approx(battle.player_one.posture, p1_posture_before)
		and is_equal_approx(battle.player_two.health, p2_health_before)
		and is_equal_approx(battle.player_two.posture, p2_posture_before)
		and is_equal_approx(battle._time_remaining, time_before)
	)
	if not gameplay_unchanged:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED gameplay_mutation", battle)
		return

	battle._set_paused(true)
	battle._set_paused(false)
	if audio.cue_count(&"ui_pause") < 1 or audio.cue_count(&"ui_resume") < 1:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED pause_resume", battle)
		return

	battle._on_difficulty_changed(&"apprentice", "Aprendiz")
	if audio.cue_count(&"ui_select") < 1:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED ui_select", battle)
		return

	battle.presentation_cue_requested.emit(&"ui_confirm", 0.80)
	battle.presentation_cue_requested.emit(&"timeout", 0.88)
	battle.presentation_cue_requested.emit(&"round_loss", 1.0)
	if audio.cue_count(&"ui_confirm") < 1 or audio.cue_count(&"timeout") < 1 or audio.cue_count(&"round_loss") < 1:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED presentation_dispatch", battle)
		return

	battle._finish_match(battle.player_one, "KO")
	if audio.cue_count(&"ko") != 1 or audio.cue_count(&"round_win") != 1:
		_fail("AUDIO02_CANONICAL_SOUND=BLOCKED ko_result ko=%d win=%d" % [audio.cue_count(&"ko"), audio.cue_count(&"round_win")], battle)
		return

	print("AUDIO02_PRESENTATION_CONNECTION=PASS")
	print("AUDIO02_CANONICAL_CUES=PASS count=%d" % canonical.size())
	print("AUDIO02_LAYERED_RECIPES=PASS")
	print("AUDIO02_44100_MIX=PASS")
	print("AUDIO02_COUNTDOWN_FIGHT=PASS countdown=3 fight=1")
	print("AUDIO02_SPATIAL_PAN=PASS left=%.3f right=%.3f" % [left_pan, right_pan])
	print("AUDIO02_KO_RESULT_UI=PASS")
	print("AUDIO02_ZERO_GAMEPLAY_MUTATION=PASS")
	print("AUDIO02_CANONICAL_SOUND=PASS")
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
