class_name ModularFighterPresetStore
extends RefCounted

## Versioned persistence boundary for ModularFighterProfile.
## Supports canonical v2 creator presets and read compatibility with repository v1 presets.
## Tehkné Solutions

const SCHEMA_V1 := "tehkne/taijifu-modular-fighter-preset/v1"
const SCHEMA_V2 := "tehkne/taijifu-modular-fighter-preset/v2"
const SIGNATURE := "Tehkné Solutions"
const USER_DIR := "user://modular_fighter_presets"
const MAX_PRESET_ID_LENGTH := 64

static func encode(profile: ModularFighterProfile, preset_id: StringName = &"") -> Dictionary:
	if profile == null:
		return {}
	var resolved_preset_id := String(preset_id)
	if resolved_preset_id.is_empty():
		resolved_preset_id = String(profile.profile_id)
	return {
		"schema": SCHEMA_V2,
		"signature": SIGNATURE,
		"preset_id": resolved_preset_id,
		"profile_id": String(profile.profile_id),
		"display_name": profile.display_name,
		"base_body_id": String(profile.base_body_id),
		"authored_facing": profile.authored_facing,
		"palette": profile.palette.duplicate(true),
		"modules": profile.modules.duplicate(true),
		"combat_loadout_id": String(profile.combat_loadout_id),
		"creator": {
			"identity_slots": ["skin", "face", "eyes", "brows"],
			"source": "BASE01_IDENTITY_CREATOR_CONTROL",
		},
	}

static func decode(data: Dictionary) -> Dictionary:
	var failures := PackedStringArray()
	var profile := ModularFighterProfile.new()
	if data.is_empty():
		failures.append("preset_data_empty")
		return _decode_result(profile, failures)

	var schema := String(data.get("schema", ""))
	if not [SCHEMA_V1, SCHEMA_V2].has(schema):
		failures.append("preset_schema_unsupported:%s" % schema)
		return _decode_result(profile, failures)
	if String(data.get("signature", "")) != SIGNATURE:
		failures.append("preset_signature_invalid")
		return _decode_result(profile, failures)

	if schema == SCHEMA_V2:
		var preset_id := String(data.get("preset_id", ""))
		if not _valid_preset_id(preset_id):
			failures.append("preset_id_invalid:%s" % preset_id)

	profile.profile_id = StringName(String(data.get("profile_id", "")))
	profile.display_name = String(data.get("display_name", ""))
	profile.base_body_id = StringName(String(data.get("base_body_id", "base_fighter_v1")))
	profile.authored_facing = int(data.get("authored_facing", 1))
	profile.combat_loadout_id = StringName(String(data.get("combat_loadout_id", "")))

	var palette_value = data.get("palette", {})
	if typeof(palette_value) == TYPE_DICTIONARY:
		profile.palette = (palette_value as Dictionary).duplicate(true)
	else:
		failures.append("preset_palette_invalid")

	var modules_value = data.get("modules", {})
	if typeof(modules_value) == TYPE_DICTIONARY:
		profile.modules = (modules_value as Dictionary).duplicate(true)
	else:
		failures.append("preset_modules_invalid")

	failures.append_array(profile.validate_against_standard())
	return _decode_result(profile, failures)

static func save_user_preset(profile: ModularFighterProfile, preset_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("preset_profile_missing")
		return failures
	var id_text := String(preset_id)
	if not _valid_preset_id(id_text):
		failures.append("preset_id_invalid:%s" % id_text)
		return failures
	failures.append_array(profile.validate_against_standard())
	if not failures.is_empty():
		return failures

	var absolute_dir := ProjectSettings.globalize_path(USER_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		failures.append("preset_user_dir_unavailable")
		return failures
	var path := user_preset_path(preset_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("preset_write_failed:%s" % id_text)
		return failures
	file.store_string(JSON.stringify(encode(profile, preset_id), "  ") + "\n")
	file.close()
	return failures

static func load_user_preset(preset_id: StringName) -> Dictionary:
	var failures := PackedStringArray()
	var id_text := String(preset_id)
	if not _valid_preset_id(id_text):
		failures.append("preset_id_invalid:%s" % id_text)
		return _decode_result(ModularFighterProfile.new(), failures)
	return load_path(user_preset_path(preset_id))

static func load_path(path: String) -> Dictionary:
	var failures := PackedStringArray()
	if path.is_empty() or not FileAccess.file_exists(path):
		failures.append("preset_file_missing:%s" % path)
		return _decode_result(ModularFighterProfile.new(), failures)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures.append("preset_read_failed:%s" % path)
		return _decode_result(ModularFighterProfile.new(), failures)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("preset_json_invalid:%s" % path)
		return _decode_result(ModularFighterProfile.new(), failures)
	return decode(parsed as Dictionary)

static func user_preset_path(preset_id: StringName) -> String:
	return "%s/%s.json" % [USER_DIR, String(preset_id)]

static func list_user_preset_ids() -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(USER_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var preset_id := file_name.trim_suffix(".json")
			if _valid_preset_id(preset_id):
				result.append(preset_id)
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

static func delete_user_preset(preset_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	var id_text := String(preset_id)
	if not _valid_preset_id(id_text):
		failures.append("preset_id_invalid:%s" % id_text)
		return failures
	var path := user_preset_path(preset_id)
	if not FileAccess.file_exists(path):
		return failures
	var absolute_path := ProjectSettings.globalize_path(path)
	if DirAccess.remove_absolute(absolute_path) != OK:
		failures.append("preset_delete_failed:%s" % id_text)
	return failures

static func _decode_result(profile: ModularFighterProfile, failures: PackedStringArray) -> Dictionary:
	return {
		"profile": profile,
		"failures": failures,
		"ok": failures.is_empty(),
	}

static func _valid_preset_id(value: String) -> bool:
	if value.is_empty() or value.length() > MAX_PRESET_ID_LENGTH:
		return false
	var regex := RegEx.new()
	if regex.compile("^[A-Za-z0-9][A-Za-z0-9_-]*$") != OK:
		return false
	return regex.search(value) != null
