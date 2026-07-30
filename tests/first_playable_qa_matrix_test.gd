extends SceneTree

const SCENE_PATH := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_WAIT_FRAMES := 420
const DIFFICULTY_SEQUENCE: Array[StringName] = [
	&"apprentice", &"disciple", &"master",
	&"apprentice", &"disciple", &"master",
	&"apprentice", &"disciple", &"master", &"disciple"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
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
	controller.match_time_limit_seconds = 12.0
	root.add_child(controller)

	var completed := 0
	for match_index in range(DIFFICULTY_SEQUENCE.size()):
		var difficulty_id := DIFFICULTY_SEQUENCE[match_index]
		controller.difficulty_controller.set_difficulty(difficulty_id)
		if match_index > 0:
			controller._start_match()
		if not await _wait_for_state(controller, FirstPlayableController.MatchState.BATTLE):
			_fail("match %d did not reach BATTLE" % (match_index + 1))
			return
		if controller.bot_runtime.difficulty_id != difficulty_id:
			_fail("match %d did not apply %s" % [match_index + 1, String(difficulty_id)])
			return
		if not controller.bot_runtime.enabled:
			_fail("match %d started with AI disabled" % (match_index + 1))
			return
		if not is_instance_valid(controller.player_one) or not is_instance_valid(controller.player_two):
			_fail("match %d has invalid fighters" % (match_index + 1))
			return

		# Permite que navegação, gravidade e decisões da IA processem em todos os
		# níveis antes de encerrar a partida de forma determinística.
		for _frame in range(36):
			await physics_frame
			if controller._state != FirstPlayableController.MatchState.BATTLE:
				break

		if controller._state == FirstPlayableController.MatchState.BATTLE:
			if match_index % 3 == 2:
				controller.player_one.health = controller.player_one.build.max_health()
				controller.player_two.health = controller.player_two.build.max_health() * 0.35
				controller._time_remaining = 0.0
			else:
				var defeated := controller.player_two if match_index % 2 == 0 else controller.player_one
				defeated.receive_hit(
					9999.0,
					9999.0,
					Vector2.ZERO,
					defeated.global_position,
					null,
					&"torso",
					null,
					true
				)

		if not await _wait_for_state(controller, FirstPlayableController.MatchState.RESULT):
			_fail("match %d did not reach RESULT" % (match_index + 1))
			return
		if controller.bot_runtime.enabled:
			_fail("match %d left AI enabled after result" % (match_index + 1))
			return
		if not (controller.get_node("HUD/ResultOverlay") as Control).visible:
			_fail("match %d did not show result overlay" % (match_index + 1))
			return
		completed += 1

	if completed != 10:
		_fail("expected 10 completed matches, found %d" % completed)
		return
	if FirstPlayableSession.selected_difficulty_id != DIFFICULTY_SEQUENCE[-1]:
		_fail("session did not preserve final QA difficulty")
		return

	print("FIRST_PLAYABLE_QA_MATRIX_OK • 10 MATCHES")
	quit(0)

func _wait_for_state(controller: FirstPlayableController, expected_state: int) -> bool:
	for _frame in range(MAX_WAIT_FRAMES):
		if controller._state == expected_state:
			return true
		await process_frame
	return false

func _fail(message: String) -> void:
	paused = false
	printerr("FIRST_PLAYABLE_QA_MATRIX_FAILED: %s" % message)
	quit(1)
