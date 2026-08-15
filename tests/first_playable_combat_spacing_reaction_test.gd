extends SceneTree

const FIGHTER_SCENE := preload("res://scenes/fighter/first_playable_fighter.tscn")
const FIRST_PLAYABLE_SCENE := preload("res://scenes/vertical_slice/first_playable.tscn")

var _nodes: Array[Node] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _validate_integrated_scene_uses_recovery_runtime():
		return
	if not await _validate_clean_hit_reaction():
		return
	if not await _validate_blocked_recoil():
		return
	if not await _validate_posture_break_reaction():
		return
	if not await _validate_bot_spacing_policy():
		return
	await _cleanup()
	print("FIRST_PLAYABLE_COMBAT_SPACING_REACTION_OK")
	quit(0)

func _spawn_fighter(player_index: int, preset: StringName, position: Vector2) -> FirstPlayableCombatFighterController:
	var fighter := FIGHTER_SCENE.instantiate() as FirstPlayableCombatFighterController
	fighter.player_index = player_index
	fighter.build_preset = preset
	fighter.global_position = position
	root.add_child(fighter)
	_nodes.append(fighter)
	return fighter

func _validate_integrated_scene_uses_recovery_runtime() -> bool:
	FirstPlayableSession.reset()
	var battle := FIRST_PLAYABLE_SCENE.instantiate() as FirstPlayableController
	battle.countdown_step_seconds = 0.01
	battle.fight_command_seconds = 0.01
	root.add_child(battle)
	_nodes.append(battle)
	await process_frame
	await process_frame
	if battle.bot_runtime is not FirstPlayableTacticalBotRuntime:
		await _fail("First Playable scene is not using FirstPlayableTacticalBotRuntime")
		return false
	if battle.player_one is not FirstPlayableCombatFighterController:
		await _fail("Lian Wu is not using FirstPlayableCombatFighterController")
		return false
	if battle.player_two is not FirstPlayableCombatFighterController:
		await _fail("Training Rival is not using FirstPlayableCombatFighterController")
		return false
	await _remove_node(battle)
	return true

func _validate_clean_hit_reaction() -> bool:
	var attacker := _spawn_fighter(1, &"lian_wu_first_playable", Vector2(900, 700))
	var target := _spawn_fighter(2, &"training_rival_first_playable", Vector2(1000, 700))
	await process_frame
	await process_frame

	# Simulate a fighter being caught during an active attack. Human playtest showed
	# that attacks continued to drive the body back into contact immediately.
	target._current_technique = TechniqueCatalog.get_technique(&"gauntlet_center_crush")
	target._attack_phase = FighterController.AttackPhase.ACTIVE
	target._attack_phase_timer = 0.2
	var hit_technique := TechniqueCatalog.get_technique(&"tai_advancing_kick")
	var accepted := target.receive_hit(
		8.0,
		6.0,
		Vector2(20.0, -20.0),
		attacker.global_position,
		attacker,
		&"torso",
		hit_technique
	)
	if not accepted:
		await _fail("clean hit was unexpectedly rejected")
		return false
	var signature := target.first_playable_reaction_signature()
	if String(signature.get("last_reaction_id", "")) != "hit_recoil":
		await _fail("clean hit did not enter hit_recoil")
		return false
	if not bool(signature.get("input_locked", false)) or not bool(signature.get("knockback_locked", false)):
		await _fail("clean hit did not preserve input/knockback reaction locks")
		return false
	if absf(target.velocity.x) < 284.5:
		await _fail("clean hit horizontal separation is below the 285 px/s floor")
		return false
	if target._attack_phase != FighterController.AttackPhase.NONE:
		await _fail("clean hit did not interrupt the active technique")
		return false

	await _remove_node(attacker)
	await _remove_node(target)
	return true

func _validate_blocked_recoil() -> bool:
	var attacker := _spawn_fighter(1, &"lian_wu_first_playable", Vector2(900, 700))
	var target := _spawn_fighter(2, &"training_rival_first_playable", Vector2(1000, 700))
	await process_frame
	await process_frame
	target.facing = -1.0
	target._is_blocking = true
	target._parry_timer = 0.0
	var accepted := target.receive_hit(
		8.0,
		6.0,
		Vector2(20.0, -10.0),
		attacker.global_position,
		attacker,
		&"torso",
		TechniqueCatalog.get_technique(&"ji_body_hook")
	)
	if not accepted:
		await _fail("blocked hit was unexpectedly rejected")
		return false
	var signature := target.first_playable_reaction_signature()
	if String(signature.get("last_reaction_id", "")) != "blocked_recoil":
		await _fail("guard did not enter blocked_recoil")
		return false
	if absf(target.velocity.x) < 117.5:
		await _fail("blocked hit recoil is visually negligible")
		return false
	if bool(signature.get("input_locked", false)):
		await _fail("blocked hit incorrectly applies full clean-hit input lock")
		return false
	await _remove_node(attacker)
	await _remove_node(target)
	return true

func _validate_posture_break_reaction() -> bool:
	var attacker := _spawn_fighter(1, &"lian_wu_first_playable", Vector2(900, 700))
	var target := _spawn_fighter(2, &"training_rival_first_playable", Vector2(1000, 700))
	await process_frame
	await process_frame
	target.posture = 1.0
	target._current_technique = TechniqueCatalog.get_technique(&"gauntlet_center_crush")
	target._attack_phase = FighterController.AttackPhase.STARTUP
	var accepted := target.receive_hit(
		4.0,
		80.0,
		Vector2(30.0, -20.0),
		attacker.global_position,
		attacker,
		&"torso",
		TechniqueCatalog.get_technique(&"ji_shove")
	)
	if not accepted:
		await _fail("posture-breaking hit was unexpectedly rejected")
		return false
	var signature := target.first_playable_reaction_signature()
	if String(signature.get("last_reaction_id", "")) != "posture_break":
		await _fail("posture break did not enter the strong separation reaction")
		return false
	if absf(target.velocity.x) < 429.5:
		await _fail("posture break horizontal separation is below the 430 px/s floor")
		return false
	if target.velocity.y > -104.5:
		await _fail("posture break lacks visible vertical recoil")
		return false
	if target._attack_phase != FighterController.AttackPhase.NONE:
		await _fail("posture break did not cancel the target technique")
		return false
	await _remove_node(attacker)
	await _remove_node(target)
	return true

func _validate_bot_spacing_policy() -> bool:
	var bot_fighter := _spawn_fighter(2, &"training_rival_first_playable", Vector2(1000, 700))
	var opponent := _spawn_fighter(1, &"lian_wu_first_playable", Vector2(1050, 700))
	await process_frame
	await process_frame
	var bot := FirstPlayableTacticalBotRuntime.new()
	bot._bot = bot_fighter
	bot._opponent = opponent

	bot._set_movement(1)
	if bot._movement_direction != -1:
		await _fail("bot did not actively separate inside hard pile-up range")
		return false

	opponent.global_position.x = 1090.0
	bot._set_movement(1)
	if bot._movement_direction != 0:
		await _fail("bot still drives forward inside contact-stop range")
		return false

	opponent.global_position.x = 1075.0
	bot._apply_range_movement(75.0, 1)
	if bot._movement_direction != -1:
		await _fail("bot neutral reset did not retreat when crowded")
		return false

	var signature := bot.first_playable_spacing_signature()
	if not bool(signature.get("close_forward_drive_blocked", false)):
		await _fail("bot spacing signature does not declare close forward-drive guard")
		return false
	if not bool(signature.get("all_routes_can_retreat_when_crowded", false)):
		await _fail("bot spacing recovery is still route-specific")
		return false

	bot.queue_free()
	await _remove_node(bot_fighter)
	await _remove_node(opponent)
	return true

func _remove_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_nodes.erase(node)
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
	await process_frame

func _cleanup() -> void:
	for node in _nodes.duplicate():
		await _remove_node(node)
	FirstPlayableSession.reset()

func _fail(message: String) -> void:
	printerr("FIRST_PLAYABLE_COMBAT_SPACING_REACTION_FAILED: %s" % message)
	await _cleanup()
	quit(1)

# Tehkné Solutions
