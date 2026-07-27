class_name PlayerProfileLedger
extends RefCounted

const SAVE_PATH := "user://player_profiles.json"
const VERSION := 1
const MAX_PROFILES := 12

var data: Dictionary = default_state()

static func default_state() -> Dictionary:
	return {
		"version": VERSION,
		"profiles": [
			{"profile_id": "profile_p1", "name": "JOGADOR 1", "created_unix": 0},
			{"profile_id": "profile_p2", "name": "JOGADOR 2", "created_unix": 0}
		],
		"active_by_slot": {"1": "profile_p1", "2": "profile_p2"}
	}

func load_from_disk() -> void:
	data = default_state()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = sanitize_state(parsed as Dictionary)

func save_to_disk() -> String:
	data = sanitize_state(data)
	data["updated_unix"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(data, "\t"))
	return SAVE_PATH

func profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in data.get("profiles", []):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result

func active_profile(slot: int) -> Dictionary:
	var clean_slot := clampi(slot, 1, 2)
	var active_map: Dictionary = data.get("active_by_slot", {})
	var profile_id := String(active_map.get(str(clean_slot), "profile_p%d" % clean_slot))
	var found := profile_by_id(profile_id)
	if not found.is_empty():
		return found
	var fallback_id := "profile_p%d" % clean_slot
	found = profile_by_id(fallback_id)
	if not found.is_empty():
		return found
	var source := profiles()
	return source[0] if not source.is_empty() else {"profile_id": fallback_id, "name": "JOGADOR %d" % clean_slot}

func profile_by_id(profile_id: String) -> Dictionary:
	for profile in profiles():
		if String(profile.get("profile_id", "")) == profile_id:
			return profile
	return {}

func create_profile(name: String) -> Dictionary:
	var source := profiles()
	if source.size() >= MAX_PROFILES:
		return {}
	var now := int(Time.get_unix_time_from_system())
	var profile := {
		"profile_id": "profile_%d_%d" % [now, Time.get_ticks_msec() % 100000],
		"name": sanitize_name(name, "JOGADOR %d" % (source.size() + 1)),
		"created_unix": now
	}
	source.append(profile)
	data["profiles"] = source
	save_to_disk()
	return profile.duplicate(true)

func rename_profile(profile_id: String, name: String) -> bool:
	var source: Array = data.get("profiles", [])
	for index in range(source.size()):
		if not (source[index] is Dictionary):
			continue
		var profile: Dictionary = source[index]
		if String(profile.get("profile_id", "")) != profile_id:
			continue
		profile["name"] = sanitize_name(name, String(profile.get("name", "JOGADOR")))
		source[index] = profile
		data["profiles"] = source
		save_to_disk()
		return true
	return false

func delete_profile(profile_id: String) -> bool:
	if profile_id in ["profile_p1", "profile_p2"]:
		return false
	var source: Array = data.get("profiles", [])
	for index in range(source.size()):
		if source[index] is Dictionary and String((source[index] as Dictionary).get("profile_id", "")) == profile_id:
			source.remove_at(index)
			data["profiles"] = source
			var active_map: Dictionary = data.get("active_by_slot", {})
			for slot in ["1", "2"]:
				if String(active_map.get(slot, "")) == profile_id:
					active_map[slot] = "profile_p%s" % slot
			data["active_by_slot"] = active_map
			save_to_disk()
			return true
	return false

func set_active(slot: int, profile_id: String) -> bool:
	if profile_by_id(profile_id).is_empty():
		return false
	var clean_slot := clampi(slot, 1, 2)
	var active_map: Dictionary = data.get("active_by_slot", {})
	active_map[str(clean_slot)] = profile_id
	data["active_by_slot"] = active_map
	save_to_disk()
	return true

func sanitize_state(source: Dictionary) -> Dictionary:
	var result := default_state()
	var clean_profiles: Array[Dictionary] = []
	var seen: Dictionary = {}
	var profiles_source: Variant = source.get("profiles", [])
	if profiles_source is Array:
		for value in profiles_source:
			if not (value is Dictionary) or clean_profiles.size() >= MAX_PROFILES:
				continue
			var profile: Dictionary = value
			var profile_id := String(profile.get("profile_id", "")).strip_edges().left(64)
			if profile_id == "" or seen.has(profile_id):
				continue
			seen[profile_id] = true
			clean_profiles.append({
				"profile_id": profile_id,
				"name": sanitize_name(String(profile.get("name", "JOGADOR")), "JOGADOR"),
				"created_unix": int(profile.get("created_unix", 0))
			})
	for fallback in default_state()["profiles"]:
		var fallback_id := String((fallback as Dictionary).get("profile_id", ""))
		if not seen.has(fallback_id):
			clean_profiles.push_front((fallback as Dictionary).duplicate(true))
			seen[fallback_id] = true
	result["profiles"] = clean_profiles
	var active_source: Variant = source.get("active_by_slot", {})
	var active_map: Dictionary = active_source as Dictionary if active_source is Dictionary else {}
	for slot in ["1", "2"]:
		var fallback_id := "profile_p%s" % slot
		var requested := String(active_map.get(slot, fallback_id))
		result["active_by_slot"][slot] = requested if seen.has(requested) else fallback_id
	result["updated_unix"] = int(source.get("updated_unix", 0))
	return result

static func sanitize_name(value: String, fallback: String = "JOGADOR") -> String:
	var clean := value.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	while clean.contains("  "):
		clean = clean.replace("  ", " ")
	return (clean if clean != "" else fallback).left(36)
