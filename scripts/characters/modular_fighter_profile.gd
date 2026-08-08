class_name ModularFighterProfile
extends Resource

## Serializable visual identity for Taijifu Modular Fighter System v1.
## Combat configuration intentionally lives outside this resource.
## Tehkné Solutions

const STANDARD_PATH := "res://config/modular-fighter-standard-v1.json"
const SKIN_CONTRACT_PATH := "res://assets/modular_fighters/base_01/production/BASE01_SKIN_PALETTES.json"

@export var profile_id: StringName = &""
@export var display_name: String = ""
@export var base_body_id: StringName = &"base_fighter_v1"
@export var authored_facing: int = 1
@export var palette: Dictionary = {}
@export var modules: Dictionary = {}
@export var combat_loadout_id: StringName = &""

func set_module(slot: StringName, module_id: StringName) -> void:
	modules[String(slot)] = String(module_id)

func clear_module(slot: StringName) -> void:
	modules.erase(String(slot))

func module_id(slot: StringName) -> StringName:
	return StringName(String(modules.get(String(slot), "")))

func set_skin_palette_id(palette_id: StringName) -> void:
	if palette_id == &"":
		palette.erase("skin")
		return
	palette["skin"] = String(palette_id)

func skin_palette_id() -> StringName:
	return StringName(String(palette.get("skin", "")))

func validate_against_standard() -> PackedStringArray:
	var failures := PackedStringArray()
	if profile_id == &"":
		failures.append("profile_id_missing")
	if base_body_id == &"":
		failures.append("base_body_id_missing")
	if authored_facing != -1 and authored_facing != 1:
		failures.append("authored_facing_must_be_minus1_or_plus1")

	var allowed_slots := _load_allowed_slots()
	if allowed_slots.is_empty():
		failures.append("modular_fighter_standard_unavailable")
		return failures

	for raw_slot in modules.keys():
		var slot := String(raw_slot)
		if not allowed_slots.has(slot):
			failures.append("unknown_visual_slot:%s" % slot)

	var selected_skin := String(skin_palette_id())
	if not selected_skin.is_empty():
		var allowed_skin_ids := _load_allowed_skin_palette_ids()
		if allowed_skin_ids.is_empty():
			failures.append("skin_palette_contract_unavailable")
		elif not allowed_skin_ids.has(selected_skin):
			failures.append("unknown_skin_palette:%s" % selected_skin)
	return failures

func is_valid() -> bool:
	return validate_against_standard().is_empty()

func to_runtime_dictionary() -> Dictionary:
	return {
		"profile_id": String(profile_id),
		"display_name": display_name,
		"base_body_id": String(base_body_id),
		"authored_facing": authored_facing,
		"palette": palette.duplicate(true),
		"modules": modules.duplicate(true),
		"combat_loadout_id": String(combat_loadout_id),
		"signature": "Tehkné Solutions",
	}

func _load_allowed_slots() -> PackedStringArray:
	var result := PackedStringArray()
	var parsed := _load_json(STANDARD_PATH)
	if parsed.is_empty():
		return result
	var slots = parsed.get("slots", [])
	if typeof(slots) != TYPE_ARRAY:
		return result
	for slot in slots:
		result.append(String(slot))
	return result

func _load_allowed_skin_palette_ids() -> PackedStringArray:
	var result := PackedStringArray()
	var parsed := _load_json(SKIN_CONTRACT_PATH)
	if parsed.is_empty():
		return result
	var palette_ids = parsed.get("palette_ids", [])
	if typeof(palette_ids) != TYPE_ARRAY:
		return result
	for palette_id in palette_ids:
		result.append(String(palette_id))
	return result

func _load_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
