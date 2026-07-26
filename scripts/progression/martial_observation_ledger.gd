class_name MartialObservationLedger
extends RefCounted

const SAVE_PATH := "user://martial_observation.json"

const EVENT_POINTS := {
	&"seen": 1,
	&"recognized": 2,
	&"understood": 3,
	&"defended": 4,
	&"reproduced": 6,
	&"adapted": 7
}

const STAGE_LABELS := {
	&"seen": "VISTA",
	&"recognized": "RECONHECIDA",
	&"understood": "COMPREENDIDA",
	&"defended": "DEFENDIDA",
	&"reproduced": "REPRODUZIDA",
	&"adapted": "ADAPTADA",
	&"mastered": "DOMINADA"
}

var _profiles: Dictionary = {}
var _last_updates: Dictionary = {}

func _init() -> void:
	_load()

func record_event(
	profile_id: StringName,
	technique_id: StringName,
	event_id: StringName
) -> Dictionary:
	if profile_id == &"" or technique_id == &"" or not EVENT_POINTS.has(event_id):
		return {}

	var profile_key := String(profile_id)
	var technique_key := String(technique_id)
	var profile: Dictionary = _profiles.get(profile_key, {})
	var entry: Dictionary = profile.get(technique_key, _new_entry())
	var events: Dictionary = entry.get("events", {})
	var previous_stage := StringName(entry.get("stage", "seen"))

	events[String(event_id)] = int(events.get(String(event_id), 0)) + 1
	entry["events"] = events
	entry["score"] = int(entry.get("score", 0)) + int(EVENT_POINTS[event_id])
	entry["last_event"] = String(event_id)
	entry["updated_unix"] = int(Time.get_unix_time_from_system())
	entry["stage"] = String(_resolve_stage(entry))
	profile[technique_key] = entry
	_profiles[profile_key] = profile

	var result := {
		"profile_id": profile_key,
		"technique_id": technique_key,
		"event_id": String(event_id),
		"stage": entry["stage"],
		"stage_label": stage_label(StringName(entry["stage"])),
		"advanced": previous_stage != StringName(entry["stage"]),
		"score": entry["score"]
	}
	_last_updates[profile_key] = result
	_save()
	return result

func stage_for(profile_id: StringName, technique_id: StringName) -> StringName:
	var profile: Dictionary = _profiles.get(String(profile_id), {})
	var entry: Dictionary = profile.get(String(technique_id), {})
	return StringName(entry.get("stage", "seen"))

func stage_label(stage_id: StringName) -> String:
	return STAGE_LABELS.get(stage_id, "VISTA")

func latest_summary(profile_id: StringName) -> String:
	var update: Dictionary = _last_updates.get(String(profile_id), {})
	if update.is_empty():
		return "SEM REGISTRO"
	var technique := TechniqueCatalog.get_technique(StringName(update.get("technique_id", "")))
	return "%s • %s" % [technique.display_name.to_upper(), update.get("stage_label", "VISTA")]

func profile_snapshot(profile_id: StringName) -> Dictionary:
	return _profiles.get(String(profile_id), {}).duplicate(true)

func _new_entry() -> Dictionary:
	return {
		"score": 0,
		"stage": "seen",
		"events": {},
		"last_event": "seen",
		"updated_unix": 0
	}

func _resolve_stage(entry: Dictionary) -> StringName:
	var score := int(entry.get("score", 0))
	var events: Dictionary = entry.get("events", {})
	var seen_count := int(events.get("seen", 0))
	var defended_count := int(events.get("defended", 0))
	var reproduced_count := int(events.get("reproduced", 0))
	var adapted_count := int(events.get("adapted", 0))
	var event_variety := events.keys().size()

	if score >= 42 and defended_count >= 4 and reproduced_count >= 3 and adapted_count >= 2:
		return &"mastered"
	if score >= 26 and defended_count >= 2 and reproduced_count >= 1:
		return &"adapted"
	if reproduced_count >= 1:
		return &"reproduced"
	if defended_count >= 1:
		return &"defended"
	if score >= 8 and event_variety >= 2:
		return &"understood"
	if score >= 3 or seen_count >= 2:
		return &"recognized"
	return &"seen"

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"version": 1, "profiles": _profiles}, "\t"))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_profiles = (parsed as Dictionary).get("profiles", {})
