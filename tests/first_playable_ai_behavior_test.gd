extends SceneTree

const SCENE_PATH := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_STATE_WAIT_FRAMES := 420
const NAVIGATION_TEST_FRAMES := 360
const OFFENSE_TEST_FRAMES := 480

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(1337)
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("could not load %s" % SCENE_PATH)
		return

	var controller := packed.instantiate() as FirstPlayableController
	if controller == null:
		_fail("scene root is not FirstPlayableController")
		return
	controller.countdown_step_seconds = 0.01
	controller.fight_command_seconds = 0.01
	controller.match_time_limit_seconds = 30.0
	root.add_child(controller)
	await process_frame
	await process_frame

	var difficulty := controller.get_node_or_null("DifficultyController") as FirstPlayableDifficultyController
	var bot := controller.get_node_or_null("TacticalBotRuntime") as TacticalBotRuntime
	if not _validate_difficulty_contract(difficulty, bot):
		return

	difficulty.set_difficulty(&"master")
	if not await _wait_for_battle(controller):
		_fail("First Playable did not reach BATTLE")
		return
	if not is_instance_valid(controller.player_one) or not is_instance_valid(controller.player_two):
		_fail("fighters are invalid after countdown")
		return
	if not bot.enabled or bot.difficulty_id != &"master":
		_fail("bot did not start with selected master difficulty")
		return

	if not await _validate_navigation(controller, bot):
		return
	if not await _validate_offense(controller, bot):
		return
	if not await _validate_rematch_persistence(controller, difficulty, bot):
		return

	print("FIRST_PLAYABLE_AI_BEHAVIOR_OK")
	quit(0)

func _validate_difficulty_contract(
	difficulty: FirstPlayableDifficultyController,
	bot: TacticalBotRuntime
) -> bool:
	if not is_instance_valid(difficulty) or not is_instance_valid(bot):
		_fail("difficulty controller or tactical bot is missing")
		return false
	var signature := difficulty.selection_signature()
	var ids: Array = signature.get("difficulty_ids", [])
	if ids != [&"apprentice", &"disciple", &"master"]:
		_fail("First Playable difficulty order is invalid: %s" % str(ids))
		return false
	if StringName(signature.get("default_id", &"")) != &"disciple":
		_fail("default difficulty must be disciple")
		return false
	if not bool(signature.get("persists_across_rematch", false)):
		_fail("difficulty contract must persist across rematch")
		return false

	var apprentice := BotBehaviorCatalog.difficulty(&"apprentice")
	var disciple := BotBehaviorCatalog.difficulty(&"disciple")
	var master := BotBehaviorCatalog.difficulty(&"master")
	if not (
		float(apprentice.get("mistake_chance", 0.0))
		> float(disciple.get("mistake_chance", 0.0))
		and float(disciple.get("mistake_chance", 0.0))
		> float(master.get("mistake_chance", 0.0))
	):
		_fail("difficulty mistake chances are not strictly ordered")
		return false
	if not (
		float(apprentice.get("decision_max", 0.0))
		> float(disciple.get("decision_max", 0.0))
		and float(disciple.get("decision_max", 0.0))
		> float(master.get("decision_max", 0.0))
	):
		_fail("difficulty decision delays are not strictly ordered")
		return false
	return true

func _validate_navigation(
	controller: FirstPlayableController,
	bot: TacticalBotRuntime
) -> bool:
	var player := controller.player_one
	var cpu := controller.player_two
	player.global_position = Vector2(1750.0, 760.0)
	cpu.global_position = Vector2(850.0, 760.0)
	player.velocity = Vector2.ZERO
	cpu.velocity = Vector2.ZERO
	bot._reset_decision_state("AI TEST NAVIGATION")
	var initial_position := cpu.global_position

	for _frame in range(NAVIGATION_TEST_FRAMES):
		await physics_frame
		if controller._state != FirstPlayableController.MatchState.BATTLE:
			_fail("match ended before navigation validation")
			return false
		if absf(cpu.global_position.x - initial_position.x) > 24.0 or absf(cpu.velocity.x) > 30.0:
			return true
	_fail("bot did not navigate toward a distant opponent")
	return false

func _validate_offense(
	controller: FirstPlayableController,
	bot: TacticalBotRuntime
) -> bool:
	var player := controller.player_one
	var cpu := controller.player_two
	player.global_position = Vector2(1320.0, 760.0)
	cpu.global_position = Vector2(1395.0, 760.0)
	player.velocity = Vector2.ZERO
	cpu.velocity = Vector2.ZERO
	player.health = player.build.max_health()
	bot._reset_decision_state("AI TEST OFFENSE")
	var initial_health := player.health

	for _frame in range(OFFENSE_TEST_FRAMES):
		await physics_frame
		if cpu._attack_phase != FighterController.AttackPhase.NONE:
			return true
		if is_instance_valid(cpu._grabbed_target):
			return true
		if player.health < initial_health - 0.01:
			return true
		if controller._state == FirstPlayableController.MatchState.RESULT:
			return true
	_fail("bot did not attempt an offensive action at close range")
	return false

func _validate_rematch_persistence(
	controller: FirstPlayableController,
	difficulty: FirstPlayableDifficultyController,
	bot: TacticalBotRuntime
) -> bool:
	controller._start_match()
	for _frame in range(12):
		await process_frame
	if difficulty.selected_difficulty_id != &"master":
		_fail("selected difficulty was lost on rematch")
		return false
	if bot.difficulty_id != &"master":
		_fail("bot difficulty was not restored on rematch")
		return false
	return true

func _wait_for_battle(controller: FirstPlayableController) -> bool:
	for _frame in range(MAX_STATE_WAIT_FRAMES):
		if controller._state == FirstPlayableController.MatchState.BATTLE:
			return true
		await process_frame
	return false

func _fail(message: String) -> void:
	printerr("FIRST_PLAYABLE_AI_BEHAVIOR_FAILED: %s" % message)
	quit(1)
