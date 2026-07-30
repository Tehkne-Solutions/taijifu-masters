extends SceneTree

const SCENE_PATH := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_WAIT_FRAMES := 240

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
	controller.match_time_limit_seconds = 5.0
	root.add_child(controller)

	for cycle in range(3):
		if not await _wait_for_state(controller, FirstPlayableController.MatchState.BATTLE):
			_fail("cycle %d did not reach BATTLE" % (cycle + 1))
			return
		if not is_instance_valid(controller.player_one) or not is_instance_valid(controller.player_two):
			_fail("cycle %d has invalid fighters" % (cycle + 1))
			return

		if cycle < 2:
			controller.player_two.receive_hit(
				9999.0,
				9999.0,
				Vector2.ZERO,
				controller.player_two.global_position,
				null,
				&"torso",
				null,
				true
			)
		else:
			controller.player_one.health = controller.player_one.build.max_health()
			controller.player_two.health = controller.player_two.build.max_health() * 0.25
			controller._time_remaining = 0.0

		if not await _wait_for_state(controller, FirstPlayableController.MatchState.RESULT):
			_fail("cycle %d did not reach RESULT" % (cycle + 1))
			return

		if cycle < 2:
			controller._start_match()

	print("FIRST_PLAYABLE_MATCH_CYCLE_OK")
	quit(0)

func _wait_for_state(controller: FirstPlayableController, expected_state: int) -> bool:
	for _frame in range(MAX_WAIT_FRAMES):
		if controller._state == expected_state:
			return true
		await process_frame
	return false

func _fail(message: String) -> void:
	printerr("FIRST_PLAYABLE_MATCH_CYCLE_FAILED: %s" % message)
	quit(1)
