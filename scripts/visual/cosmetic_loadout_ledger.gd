class_name CosmeticLoadoutLedger
extends RefCounted

const SAVE_PATH := "user://cosmetic_loadout.json"

var data: Dictionary = {"version": 1, "profiles": {}}

func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = parsed
	if not data.has("profiles") or not (data["profiles"] is Dictionary):
		data["profiles"] = {}

func save_to_disk() -> String:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
	data["version"] = 1
	data["updated_unix"] = int(Time.get_unix_time_from_system())
	file.store_string(JSON.stringify(data, "\t"))
	return SAVE_PATH

func loadout_for(profile_id: String, character_id: StringName) -> Dictionary:
	var profiles: Dictionary = data.get("profiles", {})
	var stored: Variant = profiles.get(profile_id, {})
	var loadout := CosmeticSocketCatalog.default_loadout(character_id)
	if stored is Dictionary:
		var stored_dictionary: Dictionary = stored
		for socket_id in CosmeticSocketCatalog.SOCKET_IDS:
			var key := String(socket_id)
			var candidate := StringName(stored_dictionary.get(key, loadout.get(key, "none")))
			if candidate in CosmeticSocketCatalog.options_for(socket_id):
				loadout[key] = String(candidate)
	return loadout

func set_loadout(profile_id: String, loadout: Dictionary) -> void:
	var profiles: Dictionary = data.get("profiles", {})
	var sanitized: Dictionary = {}
	for socket_id in CosmeticSocketCatalog.SOCKET_IDS:
		var key := String(socket_id)
		var candidate := StringName(loadout.get(key, "none"))
		if candidate not in CosmeticSocketCatalog.options_for(socket_id):
			candidate = &"none"
		sanitized[key] = String(candidate)
	profiles[profile_id] = sanitized
	data["profiles"] = profiles

func cycle_item(
	profile_id: String,
	character_id: StringName,
	socket_id: StringName,
	direction: int
) -> Dictionary:
	var loadout := loadout_for(profile_id, character_id)
	var options := CosmeticSocketCatalog.options_for(socket_id)
	if options.is_empty():
		return loadout
	var key := String(socket_id)
	var current := StringName(loadout.get(key, "none"))
	var index := options.find(current)
	if index < 0:
		index = 0
	index = wrapi(index + direction, 0, options.size())
	loadout[key] = String(options[index])
	set_loadout(profile_id, loadout)
	return loadout

func reset_profile(profile_id: String, character_id: StringName) -> Dictionary:
	var loadout := CosmeticSocketCatalog.default_loadout(character_id)
	set_loadout(profile_id, loadout)
	return loadout
