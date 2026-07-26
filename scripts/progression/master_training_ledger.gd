class_name MasterTrainingLedger
extends RefCounted

const SAVE_PATH := "user://master_training.json"

var data: Dictionary = {
	"version": 1,
	"profiles": {}
}

func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed := JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = parsed
	if not data.has("profiles") or not (data["profiles"] is Dictionary):
		data["profiles"] = {}

func save_to_disk() -> String:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
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
			"completed_trials": {}
		}
		profiles[profile_id] = profile
		data["profiles"] = profiles
	return profile

func _set_profile(profile_id: String, profile: Dictionary) -> void:
	var profiles: Dictionary = data.get("profiles", {})
	profiles[profile_id] = profile
	data["profiles"] = profiles
