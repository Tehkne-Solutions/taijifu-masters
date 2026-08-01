extends SceneTree

const PROJECT_PATH := "res://project.godot"
const MENU_SCRIPT_PATH := "res://scripts/vertical_slice/first_playable_menu.gd"
const MENU_SCENE_PATH := "res://scenes/vertical_slice/first_playable_menu.tscn"

func _init() -> void:
	var errors: Array[String] = []
	var project_source := _read(PROJECT_PATH)
	var menu_source := _read(MENU_SCRIPT_PATH)
	var menu_scene_source := _read(MENU_SCENE_PATH)

	for forbidden in [
		"MainMenuRuntime=",
		"MainMenuHubRuntime=",
		"CinematicMainMenuRuntime="
	]:
		if project_source.contains(forbidden):
			errors.append("autoload de UI duplicada ainda presente: %s" % forbidden)

	for required in [
		"DEFAULT_PARTICIPANT_CODE",
		'"legacy_nodes_removed": true',
		'"legacy_prototype_exposed": false',
		'"participant_code_required": false',
		'"site_like_panels": false',
		'"form_fields": 0',
		'"quick_game_ui": true',
		"change_scene_to_file(FIRST_PLAYABLE_SCENE)"
	]:
		if not menu_source.contains(required):
			errors.append("contrato de fluxo único ausente: %s" % required)

	for forbidden_script in [
		"participant_panel",
		"participant_input",
		"participant_status",
		"prototype_button",
		"_open_complete_prototype"
	]:
		if menu_source.contains(forbidden_script):
			errors.append("dependência legada ainda presente no controller: %s" % forbidden_script)

	for forbidden_scene in [
		'[node name="Participant"',
		'[node name="ParticipantInput"',
		'[node name="ParticipantStatus"',
		'[node name="PrototypeButton"',
		"ABRIR PROTÓTIPO COMPLETO",
		"FIRST PLAYABLE •"
	]:
		if menu_scene_source.contains(forbidden_scene):
			errors.append("nó/copy legado ainda presente na cena: %s" % forbidden_scene)

	for required_scene in [
		'[node name="Lian"',
		'[node name="Rival"',
		'[node name="PlayButton"',
		'[node name="ExitButton"',
		'text = "JOGAR"',
		'text = "TAIJIFU MASTERS"'
	]:
		if not menu_scene_source.contains(required_scene):
			errors.append("menu de jogo incompleto: %s" % required_scene)

	if errors.is_empty():
		print("SPRINT0_SINGLE_NATIVE_FLOW_CONTRACT_OK")
		quit(0)
		return
	for error in errors:
		push_error(error)
	quit(1)

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()

# Tehkné Solutions
