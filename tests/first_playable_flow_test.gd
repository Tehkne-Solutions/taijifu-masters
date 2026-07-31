extends SceneTree

const MENU_SCENE := "res://scenes/vertical_slice/first_playable_menu.tscn"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_WAIT_FRAMES := 420

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	if String(ProjectSettings.get_setting("application/run/main_scene", "")) != MENU_SCENE:
		_fail("First Playable menu is not the default project entry point")
		return

	var menu_packed := load(MENU_SCENE) as PackedScene
	if menu_packed == null:
		_fail("could not load First Playable menu")
		return
	var menu := menu_packed.instantiate() as FirstPlayableMenuController
	if menu == null:
		_fail("menu root has the wrong controller")
		return
	root.add_child(menu)
	await process_frame
	await process_frame

	if not _validate_menu(menu):
		return
	if not menu.play_button.disabled:
		_fail("play must remain blocked before an anonymous code is entered")
		return
	if menu.set_participant_code("000"):
		_fail("participant code zero must be rejected")
		return
	if not menu.play_button.disabled:
		_fail("invalid participant code did not keep play blocked")
		return
	if not menu.set_participant_code("003"):
		_fail("three participant digits were not normalized")
		return
	if FirstPlayableSession.participant_code != "TJFP-003":
		_fail("participant code was not normalized and persisted")
		return
	if menu.play_button.disabled:
		_fail("valid participant code did not enable play")
		return
	if "TJFP-003" not in menu.participant_status.text:
		_fail("menu did not confirm the anonymous participant code")
		return

	menu.select_difficulty(&"master")
	if FirstPlayableSession.selected_difficulty_id != &"master":
		_fail("menu did not persist master difficulty")
		return
	if "MESTRE" not in menu.difficulty_label.text:
		_fail("menu did not refresh the selected difficulty label")
		return

	root.remove_child(menu)
	menu.queue_free()
	await process_frame

	var battle_packed := load(BATTLE_SCENE) as PackedScene
	if battle_packed == null:
		_fail("could not load First Playable battle")
		return
	var battle := battle_packed.instantiate() as FirstPlayableController
	if battle == null:
		_fail("battle root has the wrong controller")
		return
	battle.countdown_step_seconds = 0.01
	battle.fight_command_seconds = 0.01
	battle.match_time_limit_seconds = 20.0
	root.add_child(battle)
	await process_frame
	await process_frame

	if battle.difficulty_controller.selected_difficulty_id != &"master":
		_fail("battle did not inherit menu difficulty")
		return
	if battle.bot_runtime.difficulty_id != &"master":
		_fail("bot did not receive menu difficulty")
		return
	var session_metadata: Dictionary = battle._telemetry.session_snapshot().get("metadata", {})
	if String(session_metadata.get("participant_code", "")) != "TJFP-003":
		_fail("battle telemetry did not inherit participant code")
		return
	if String(session_metadata.get("pilot_id", "")) != FirstPlayableSession.PILOT_ID:
		_fail("battle telemetry did not inherit pilot ID")
		return
	if not await _wait_for_battle(battle):
		_fail("battle did not reach active combat")
		return

	battle._update_hud()
	if not _validate_resource_bars(battle):
		return

	battle._set_paused(true)
	if not paused or not battle._is_paused:
		_fail("pause did not stop the scene tree")
		return
	if not (battle.get_node("HUD/PauseOverlay") as Control).visible:
		_fail("pause overlay did not become visible")
		return
	battle._resume_match()
	if paused or battle._is_paused:
		_fail("resume did not restore the scene tree")
		return

	battle._finish_match(battle.player_one, "TESTE")
	if battle._state != FirstPlayableController.MatchState.RESULT:
		_fail("battle did not reach result state")
		return
	var result_overlay := battle.get_node("HUD/ResultOverlay") as Control
	var result_title := battle.get_node("HUD/ResultOverlay/Panel/Content/Title") as Label
	if not result_overlay.visible or result_title.text != "VITÓRIA":
		_fail("result overlay did not present player victory")
		return
	if not battle._last_telemetry_path.get_file().begins_with("TJFP-003__taijifu_"):
		_fail("telemetry filename did not include the anonymous participant code")
		return

	if not await _validate_playtest_feedback(battle):
		return

	var rematch_button := battle.get_node("HUD/ResultOverlay/Panel/Content/RematchButton") as Button
	rematch_button.emit_signal("pressed")
	await process_frame
	if battle._state != FirstPlayableController.MatchState.COUNTDOWN:
		_fail("rematch button did not start a new countdown")
		return
	if result_overlay.visible:
		_fail("result overlay remained visible after rematch")
		return
	if battle.difficulty_controller.selected_difficulty_id != &"master":
		_fail("difficulty was lost after UI rematch")
		return
	if FirstPlayableSession.participant_code != "TJFP-003":
		_fail("participant code was lost after UI rematch")
		return
	var previous_round := battle._telemetry.last_round_snapshot()
	var previous_metadata: Dictionary = previous_round.get("metadata", {})
	if not bool(previous_metadata.get("rematch_requested", false)):
		_fail("rematch was not attached to the completed playtest round")
		return

	FirstPlayableSession.reset()
	print("FIRST_PLAYABLE_FLOW_OK")
	quit(0)

func _validate_menu(menu: FirstPlayableMenuController) -> bool:
	for path in [
		"Content/Participant/ParticipantInput",
		"Content/Participant/ParticipantStatus",
		"Content/Actions/PlayButton",
		"Content/Actions/PrototypeButton",
		"Content/Actions/ExitButton",
		"Content/Difficulty/Options/EasyButton",
		"Content/Difficulty/Options/NormalButton",
		"Content/Difficulty/Options/HardButton",
		"Signature"
	]:
		if menu.get_node_or_null(path) == null:
			_fail("menu node is missing: %s" % path)
			return false
	var signature := menu.flow_signature()
	if StringName(signature.get("main_action", &"")) != &"play_vs_ai":
		_fail("menu main action is invalid")
		return false
	if String(signature.get("first_playable_scene", "")) != BATTLE_SCENE:
		_fail("menu battle target is invalid")
		return false
	if String(signature.get("complete_prototype_scene", "")) != "res://scenes/main.tscn":
		_fail("complete prototype fallback is missing")
		return false
	if not bool(signature.get("participant_code_required", false)):
		_fail("menu signature must require an anonymous participant code")
		return false
	if String(signature.get("participant_code_pattern", "")) != "TJFP-###":
		_fail("menu signature participant pattern is invalid")
		return false
	if String(signature.get("pilot_id", "")) != FirstPlayableSession.PILOT_ID:
		_fail("menu signature pilot ID is invalid")
		return false
	if not bool(signature.get("mouse_supported", false)) or not bool(signature.get("gamepad_focus_supported", false)):
		_fail("menu must support mouse and focused gamepad navigation")
		return false
	return true

func _validate_resource_bars(battle: FirstPlayableController) -> bool:
	var bars := [
		battle.get_node("HUD/P1Health") as ProgressBar,
		battle.get_node("HUD/P1Posture") as ProgressBar,
		battle.get_node("HUD/P1Stamina") as ProgressBar,
		battle.get_node("HUD/P2Health") as ProgressBar,
		battle.get_node("HUD/P2Posture") as ProgressBar,
		battle.get_node("HUD/P2Stamina") as ProgressBar
	]
	for bar in bars:
		if not is_instance_valid(bar) or bar.max_value <= 0.0 or bar.value <= 0.0:
			_fail("resource bar was not initialized")
			return false
	return true

func _validate_playtest_feedback(battle: FirstPlayableController) -> bool:
	var content_path := "HUD/ResultOverlay/Panel/Content/"
	var balanced_button := battle.get_node_or_null(
		content_path + "PlaytestFeedbackButtons/FeedbackBalanced"
	) as Button
	var copy_button := battle.get_node_or_null(content_path + "CopyPlaytestReportButton") as Button
	var feedback_status := battle.get_node_or_null(content_path + "PlaytestFeedbackStatus") as Label
	if not is_instance_valid(balanced_button):
		_fail("balanced feedback button is missing")
		return false
	if not is_instance_valid(copy_button):
		_fail("copy playtest report button is missing")
		return false
	if not is_instance_valid(feedback_status):
		_fail("playtest feedback status is missing")
		return false

	var signature := battle.hud_controller.presentation_signature()
	if not bool(signature.get("playtest_feedback", false)):
		_fail("HUD signature does not expose playtest feedback")
		return false
	if int(signature.get("balance_feedback_options", 0)) != 3:
		_fail("HUD must expose three balance feedback options")
		return false
	if not bool(signature.get("copy_report_button", false)):
		_fail("HUD signature does not expose report copy")
		return false

	balanced_button.emit_signal("pressed")
	await process_frame
	if not balanced_button.disabled:
		_fail("feedback button remained enabled after submission")
		return false
	var last_round := battle._telemetry.last_round_snapshot()
	var metadata: Dictionary = last_round.get("metadata", {})
	if String(metadata.get("balance_feedback", "")) != "balanced":
		_fail("balance feedback was not attached to the completed round")
		return false
	if "SESSÃO" not in feedback_status.text:
		_fail("feedback status did not expose the local session ID")
		return false
	return true

func _wait_for_battle(battle: FirstPlayableController) -> bool:
	for _frame in range(MAX_WAIT_FRAMES):
		if battle._state == FirstPlayableController.MatchState.BATTLE:
			return true
		await process_frame
	return false

func _fail(message: String) -> void:
	paused = false
	printerr("FIRST_PLAYABLE_FLOW_FAILED: %s" % message)
	quit(1)
