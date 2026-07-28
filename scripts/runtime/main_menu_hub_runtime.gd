extends Node

signal hub_opened(section_id: String)
signal hub_closed(section_id: String)
signal navigation_rejected(section_id: String, reason: String)

const SECTIONS := {"profile":"PERFIL","shop":"LOJA DE TREINO","collection":"COLEÇÃO"}
var _active_section := ""

func open_section(section_id: String) -> bool:
	if not SECTIONS.has(section_id):
		navigation_rejected.emit(section_id, "invalid_section")
		return false
	close_active_section(false)
	var menu := get_node_or_null("/root/MainMenuRuntime")
	if menu != null and menu.has_method("hide_for_hub"):
		menu.hide_for_hub()
	match section_id:
		"profile", "shop":
			var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
			if profile == null or not profile.has_method("open_profile"):
				return _reject(section_id, "profile_unavailable")
			profile.open_profile()
		"collection":
			var collection := get_node_or_null("/root/CosmeticCollectionRuntime")
			if collection == null or not collection.has_method("open_collection"):
				return _reject(section_id, "collection_unavailable")
			collection.open_collection()
	_active_section = section_id
	hub_opened.emit(section_id)
	return true

func close_active_section(return_to_menu: bool = true) -> void:
	var closing := _active_section
	if closing in ["profile", "shop"]:
		var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
		if profile != null and profile.has_method("close_profile"):
			profile.close_profile()
	elif closing == "collection":
		var collection := get_node_or_null("/root/CosmeticCollectionRuntime")
		if collection != null and collection.has_method("close_collection"):
			collection.close_collection()
	_active_section = ""
	if closing != "":
		hub_closed.emit(closing)
	if return_to_menu:
		var menu := get_node_or_null("/root/MainMenuRuntime")
		if menu != null and menu.has_method("restore_from_hub"):
			menu.restore_from_hub()

func _reject(section_id: String, reason: String) -> bool:
	_active_section = ""
	navigation_rejected.emit(section_id, reason)
	var menu := get_node_or_null("/root/MainMenuRuntime")
	if menu != null and menu.has_method("restore_from_hub"):
		menu.restore_from_hub()
	return false

func active_section() -> String:
	return _active_section

func is_hub_open() -> bool:
	return _active_section != ""
