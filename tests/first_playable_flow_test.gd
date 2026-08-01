extends SceneTree

const MENU_SCENE := "res://scenes/vertical_slice/first_playable_menu.tscn"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_WAIT_FRAMES := 420

var _active_scene: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	if String(ProjectSettings.get_setting("application/run/main_scene", "")) != MENU_SCENE:
		await _fail("First Playable menu is not the default project entry point")
		return

	var menu_packed := load(MENU_SCENE) as PackedScene
	if menu_packed == null:
		await _fail("could not load First Playable menu")
		return
	var menu := menu_packed.instantiate() as FirstPlayableMenuController
	if menu == null:
		await _fail("menu root has the wrong controller")
		return
	_active_scene = menu
	root.add_child(menu)
	await process_frame
	await process_frame

	if not _validate_menu(menu):
		return
	if menu.play_button.disabled:
		await _fail("play must be enabled on first entry")
		return
	if FirstPlayableSession.participant_code != "TJFP-001":
		await _fail("default anonymous participant code was not applied internally")
		return

	menu.select_difficulty(&"master")
	if FirstPlayableSession.selected_difficulty_id != &"master":
		await _fail("menu did not persist master difficulty")
		return
	if "MESTRE" not in menu.difficulty_label.text:
		await _fail("menu did not refresh the selected difficulty label")
		return

	await _dispose_active_scene()

	var battle_packed := load(BATTLE_SCENE) as PackedScene
	if battle_packed == null:
		await _fail("could not load First Playable battle")
		return
	var battle := battle_packed.instantiate() as FirstPlayableController
	if battle == null:
		await _fail("battle root has the wrong controller")
		return
	battle.countdown_step_seconds = 0.01
	battle.fight_command_seconds = 0.01
	battle.match_time_limit_seconds = 20.0
	_active_scene = battle
	root.add_child(battle)
	await process_frame
	await process_frame

	if battle.difficulty_controller.selected_difficulty_id != &"master":
		await _fail("battle did not inherit menu difficulty")
		return
	if battle.bot_runtime.difficulty_id != &"master":
		await _fail("bot did not receive menu difficulty")
		return
	if not await _wait_for_battle(battle):
		await _fail("battle did not reach active combat")
		return

	battle._update_hud()
	if not _validate_resource_bars(battle):
		return

	battle._set_paused(true)
	if not paused or not battle._is_paused:
		await _fail("pause did not stop the scene tree")
		return
	if not (battle.get_node("HUD/PauseOverlay") as Control).visible:
		await _fail("pause overlay did not become visible")
		return
	battle._resume_match()
	if paused or battle._is_paused:
		await _fail("resume did not restore the scene tree")
		return

	battle._finish_match(battle.player_one, "TESTE")
	if battle._state != FirstPlayableController.MatchState.RESULT:
		await _fail("battle did not reach result state")
		return
	var result_overlay := battle.get_node("HUD/ResultOverlay") as Control
	var result_title := battle.get_node("HUD/ResultOverlay/Panel/Content/Title") as Label
	if not result_overlay.visible or result_title.text != "VITÓRIA":
		await _fail("result overlay did not present player victory")
		return

	var rematch_button := battle.get_node("HUD/ResultOverlay/Panel/Content/RematchButton") as Button
	rematch_button.emit_signal("pressed")
	await process_frame
	if battle._state != FirstPlayableController.MatchState.COUNTDOWN:
		await _fail("rematch button did not start a new countdown")
		return
	if result_overlay.visible:
		await _fail("result overlay remained visible after rematch")
		return
	if battle.difficulty_controller.selected_difficulty_id != &"master":
		await _fail("difficulty was lost after rematch")
		return

	await _dispose_active_scene()
	FirstPlayableSession.reset()
	print("FIRST_PLAYABLE_FLOW_OK")
	quit(0)

func _validate_menu(menu: FirstPlayableMenuController) -> bool:
	for path in [
		"Content/Fighters/Lian/Name",
		"Content/Fighters/Rival/Name",
		"Content/Actions/PlayButton",
		"Content/Actions/ExitButton",
		"Content/Difficulty/Options/EasyButton",
		"Content/Difficulty/Options/NormalButton",
		"Content/Difficulty/Options/HardButton",
		"Signature"
	]:
		if menu.get_node_or_null(path) == null:
			call_deferred("_fail", "menu node is missing: %s" % path)
			return false

	if menu.get_node_or_null("Content/Participant") != null:
		call_deferred("_fail", "participant form must not exist in player UI")
		return false
	if menu.get_node_or_null("Content/Actions/PrototypeButton") != null:
		call_deferred("_fail", "legacy prototype button must be physically removed")
		return false

	var signature := menu.flow_signature()
	if StringName(signature.get("main_action", &"")) != &"play_vs_ai":
		call_deferred("_fail", "menu main action is invalid")
		return false
	if String(signature.get("first_playable_scene", "")) != BATTLE_SCENE:
		call_deferred("_fail", "menu battle target is invalid")
		return false
	if bool(signature.get("participant_code_required", true)):
		call_deferred("_fail", "participant code must not block entry")
		return false
	if bool(signature.get("legacy_prototype_exposed", true)):
		call_deferred("_fail", "legacy prototype must not be exposed")
		return false
	if not bool(signature.get("legacy_nodes_removed", false)):
		call_deferred("_fail", "legacy menu nodes must be removed")
		return false
	if bool(signature.get("site_like_panels", true)):
		call_deferred("_fail", "menu must not use site-like panels")
		return false
	if int(signature.get("form_fields", -1)) != 0:
		call_deferred("_fail", "menu must not expose form fields")
		return false
	if not bool(signature.get("quick_game_ui", false)):
		call_deferred("_fail", "menu must expose quick game UI")
		return false
	if not bool(signature.get("mouse_supported", false)) or not bool(signature.get("gamepad_focus_supported", false)):
		call_deferred("_fail", "menu must support mouse and focused gamepad navigation")
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
			call_deferred("_fail", "resource bar was not initialized")
			return false
	return true

func _wait_for_battle(battle: FirstPlayableController) -> bool:
	for _frame in range(MAX_WAIT_FRAMES):
		if battle._state == FirstPlayableController.MatchState.BATTLE:
			return true
		await process_frame
	return false

func _dispose_active_scene() -> void:
	paused = false
	if is_instance_valid(_active_scene):
		if _active_scene.get_parent() != null:
			_active_scene.get_parent().remove_child(_active_scene)
		_active_scene.free()
	_active_scene = null
	await process_frame
	await process_frame

func _fail(message: String) -> void:
	await _dispose_active_scene()
	FirstPlayableSession.reset()
	printerr("FIRST_PLAYABLE_FLOW_FAILED: %s" % message)
	quit(1)

# Tehkné Solutions
