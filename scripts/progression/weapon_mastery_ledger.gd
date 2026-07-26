class_name WeaponMasteryLedger
extends RefCounted

const SAVE_PATH := "user://weapon_mastery.json"
const STAGES := [
	{"id": &"unfamiliar", "label": "DESCONHECIDA", "xp": 0},
	{"id": &"familiar", "label": "FAMILIAR", "xp": 20},
	{"id": &"trained", "label": "TREINADA", "xp": 60},
	{"id": &"proficient", "label": "PROFICIENTE", "xp": 140},
	{"id": &"mastered", "label": "DOMINADA", "xp": 300},
	{"id": &"legendary", "label": "LENDÁRIA", "xp": 600}
]

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

func record_event(
	profile_id: String,
	weapon_id: StringName,
	event_id: StringName,
	xp_gain: float
) -> Dictionary:
	if weapon_id == &"" or weapon_id == &"unarmed":
		return {}
	var entry := _entry(profile_id, weapon_id)
	entry["xp"] = maxf(0.0, float(entry.get("xp", 0.0)) + xp_gain)
	entry["events"] = int(entry.get("events", 0)) + 1
	entry[String(event_id)] = int(entry.get(String(event_id), 0)) + 1
	entry["stage"] = String(_stage_for_xp(float(entry["xp"])).get("id", &"unfamiliar"))
	entry["updated_unix"] = int(Time.get_unix_time_from_system())
	_set_entry(profile_id, weapon_id, entry)
	return entry.duplicate(true)

func entry_for(profile_id: String, weapon_id: StringName) -> Dictionary:
	return _entry(profile_id, weapon_id).duplicate(true)

func stage_label_for(profile_id: String, weapon_id: StringName) -> String:
	var entry := _entry(profile_id, weapon_id)
	return String(_stage_for_xp(float(entry.get("xp", 0.0))).get("label", "DESCONHECIDA"))

func progress_for(profile_id: String, weapon_id: StringName) -> Dictionary:
	var entry := _entry(profile_id, weapon_id)
	var xp := float(entry.get("xp", 0.0))
	var current := _stage_for_xp(xp)
	var next := _next_stage(current)
	var current_xp := float(current.get("xp", 0))
	var next_xp := float(next.get("xp", current_xp))
	var ratio := 1.0 if next_xp <= current_xp else clampf((xp - current_xp) / (next_xp - current_xp), 0.0, 1.0)
	return {
		"xp": xp,
		"stage_id": current.get("id", &"unfamiliar"),
		"stage_label": current.get("label", "DESCONHECIDA"),
		"next_stage_label": next.get("label", current.get("label", "DESCONHECIDA")),
		"next_xp": next_xp,
		"ratio": ratio
	}

func _entry(profile_id: String, weapon_id: StringName) -> Dictionary:
	var profiles: Dictionary = data.get("profiles", {})
	var profile: Dictionary = profiles.get(profile_id, {})
	var key := String(weapon_id)
	var entry: Dictionary = profile.get(key, {})
	if entry.is_empty():
		entry = {
			"weapon_id": key,
			"xp": 0.0,
			"stage": "unfamiliar",
			"events": 0,
			"uses": 0,
			"hits": 0,
			"blocked_contacts": 0,
			"parried_contacts": 0,
			"evaded_contacts": 0,
			"parries": 0,
			"swaps": 0,
			"adaptive_hits": 0,
			"disarms_suffered": 0
		}
		profile[key] = entry
		profiles[profile_id] = profile
		data["profiles"] = profiles
	return entry

func _set_entry(profile_id: String, weapon_id: StringName, entry: Dictionary) -> void:
	var profiles: Dictionary = data.get("profiles", {})
	var profile: Dictionary = profiles.get(profile_id, {})
	profile[String(weapon_id)] = entry
	profiles[profile_id] = profile
	data["profiles"] = profiles

func _stage_for_xp(xp: float) -> Dictionary:
	var selected: Dictionary = STAGES[0]
	for stage_variant in STAGES:
		var stage: Dictionary = stage_variant
		if xp >= float(stage.get("xp", 0)):
			selected = stage
		else:
			break
	return selected

func _next_stage(current: Dictionary) -> Dictionary:
	var current_id := StringName(current.get("id", &"unfamiliar"))
	for index in range(STAGES.size()):
		var stage: Dictionary = STAGES[index]
		if StringName(stage.get("id", &"")) == current_id:
			return STAGES[mini(index + 1, STAGES.size() - 1)]
	return STAGES[0]