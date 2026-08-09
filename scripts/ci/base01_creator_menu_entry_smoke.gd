extends SceneTree

const MENU_SCENE := "res://scenes/vertical_slice/first_playable_menu.tscn"
const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := PackedStringArray()
	var menu_packed := load(MENU_SCENE) as PackedScene
	if menu_packed == null:
		_fail(["menu_scene_missing"])
		return
	var menu := menu_packed.instantiate() as FirstPlayableMenuController
	if menu == null:
		_fail(["menu_controller_invalid"])
		return
	get_root().add_child(menu)
	await process_frame
	await process_frame

	if menu.creator_button == null:
		failures.append("creator_button_missing")
	else:
		if menu.creator_button.disabled: failures.append("creator_button_disabled")
		if menu.creator_button.text != "CRIAR LUTADOR": failures.append("creator_button_text")
		if menu.creator_button.pressed.get_connections().is_empty(): failures.append("creator_button_not_connected")
	if menu.play_button == null or menu.play_button.disabled:
		failures.append("play_regressed")
	if get_root().gui_get_focus_owner() != menu.play_button:
		failures.append("initial_focus_not_play")
	if menu.get_node_or_null("Content/Participant") != null:
		failures.append("participant_form_regressed")
	if menu.get_node_or_null("Content/Actions/PrototypeButton") != null:
		failures.append("prototype_regressed")

	var signature := menu.flow_signature()
	if StringName(signature.get("main_action", &"")) != &"play_vs_ai": failures.append("main_action_regressed")
	if String(signature.get("first_playable_scene", "")) != BATTLE_SCENE: failures.append("battle_target_regressed")
	if String(signature.get("creator_scene", "")) != CREATOR_SCENE: failures.append("creator_target")
	if not bool(signature.get("creator_entry_exposed", false)): failures.append("creator_entry_not_exposed")
	if String(signature.get("creator_entry_role", "")) != "secondary_non_blocking": failures.append("creator_role")
	if not bool(signature.get("quick_game_ui", false)): failures.append("quick_game_regressed")
	if not bool(signature.get("quick_game_path_unchanged", false)): failures.append("quick_game_contract")
	if int(signature.get("form_fields", -1)) != 0: failures.append("form_fields_regressed")
	if String(signature.get("keyboard_shortcuts", {}).get("creator", "")) != "C": failures.append("creator_shortcut")

	var creator_packed := load(CREATOR_SCENE) as PackedScene
	if creator_packed == null:
		failures.append("creator_scene_missing")
	else:
		var creator := creator_packed.instantiate() as ModularFighterCreatorShell
		if creator == null:
			failures.append("creator_root_invalid")
		else:
			get_root().add_child(creator)
			await process_frame
			if int(creator.flow_signature().get("identity_options", 0)) != 24:
				failures.append("creator_contract_not_live")
			creator.queue_free()

	if not failures.is_empty():
		_fail(failures)
		return
	print("C62_7_CREATOR_MENU_ENTRY=PASS target=BASE01_CHARACTER_CREATOR_SHELL")
	print("C62_7_QUICK_GAME_REGRESSION=PASS main_action=play_vs_ai focus=play")
	print("C62_7_CREATOR_SHORTCUT=PASS key=C")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _fail(failures: Array) -> void:
	for failure in failures:
		push_error("C62_7_CREATOR_MENU_ENTRY=BLOCKED %s" % String(failure))
	quit(2)
