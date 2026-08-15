extends SceneTree

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")

var _context: Node2D
var _fighter: FirstPlayableCombatFighterController

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_context = Node2D.new()
	_context.name = "FirstPlayable"
	root.add_child(_context)

	_fighter = FIGHTER_SCENE.instantiate() as FirstPlayableCombatFighterController
	_fighter.player_index = 1
	_fighter.build_preset = &"lian_wu_first_playable"
	_context.add_child(_fighter)
	await process_frame
	await process_frame

	var lian_presenter := FirstPlayableLot01Presenter.new()
	lian_presenter._fighter = _fighter
	var rival_presenter := TrainingRivalLot01Presenter.new()
	rival_presenter._fighter = _fighter

	# A discrete action that still exists while the gameplay lock is active must
	# not visually override the authored hit reaction.
	_fighter._first_playable_input_lock = 0.10
	_fighter._attack_phase = FighterController.AttackPhase.STARTUP
	lian_presenter._hit_visual_timer = 0.30
	rival_presenter._hit_visual_timer = 0.30
	if _fighter.first_playable_visual_action_override_active():
		_fail("action override became active before input lock expired")
		return
	if lian_presenter._resolve_animation() != &"hit" or rival_presenter._resolve_animation() != &"hit":
		_fail("canonical presenters did not preserve hit while gameplay remained locked")
		return

	# Once gameplay is unlocked and an attack is accepted, presentation must yield
	# immediately instead of keeping the 0.30 s hit tail on top of attack startup.
	_fighter._first_playable_input_lock = 0.0
	if not _fighter.first_playable_visual_action_override_active():
		_fail("accepted attack was not exposed as a presentation override")
		return
	if lian_presenter._resolve_animation() != &"attack_light":
		_fail("Lian hit tail masked an accepted attack")
		return
	if rival_presenter._resolve_animation() != &"attack_light":
		_fail("Training Rival hit tail masked an accepted attack")
		return

	# Dodge is also a discrete accepted action and must win over the residual hit tail.
	_fighter._attack_phase = FighterController.AttackPhase.NONE
	_fighter._dodge_timer = 0.20
	lian_presenter._hit_visual_timer = 0.30
	rival_presenter._hit_visual_timer = 0.30
	if lian_presenter._resolve_animation() != &"dodge" or rival_presenter._resolve_animation() != &"dodge":
		_fail("accepted dodge did not override residual hit presentation")
		return

	# Guard follows the same authority rule. This also prevents a blocked contact
	# from being displayed as a generic clean HIT while guard remains valid.
	_fighter._dodge_timer = 0.0
	_fighter._is_blocking = true
	lian_presenter._hit_visual_timer = 0.30
	rival_presenter._hit_visual_timer = 0.30
	if lian_presenter._resolve_animation() != &"guard" or rival_presenter._resolve_animation() != &"guard":
		_fail("accepted guard did not override residual hit presentation")
		return

	var signature := _fighter.first_playable_reaction_signature()
	if not bool(signature.get("visual_action_override_active", false)):
		_fail("reaction signature does not expose the active presentation override")
		return

	print("P0_1_2_REACTION_ACTION_SYNC=PASS")
	print("P0_1_2_GAMEPLAY_AUTHORITY=PASS attack=true dodge=true guard=true")
	print("P0_1_2_CANONICAL_PRESENTERS=PASS lian=true rival=true")
	print("SIGNATURE=Tehkné Solutions")
	_cleanup()
	quit(0)

func _fail(message: String) -> void:
	printerr("P0_1_2_REACTION_ACTION_SYNC=BLOCKED %s" % message)
	_cleanup()
	quit(1)

func _cleanup() -> void:
	if is_instance_valid(_context):
		if _context.get_parent() != null:
			_context.get_parent().remove_child(_context)
		_context.free()
	_context = null
	_fighter = null

# Tehkné Solutions
