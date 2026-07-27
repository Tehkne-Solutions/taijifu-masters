class_name MasterTrainingLedger
extends RefCounted

const SAVE_PATH := "user://master_training.json"

var data: Dictionary = {
	"version": 2,
	"profiles": {}
}

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
	data["version"] = 2
	_migrate_profiles()

func save_to_disk() -> String:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
	data["version"] = 2
	data["updated_unix"] = int(Time.get_unix_time_from_system())
	file.store_string(JSON.stringify(data, "\t"))
	return SAVE_PATH

func unlock_variant(profile_id: String, master_id: StringName, variant_id: StringName) -> bool:
	var profile := _profile(profile_id)
	var unlocked: Array = profile.get("unlocked_variants", [])
	var variant_key := String(variant_id)
	var changed := false
	if variant_key not in unlocked:
		unlocked.append(variant_key)
		changed = true
	profile["unlocked_variants"] = unlocked
	var completed: Dictionary = profile.get("completed_trials", {})
	completed[String(master_id)] = {
		"variant_id": variant_key,
		"completed_unix": int(Time.get_unix_time_from_system())
	}
	profile["completed_trials"] = completed
	_set_profile(profile_id, profile)
	return changed

func is_unlocked(profile_id: String, variant_id: StringName) -> bool:
	return String(variant_id) in unlocked_variants(profile_id)

func unlocked_variants(profile_id: String) -> Array:
	var profile := _profile(profile_id)
	var unlocked: Array = profile.get("unlocked_variants", [])
	return unlocked.duplicate()

func selected_variant(profile_id: String) -> StringName:
	var profile := _profile(profile_id)
	var selected := StringName(profile.get("selected_variant", ""))
	if selected != &"" and not is_unlocked(profile_id, selected):
		profile["selected_variant"] = ""
		_set_profile(profile_id, profile)
		return &""
	return selected

func selected_variants(profile_id: String) -> Array:
	var selected := selected_variant(profile_id)
	return [] if selected == &"" else [String(selected)]

func set_selected_variant(profile_id: String, variant_id: StringName) -> bool:
	if variant_id != &"" and not is_unlocked(profile_id, variant_id):
		return false
	var profile := _profile(profile_id)
	var previous := StringName(profile.get("selected_variant", ""))
	profile["selected_variant"] = String(variant_id)
	_set_profile(profile_id, profile)
	return previous != variant_id

func cycle_selected_variant(profile_id: String, direction: int) -> StringName:
	var options: Array[StringName] = [&""]
	for variant_value in unlocked_variants(profile_id):
		options.append(StringName(variant_value))
	if options.size() <= 1:
		set_selected_variant(profile_id, &"")
		return &""
	var current := selected_variant(profile_id)
	var index := options.find(current)
	if index < 0:
		index = 0
	index = wrapi(index + direction, 0, options.size())
	set_selected_variant(profile_id, options[index])
	return options[index]

func completed_master_ids(profile_id: String) -> Array[StringName]:
	var profile := _profile(profile_id)
	var completed: Dictionary = profile.get("completed_trials", {})
	var result: Array[StringName] = []
	for key in completed.keys():
		result.append(StringName(key))
	return result

func _profile(profile_id: String) -> Dictionary:
	var profiles: Dictionary = data.get("profiles", {})
	var profile: Dictionary = profiles.get(profile_id, {})
	if profile.is_empty():
		profile = {
			"unlocked_variants": [],
			"completed_trials": {},
			"selected_variant": ""
		}
		profiles[profile_id] = profile
		data["profiles"] = profiles
	elif not profile.has("selected_variant"):
		profile["selected_variant"] = ""
		profiles[profile_id] = profile
		data["profiles"] = profiles
	return profile

func _set_profile(profile_id: String, profile: Dictionary) -> void:
	var profiles: Dictionary = data.get("profiles", {})
	profiles[profile_id] = profile
	data["profiles"] = profiles

func _migrate_profiles() -> void:
	var profiles: Dictionary = data.get("profiles", {})
	for profile_id in profiles.keys():
		var profile: Dictionary = profiles[profile_id]
		if not profile.has("selected_variant"):
			profile["selected_variant"] = ""
		profiles[profile_id] = profile
	data["profiles"] = profiles
