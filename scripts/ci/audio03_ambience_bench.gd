extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-AUDIO-03")
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("AUDIO03_AMBIENCE=BLOCKED battle_scene")
		return
	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	get_root().add_child(battle)
	await create_timer(0.80).timeout
	for _frame in range(8):
		await process_frame

	var audio := battle.get_node_or_null("AudioDirector") as FirstPlayableAudioDirector
	if audio == null:
		_fail("AUDIO03_AMBIENCE=BLOCKED director", battle)
		return
	var signature := audio.presentation_signature()
	if String(signature.get("stage", "")) != "AUDIO-03":
		_fail("AUDIO03_AMBIENCE=BLOCKED stage", battle)
		return
	for flag in ["arena_ambience", "musical_bed", "adaptive_ambience_state", "ambience_single_owner", "event_consumer_only"]:
		if not bool(signature.get(flag, false)):
			_fail("AUDIO03_AMBIENCE=BLOCKED flag=%s" % flag, battle)
			return
	if bool(signature.get("gameplay_timing_owner", true)) or bool(signature.get("damage_owner", true)) or bool(signature.get("ai_owner", true)):
		_fail("AUDIO03_AMBIENCE=BLOCKED gameplay_owner", battle)
		return
	if int(signature.get("ambience_mix_rate_hz", 0)) != 22050:
		_fail("AUDIO03_AMBIENCE=BLOCKED signature_mix_rate", battle)
		return

	var ambience_player := audio.get_node_or_null("ArenaAmbiencePlayer") as AudioStreamPlayer
	if ambience_player == null or not (ambience_player.stream is AudioStreamGenerator):
		_fail("AUDIO03_AMBIENCE=BLOCKED ambience_player", battle)
		return
	var generator := ambience_player.stream as AudioStreamGenerator
	if not is_equal_approx(generator.mix_rate, 22050.0):
		_fail("AUDIO03_AMBIENCE=BLOCKED runtime_mix_rate=%.1f" % generator.mix_rate, battle)
		return
	if not audio.ambience_player_active():
		_fail("AUDIO03_AMBIENCE=BLOCKED playback", battle)
		return

	if audio.ambience_state() != &"battle" or not is_equal_approx(audio.ambience_target(), 0.72):
		_fail("AUDIO03_AMBIENCE=BLOCKED initial_battle_state=%s target=%.3f" % [audio.ambience_state(), audio.ambience_target()], battle)
		return
	var clock_before := audio.ambience_clock_seconds()
	await create_timer(0.16).timeout
	for _frame in range(4):
		await process_frame
	var clock_after := audio.ambience_clock_seconds()
	if clock_after <= clock_before + 0.02:
		_fail("AUDIO03_AMBIENCE=BLOCKED stream_clock before=%.4f after=%.4f" % [clock_before, clock_after], battle)
		return

	var p1_health := battle.player_one.health
	var p1_posture := battle.player_one.posture
	var p2_health := battle.player_two.health
	var p2_posture := battle.player_two.posture
	var time_before := battle._time_remaining

	battle._set_paused(true)
	if audio.ambience_state() != &"paused" or not is_equal_approx(audio.ambience_target(), 0.05):
		_fail("AUDIO03_AMBIENCE=BLOCKED paused_state=%s target=%.3f" % [audio.ambience_state(), audio.ambience_target()], battle)
		return
	battle._set_paused(false)
	if audio.ambience_state() != &"battle" or not is_equal_approx(audio.ambience_target(), 0.72):
		_fail("AUDIO03_AMBIENCE=BLOCKED resume_restore=%s target=%.3f" % [audio.ambience_state(), audio.ambience_target()], battle)
		return

	var synchronous_unchanged := (
		is_equal_approx(battle.player_one.health, p1_health)
		and is_equal_approx(battle.player_one.posture, p1_posture)
		and is_equal_approx(battle.player_two.health, p2_health)
		and is_equal_approx(battle.player_two.posture, p2_posture)
		and is_equal_approx(battle._time_remaining, time_before)
	)
	if not synchronous_unchanged:
		_fail("AUDIO03_AMBIENCE=BLOCKED gameplay_mutation", battle)
		return

	battle._finish_match(battle.player_one, "KO")
	if audio.ambience_state() != &"result" or not is_equal_approx(audio.ambience_target(), 0.12):
		_fail("AUDIO03_AMBIENCE=BLOCKED result_state=%s target=%.3f" % [audio.ambience_state(), audio.ambience_target()], battle)
		return
	if audio.cue_count(&"ko") != 1 or audio.cue_count(&"round_win") != 1:
		_fail("AUDIO03_AMBIENCE=BLOCKED result_cues", battle)
		return

	print("AUDIO03_AMBIENCE_PLAYER=PASS mix_rate=22050")
	print("AUDIO03_STREAM_CLOCK=PASS before=%.4f after=%.4f" % [clock_before, clock_after])
	print("AUDIO03_BATTLE_STATE=PASS target=0.72")
	print("AUDIO03_PAUSE_RESUME=PASS paused=0.05 restored=0.72")
	print("AUDIO03_RESULT_STATE=PASS target=0.12")
	print("AUDIO03_ZERO_GAMEPLAY_MUTATION=PASS")
	print("AUDIO03_AMBIENCE=PASS")
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
