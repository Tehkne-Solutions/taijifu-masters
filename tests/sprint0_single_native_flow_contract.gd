extends SceneTree

const PROJECT_PATH := "res://project.godot"
const MENU_SCRIPT_PATH := "res://scripts/vertical_slice/first_playable_menu.gd"

func _init() -> void:
	var errors: Array[String] = []
	var project_source := _read(PROJECT_PATH)
	var menu_source := _read(MENU_SCRIPT_PATH)

	for forbidden in [
		"MainMenuRuntime=",
		"MainMenuHubRuntime=",
		"CinematicMainMenuRuntime="
	]:
		if project_source.contains(forbidden):
			errors.append("autoload de UI duplicada ainda presente: %s" % forbidden)

	for required in [
		"DEFAULT_PARTICIPANT_CODE",
		"participant_panel.visible = false",
		"prototype_button.visible = false",
		'"legacy_prototype_exposed": false',
		'"participant_code_required": false',
		"change_scene_to_file(FIRST_PLAYABLE_SCENE)"
	]:
		if not menu_source.contains(required):
			errors.append("contrato de fluxo único ausente: %s" % required)

	if menu_source.contains("_open_complete_prototype"):
		errors.append("atalho para o protótipo completo voltou ao menu")

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
