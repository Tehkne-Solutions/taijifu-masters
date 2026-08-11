extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const EXPECTED_CUES: Array[StringName] = [
	&"hit",
	&"evade",
	&"block",
	&"parry",
	&"posture_break",
]
const RESULT_IDS: Array[StringName] = [
	&"hit",
	&"evaded",
	&"blocked",
	&"parried",
	&"posture_break",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-AUDIO-01")
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("AUDIO01_FOUNDATION=BLOCKED battle_scene")
		return

	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	get_root().add_child(battle)
	await create_timer(0.85).timeout
	for _frame in range(6):
		await process_frame

	var audio := battle.get_node_or_null("AudioDirector") as FirstPlayableAudioDirector
	if audio == null:
		_fail("AUDIO01_FOUNDATION=BLOCKED director_not_mounted", battle)
		return
	if not is_instance_valid(battle.player_one) or not is_instance_valid(battle.player_two):
		_fail("AUDIO01_FOUNDATION=BLOCKED fighters_missing", battle)
		return
	if audio.connected_fighter_count() != 2:
		_fail("AUDIO01_FOUNDATION=BLOCKED fighter_connections=%d" % audio.connected_fighter_count(), battle)
		return

	var signature := audio.presentation_signature()
	if String(signature.get("stage", "")) != "AUDIO-01":
		_fail("AUDIO01_FOUNDATION=BLOCKED wrong_stage", battle)
		return
	if not bool(signature.get("event_consumer_only", false)):
		_fail("AUDIO01_FOUNDATION=BLOCKED event_consumer_only", battle)
		return
	if bool(signature.get("gameplay_timing_owner", true)) or bool(signature.get("damage_owner", true)):
		_fail("AUDIO01_FOUNDATION=BLOCKED gameplay_ownership", battle)
		return
	if not bool(signature.get("cue_telemetry", false)):
		_fail("AUDIO01_FOUNDATION=BLOCKED cue_telemetry", battle)
		return

	var p1_health_before := battle.player_one.health
	var p1_posture_before := battle.player_one.posture
	var p2_health_before := battle.player_two.health
	var p2_posture_before := battle.player_two.posture
	var time_before := battle._time_remaining

	for index in range(RESULT_IDS.size()):
		battle.player_one.impact_resolved.emit(
			battle.player_one,
			battle.player_two,
			null,
			RESULT_IDS[index],
			0.0,
			0.0,
			0.62,
			battle.player_one.global_position
		)
		if audio.last_cue_id() != EXPECTED_CUES[index]:
			_fail("AUDIO01_FOUNDATION=BLOCKED cue_map expected=%s actual=%s" % [EXPECTED_CUES[index], audio.last_cue_id()], battle)
			return

	for cue_id in EXPECTED_CUES:
		if audio.cue_count(cue_id) != 1:
			_fail("AUDIO01_FOUNDATION=BLOCKED cue_count %s=%d" % [cue_id, audio.cue_count(cue_id)], battle)
			return

	var gameplay_unchanged := (
		is_equal_approx(battle.player_one.health, p1_health_before)
		and is_equal_approx(battle.player_one.posture, p1_posture_before)
		and is_equal_approx(battle.player_two.health, p2_health_before)
		and is_equal_approx(battle.player_two.posture, p2_posture_before)
		and is_equal_approx(battle._time_remaining, time_before)
	)
	if not gameplay_unchanged:
		_fail("AUDIO01_FOUNDATION=BLOCKED gameplay_mutation", battle)
		return

	var player := audio.get_node_or_null("CombatAudioPlayer") as AudioStreamPlayer
	if player == null or not (player.stream is AudioStreamGenerator):
		_fail("AUDIO01_FOUNDATION=BLOCKED generator_player", battle)
		return

	print("AUDIO01_SCENE_MOUNT=PASS")
	print("AUDIO01_FIGHTER_CONNECTIONS=PASS count=%d" % audio.connected_fighter_count())
	print("AUDIO01_CUE_MAP=PASS hit evade block parry posture_break")
	print("AUDIO01_EVENT_CONSUMER_ONLY=PASS")
	print("AUDIO01_ZERO_GAMEPLAY_MUTATION=PASS")
	print("AUDIO01_FOUNDATION=PASS")
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
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions
