extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_WAIT_FRAMES := 420

var _battle: FirstPlayableController

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	if not FirstPlayableSession.begin_pilot_session("TJFP-001"):
		await _fail("could not begin TJFP-001 pilot session")
		return

	var packed := load(BATTLE_SCENE) as PackedScene
	if packed == null:
		await _fail("could not load First Playable battle scene")
		return
	_battle = packed.instantiate() as FirstPlayableController
	if _battle == null:
		await _fail("battle root has wrong controller")
		return
	_battle.countdown_step_seconds = 0.01
	_battle.fight_command_seconds = 0.01
	_battle.match_time_limit_seconds = 20.0
	root.add_child(_battle)
	await process_frame
	await process_frame

	if not await _wait_for_battle():
		await _fail("battle did not reach active state")
		return

	_battle._finish_match(_battle.player_one, "TESTE")
	if _battle._state != FirstPlayableController.MatchState.RESULT:
		await _fail("battle did not reach result state")
		return

	var guard := root.get_node_or_null("PilotFeedbackGuardRuntime")
	if guard == null:
		await _fail("PilotFeedbackGuardRuntime autoload is missing")
		return
	guard.call("_apply_result_gate", _battle, _battle.hud_controller)

	if not _battle.hud_controller.rematch_button.disabled:
		await _fail("rematch must be blocked before pilot feedback")
		return
	if not _battle.hud_controller.result_menu_button.disabled:
		await _fail("menu must be blocked before pilot feedback")
		return
	if not bool(_battle.hud_controller.get("_qa_visible")):
		await _fail("feedback controls must open automatically in official pilot result")
		return

	_battle.hud_controller.call("_on_feedback_button", &"balanced")
	await process_frame
	guard.call("_apply_result_gate", _battle, _battle.hud_controller)
	if _battle.hud_controller.rematch_button.disabled:
		await _fail("rematch must unlock after required feedback before pilot completion")
		return
	if _battle.hud_controller.result_menu_button.disabled:
		await _fail("menu must unlock after required feedback")
		return

	FirstPlayableSession.pilot_completed_matches = FirstPlayableSession.pilot_expected_matches()
	guard.call("_apply_result_gate", _battle, _battle.hud_controller)
	if not _battle.hud_controller.rematch_button.disabled:
		await _fail("seventh pilot match must be blocked after 6/6")
		return
	if _battle.hud_controller.result_menu_button.disabled:
		await _fail("menu must remain available after pilot completion")
		return
	if _battle.hud_controller.rematch_button.text != "PILOTO CONCLUÍDO":
		await _fail("completed pilot must expose explicit terminal rematch state")
		return

	var signature: Dictionary = guard.call("presentation_signature")
	if not bool(signature.get("feedback_required_before_navigation", false)):
		await _fail("guard signature does not declare feedback fail-closed contract")
		return
	if not bool(signature.get("seventh_match_blocked", false)):
		await _fail("guard signature does not declare seventh-match block")
		return

	await _cleanup()
	FirstPlayableSession.reset()
	print("FIRST_PLAYABLE_PILOT_FEEDBACK_GUARD_OK")
	quit(0)

func _wait_for_battle() -> bool:
	for _frame in range(MAX_WAIT_FRAMES):
		if is_instance_valid(_battle) and _battle._state == FirstPlayableController.MatchState.BATTLE:
			return true
		await process_frame
	return false

func _cleanup() -> void:
	paused = false
	if is_instance_valid(_battle):
		if _battle.get_parent() != null:
			_battle.get_parent().remove_child(_battle)
		_battle.free()
	_battle = null
	await process_frame
	await process_frame

func _fail(message: String) -> void:
	await _cleanup()
	FirstPlayableSession.reset()
	printerr("FIRST_PLAYABLE_PILOT_FEEDBACK_GUARD_FAILED: %s" % message)
	quit(1)

# Tehkné Solutions
