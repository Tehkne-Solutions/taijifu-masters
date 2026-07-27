class_name LoadoutPresetLedger
extends RefCounted

const SAVE_PATH := "user://loadout_presets.json"
const EXPORT_DIRECTORY := "user://exports"
const IMPORT_DIRECTORY := "user://imports"
const IMPORT_INBOX_PATH := "user://imports/loadout.taijifu.json"
const SIGNATURE := "TAIJIFU_LOADOUT_PRESET"
const VERSION := 1
const MAX_PRESETS_PER_PROFILE := 12

var data: Dictionary = {
	"version": VERSION,
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
		var root: Dictionary = parsed
		var profiles: Variant = root.get("profiles", {})
		if profiles is Dictionary:
			data = {"version": VERSION, "profiles": profiles}
	_sanitize_all_profiles()

func save_to_disk() -> String:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
	data["version"] = VERSION
	data["updated_unix"] = int(Time.get_unix_time_from_system())
	file.store_string(JSON.stringify(data, "\t"))
	return SAVE_PATH

func presets_for(profile_id: String) -> Array[Dictionary]:
	var profiles: Dictionary = data.get("profiles", {})
	var source: Variant = profiles.get(profile_id, [])
	var result: Array[Dictionary] = []
	if source is Array:
		for value in source:
			if value is Dictionary:
				result.append((value as Dictionary).duplicate(true))
	result.sort_custom(_sort_by_updated)
	return result

func preset_count(profile_id: String) -> int:
	return presets_for(profile_id).size()

func preset_at(profile_id: String, index: int) -> Dictionary:
	var presets := presets_for(profile_id)
	if presets.is_empty():
		return {}
	return presets[clampi(index, 0, presets.size() - 1)].duplicate(true)

func preset_by_id(profile_id: String, preset_id: String) -> Dictionary:
	for preset in presets_for(profile_id):
		if String(preset.get("preset_id", "")) == preset_id:
			return preset.duplicate(true)
	return {}

func save_preset(
	profile_id: String,
	preset_name: String,
	loadout: Dictionary,
	match_config: Dictionary = {},
	unlocked_variants: Array = []
) -> Dictionary:
	var profiles: Dictionary = data.get("profiles", {})
	var presets: Array = profiles.get(profile_id, [])
	var clean_name := _clean_name(preset_name)
	var now := int(Time.get_unix_time_from_system())
	var preset := {
		"preset_id": _new_preset_id(profile_id, now, presets.size()),
		"name": clean_name,
		"loadout": BattleLoadoutCatalog.sanitize(loadout, unlocked_variants),
		"match_config": CompetitiveMatchCatalog.sanitize(match_config),
		"created_unix": now,
		"updated_unix": now
	}
	presets.append(preset)
	while presets.size() > MAX_PRESETS_PER_PROFILE:
		presets.pop_front()
	profiles[profile_id] = presets
	data["profiles"] = profiles
	save_to_disk()
	return preset.duplicate(true)

func overwrite_preset(
	profile_id: String,
	preset_id: String,
	loadout: Dictionary,
	match_config: Dictionary,
	unlocked_variants: Array = []
) -> Dictionary:
	var profiles: Dictionary = data.get("profiles", {})
	var presets: Array = profiles.get(profile_id, [])
	for index in range(presets.size()):
		if not (presets[index] is Dictionary):
			continue
		var preset: Dictionary = presets[index]
		if String(preset.get("preset_id", "")) != preset_id:
			continue
		preset["loadout"] = BattleLoadoutCatalog.sanitize(loadout, unlocked_variants)
		preset["match_config"] = CompetitiveMatchCatalog.sanitize(match_config)
		preset["updated_unix"] = int(Time.get_unix_time_from_system())
		presets[index] = preset
		profiles[profile_id] = presets
		data["profiles"] = profiles
		save_to_disk()
		return preset.duplicate(true)
	return {}

func rename_preset(profile_id: String, preset_id: String, new_name: String) -> bool:
	var profiles: Dictionary = data.get("profiles", {})
	var presets: Array = profiles.get(profile_id, [])
	for index in range(presets.size()):
		if not (presets[index] is Dictionary):
			continue
		var preset: Dictionary = presets[index]
		if String(preset.get("preset_id", "")) != preset_id:
			continue
		preset["name"] = _clean_name(new_name)
		preset["updated_unix"] = int(Time.get_unix_time_from_system())
		presets[index] = preset
		profiles[profile_id] = presets
		data["profiles"] = profiles
		save_to_disk()
		return true
	return false

func delete_preset(profile_id: String, preset_id: String) -> bool:
	var profiles: Dictionary = data.get("profiles", {})
	var presets: Array = profiles.get(profile_id, [])
	for index in range(presets.size()):
		if presets[index] is Dictionary and String((presets[index] as Dictionary).get("preset_id", "")) == preset_id:
			presets.remove_at(index)
			profiles[profile_id] = presets
			data["profiles"] = profiles
			save_to_disk()
			return true
	return false

func export_preset(profile_id: String, preset_id: String) -> String:
	var preset := preset_by_id(profile_id, preset_id)
	if preset.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORT_DIRECTORY))
	var file_name := "%s-%s.taijifu.json" % [
		_slugify(String(preset.get("name", "preset"))),
		String(preset_id).right(8)
	]
	var path := "%s/%s" % [EXPORT_DIRECTORY, file_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify({
		"signature": SIGNATURE,
		"version": VERSION,
		"exported_unix": int(Time.get_unix_time_from_system()),
		"preset": preset
	}, "\t"))
	return path

func import_inbox(profile_id: String, unlocked_variants: Array = []) -> Dictionary:
	return import_file(profile_id, IMPORT_INBOX_PATH, unlocked_variants)

func import_file(profile_id: String, path: String, unlocked_variants: Array = []) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Arquivo de importação não encontrado", "path": path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Não foi possível abrir o arquivo", "path": path}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {"ok": false, "error": "JSON inválido", "path": path}
	return import_dictionary(profile_id, parsed as Dictionary, unlocked_variants)

func import_dictionary(profile_id: String, source: Dictionary, unlocked_variants: Array = []) -> Dictionary:
	if String(source.get("signature", "")) != SIGNATURE:
		return {"ok": false, "error": "Assinatura de preset inválida"}
	var preset_source: Variant = source.get("preset", {})
	if not (preset_source is Dictionary):
		return {"ok": false, "error": "Preset ausente"}
	var imported: Dictionary = preset_source
	var loadout_source: Variant = imported.get("loadout", {})
	var config_source: Variant = imported.get("match_config", {})
	if not (loadout_source is Dictionary):
		return {"ok": false, "error": "Loadout inválido"}
	var created := save_preset(
		profile_id,
		"%s (IMPORTADO)" % _clean_name(String(imported.get("name", "PRESET"))),
		loadout_source as Dictionary,
		config_source as Dictionary if config_source is Dictionary else {},
		unlocked_variants
	)
	return {"ok": true, "preset": created}

func ensure_import_directory() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IMPORT_DIRECTORY))
	return IMPORT_INBOX_PATH

func _sanitize_all_profiles() -> void:
	var profiles: Dictionary = data.get("profiles", {})
	for profile_key in profiles.keys():
		var source: Variant = profiles[profile_key]
		var clean: Array = []
		if source is Array:
			for value in source:
				if not (value is Dictionary):
					continue
				var preset: Dictionary = value
				var loadout_source: Variant = preset.get("loadout", {})
				var config_source: Variant = preset.get("match_config", {})
				clean.append({
					"preset_id": String(preset.get("preset_id", _new_preset_id(String(profile_key), 0, clean.size()))),
					"name": _clean_name(String(preset.get("name", "PRESET"))),
					"loadout": BattleLoadoutCatalog.sanitize(loadout_source as Dictionary if loadout_source is Dictionary else {}),
					"match_config": CompetitiveMatchCatalog.sanitize(config_source as Dictionary if config_source is Dictionary else {}),
					"created_unix": int(preset.get("created_unix", 0)),
					"updated_unix": int(preset.get("updated_unix", 0))
				})
		while clean.size() > MAX_PRESETS_PER_PROFILE:
			clean.pop_front()
		profiles[String(profile_key)] = clean
	data["profiles"] = profiles

func _clean_name(value: String) -> String:
	var clean := value.strip_edges().replace("\n", " ").replace("\r", " ")
	while clean.contains("  "):
		clean = clean.replace("  ", " ")
	if clean == "":
		clean = "PRESET SEM NOME"
	return clean.left(48)

func _slugify(value: String) -> String:
	var result := value.to_lower().strip_edges()
	for character in [" ", "/", "\\", ":", ";", "|", "?", "*", "\"", "<", ">"]:
		result = result.replace(character, "-")
	while result.contains("--"):
		result = result.replace("--", "-")
	return result.trim_prefix("-").trim_suffix("-").left(36)

func _new_preset_id(profile_id: String, unix_time: int, ordinal: int) -> String:
	return "%s_%d_%02d" % [profile_id, unix_time, ordinal]

func _sort_by_updated(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("updated_unix", 0)) > int(b.get("updated_unix", 0))
