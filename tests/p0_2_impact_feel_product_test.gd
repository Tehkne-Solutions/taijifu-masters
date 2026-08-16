extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_BATTLE_WAIT_FRAMES := 420
const MAX_CAMERA_KICK_PIXELS := 7.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_difficulty(&"apprentice")
	Engine.time_scale = 1.0

	if not ResourceLoader.exists(BATTLE_SCENE):
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED battle_scene_missing")
		return
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as FirstPlayableController
	if battle == null:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED battle_instantiate")
		return
	battle.countdown_step_seconds = 0.01
	battle.fight_command_seconds = 0.01
	battle.match_time_limit_seconds = 40.0
	root.add_child(battle)
	if not await _wait_for_battle(battle):
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED battle_state_timeout", battle)
		return
	for _frame in range(24):
		await process_frame

	battle.bot_runtime.enabled = false
	battle._set_fighters_controls(false)
	var impact := battle.get_node_or_null("ImpactDirector") as ImpactDirector
	var camera_composition := battle.get_node_or_null("FightCameraComposition") as FirstPlayableCameraComposition
	var feedback := battle.get_node_or_null("FirstPlayableCombatFeedbackRuntime")
	if impact == null or camera_composition == null or feedback == null:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED presentation_runtime_missing", battle)
		return
	if not is_instance_valid(battle.player_one) or not is_instance_valid(battle.player_two):
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED fighters_missing", battle)
		return
	var p1 := battle.player_one as FirstPlayableCombatFighterController
	var p2 := battle.player_two as FirstPlayableCombatFighterController
	if p1 == null or p2 == null:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED first_playable_fighter_type", battle)
		return
	var technique := TechniqueCatalog.get_technique(&"ji_body_hook")
	if technique == null:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED technique_missing", battle)
		return

	# First-contact presentation probe: the impact signal must synchronously enter
	# hitstop and place a bounded directional camera kick before the next frame.
	p1.global_position = Vector2(1180.0, 760.0)
	p2.global_position = Vector2(1320.0, 760.0)
	p1.facing = 1.0
	p2.facing = -1.0
	Engine.time_scale = 1.0
	p1.impact_resolved.emit(
		p2,
		p1,
		technique,
		&"hit",
		8.0,
		4.0,
		0.86,
		p2.global_position + Vector2(0.0, -38.0)
	)
	var hitstop_signature := impact.hitstop_runtime_signature()
	var camera_signature := camera_composition.impact_runtime_signature()
	if not bool(hitstop_signature.get("active", false)) or Engine.time_scale >= 0.99:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED first_contact_hitstop", battle)
		return
	if String(hitstop_signature.get("overlap_policy", "")) != "extend_longest_deadline":
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED overlap_policy", battle)
		return
	var kick_pixels := float(camera_signature.get("last_impact_kick_pixels", 0.0))
	var kick = camera_signature.get("last_impact_kick", [])
	if kick_pixels <= 0.05 or kick_pixels > MAX_CAMERA_KICK_PIXELS + 0.01:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED immediate_camera_kick pixels=%.4f" % kick_pixels, battle)
		return
	if not (kick is Array) or kick.size() != 2 or float(kick[0]) <= 0.0:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED camera_kick_direction value=%s" % str(kick), battle)
		return
	if not bool(camera_composition.presentation_signature().get("impact_camera_immediate_kick", false)):
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED camera_contract", battle)
		return
	await create_timer(0.14, true, false, true).timeout
	if absf(Engine.time_scale - 1.0) > 0.001:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED first_hitstop_restore scale=%.4f" % Engine.time_scale, battle)
		return

	# Regression for the historical token bug: a later, shorter hitstop must not
	# truncate an earlier, longer freeze. The strongest scale is retained until
	# the longest real-time deadline expires.
	impact._apply_hitstop(0.100, 0.10)
	await create_timer(0.012, true, false, true).timeout
	impact._apply_hitstop(0.025, 0.06)
	await create_timer(0.040, true, false, true).timeout
	var overlap_signature := impact.hitstop_runtime_signature()
	if not bool(overlap_signature.get("active", false)) or Engine.time_scale >= 0.99:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED overlap_truncated_early", battle)
		return
	if float(overlap_signature.get("active_time_scale", 1.0)) > 0.061:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED strongest_scale_not_preserved value=%.4f" % float(overlap_signature.get("active_time_scale", 1.0)), battle)
		return
	await create_timer(0.070, true, false, true).timeout
	if absf(Engine.time_scale - 1.0) > 0.001 or bool(impact.hitstop_runtime_signature().get("active", true)):
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED overlap_restore", battle)
		return

	# Physical continuity probe: a real accepted hit must still create the First
	# Playable recoil lock and move the defender away after the visual freeze.
	p1.global_position = Vector2(1180.0, 760.0)
	p2.global_position = Vector2(1320.0, 760.0)
	p1.velocity = Vector2.ZERO
	p2.velocity = Vector2.ZERO
	p1.facing = 1.0
	p2.facing = -1.0
	p2._is_blocking = false
	p2._dodge_timer = 0.0
	p2._parry_timer = 0.0
	var recoil_start_x := p2.global_position.x
	var accepted := p2.receive_hit(
		5.0,
		0.0,
		Vector2(220.0, -18.0),
		p1.global_position,
		p1,
		&"torso",
		technique,
		false,
		1.0
	)
	if not accepted:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED real_hit_not_accepted", battle)
		return
	var reaction := p2.first_playable_reaction_signature()
	if not bool(reaction.get("input_locked", false)) or not bool(reaction.get("knockback_locked", false)):
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED recoil_lock_missing signature=%s" % str(reaction), battle)
		return
	if p2.velocity.x < 280.0:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED recoil_velocity value=%.3f" % p2.velocity.x, battle)
		return
	await create_timer(0.12, true, false, true).timeout
	for _frame in range(8):
		await physics_frame
	var recoil_distance := p2.global_position.x - recoil_start_x
	if recoil_distance <= 8.0:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED recoil_not_visible distance=%.3f" % recoil_distance, battle)
		return
	if absf(Engine.time_scale - 1.0) > 0.001:
		_fail("P0_2_IMPACT_FEEL_GATE=BLOCKED time_scale_leaked scale=%.4f" % Engine.time_scale, battle)
		return

	print("P0_2_IMMEDIATE_CAMERA_KICK=PASS directional=true max_px=%.1f observed=%.3f" % [MAX_CAMERA_KICK_PIXELS, kick_pixels])
	print("P0_2_HITSTOP_OVERLAP=PASS policy=extend_longest_deadline clock=monotonic_real_time")
	print("P0_2_KNOCKBACK_CONTINUITY=PASS distance=%.3f" % recoil_distance)
	print("P0_2_IMPACT_FEEL_PRODUCT_GATE=PASS")
	print("SIGNATURE=Tehkné Solutions")
	Engine.time_scale = 1.0
	battle.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(0)

func _wait_for_battle(battle: FirstPlayableController) -> bool:
	for _frame in range(MAX_BATTLE_WAIT_FRAMES):
		if battle._state == FirstPlayableController.MatchState.BATTLE:
			return true
		await process_frame
	return false

func _fail(marker: String, battle: Node = null) -> void:
	Engine.time_scale = 1.0
	push_error(marker)
	print(marker)
	print("SIGNATURE=Tehkné Solutions")
	if is_instance_valid(battle):
		battle.queue_free()
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions