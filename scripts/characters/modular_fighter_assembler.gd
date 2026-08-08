class_name ModularFighterAssembler
extends Node2D

## Runtime visual assembler for the Taijifu Modular Fighter System.
## BASE-00 owns body/rig; visual modules attach by canonical slots.
## Tehkné Solutions

const STANDARD_PATH := "res://config/modular-fighter-standard-v1.json"
const BASE_PATH := "res://config/fighter-bases/base_fighter_v1.json"
const BASE01_MANIFEST_PATH := "res://assets/modular_fighters/base_01/manifest.json"
const SKIN_PALETTE_ROOT := "res://assets/modular_fighters/base_01/palettes"
const SKIN_SHADER_PATH := "res://shaders/modular_fighter_skin_palette.gdshader"
const DEFAULT_SKIN_PALETTE_ID := "skin_tone_03_warm"
const FACE_PLATE_ID := "neutral_face_plate_v1"
const IDENTITY_SLOTS := ["face", "eyes", "brows"]
const SKIN_TINT_SLOTS := ["body_base", "face_plate", "face"]
const SKIN_CHANNELS := ["skin_base", "skin_shadow", "skin_highlight", "cheek_tint"]

var _profile
var _layers: Dictionary = {}
var _active_identity_modules: Dictionary = {}
var _ready_for_render := false
var _active_skin_palette: Dictionary = {}

func configure(profile) -> PackedStringArray:
	_clear_layers()
	_profile = profile
	var failures := PackedStringArray()
	if _profile == null:
		failures.append("profile_missing")
		return failures
	if not _profile.has_method("validate_against_standard"):
		failures.append("profile_validation_contract_missing")
		return failures
	var validation_result = _profile.call("validate_against_standard")
	if typeof(validation_result) != TYPE_PACKED_STRING_ARRAY:
		failures.append("profile_validation_contract_invalid")
		return failures
	failures.append_array(validation_result)
	if not failures.is_empty():
		return failures
	if not FileAccess.file_exists(BASE_PATH):
		failures.append("base_fighter_contract_missing")
		return failures
	_ready_for_render = true

	# Palette selection belongs to the serializable fighter profile. Loading it
	# during configure means every later skin-bearing module receives the same
	# material automatically when it is attached.
	if _profile.has_method("skin_palette_id"):
		var selected_skin := String(_profile.call("skin_palette_id"))
		if not selected_skin.is_empty():
			failures.append_array(set_skin_palette(StringName(selected_skin)))
	if not failures.is_empty():
		_ready_for_render = false
	return failures

func assemble_base01_default_identity() -> PackedStringArray:
	var failures := PackedStringArray()
	if not _ready_for_render:
		failures.append("assembler_not_ready")
		return failures
	var manifest := _base01_manifest()
	if manifest.is_empty():
		failures.append("base01_manifest_missing_or_invalid")
		return failures
	var default_identity = manifest.get("default_identity", {})
	if typeof(default_identity) != TYPE_DICTIONARY:
		failures.append("base01_manifest_contract_invalid")
		return failures

	# Preserve a profile-selected skin. Only profiles without an explicit skin
	# receive the approved BASE-01 Warm default.
	if _active_skin_palette.is_empty():
		var default_skin_id := String(default_identity.get("skin", DEFAULT_SKIN_PALETTE_ID))
		failures.append_array(set_skin_palette(StringName(default_skin_id)))

	for slot in IDENTITY_SLOTS:
		var module_id := String(default_identity.get(slot, ""))
		if module_id.is_empty():
			failures.append("default_module_missing:%s" % slot)
			continue
		failures.append_array(set_base01_identity_module(StringName(slot), StringName(module_id)))
	return failures

func assemble_base01_profile_identity() -> PackedStringArray:
	var failures := PackedStringArray()
	if not _ready_for_render:
		failures.append("assembler_not_ready")
		return failures
	var manifest := _base01_manifest()
	if manifest.is_empty():
		failures.append("base01_manifest_missing_or_invalid")
		return failures
	var default_identity = manifest.get("default_identity", {})
	if typeof(default_identity) != TYPE_DICTIONARY:
		failures.append("base01_manifest_contract_invalid")
		return failures
	if _active_skin_palette.is_empty():
		var skin_id := DEFAULT_SKIN_PALETTE_ID
		if _profile != null and _profile.has_method("skin_palette_id"):
			var requested_skin := String(_profile.call("skin_palette_id"))
			if not requested_skin.is_empty():
				skin_id = requested_skin
		failures.append_array(set_skin_palette(StringName(skin_id)))

	for slot in IDENTITY_SLOTS:
		var module_id := ""
		if _profile != null and _profile.has_method("module_id"):
			module_id = String(_profile.call("module_id", StringName(slot)))
		if module_id.is_empty():
			module_id = String(default_identity.get(slot, ""))
		if module_id.is_empty():
			failures.append("profile_identity_module_missing:%s" % slot)
			continue
		failures.append_array(set_base01_identity_module(StringName(slot), StringName(module_id)))
	return failures

func set_base01_identity_module(slot: StringName, module_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	if not _ready_for_render:
		failures.append("assembler_not_ready")
		return failures
	var slot_name := String(slot)
	var module_name := String(module_id)
	if not IDENTITY_SLOTS.has(slot_name):
		failures.append("base01_identity_slot_invalid:%s" % slot_name)
		return failures
	if module_name.is_empty():
		failures.append("base01_identity_module_missing:%s" % slot_name)
		return failures

	var manifest := _base01_manifest()
	var modules = manifest.get("modules", {})
	if typeof(modules) != TYPE_DICTIONARY:
		failures.append("base01_manifest_contract_invalid")
		return failures
	if not modules.has(module_name):
		failures.append("base01_identity_module_unknown:%s:%s" % [slot_name, module_name])
		return failures
	var module_contract = modules[module_name]
	if typeof(module_contract) != TYPE_DICTIONARY or String(module_contract.get("slot", "")) != slot_name:
		failures.append("base01_identity_module_slot_mismatch:%s:%s" % [slot_name, module_name])
		return failures

	if slot_name == "face":
		var default_identity = manifest.get("default_identity", {})
		var default_face := String(default_identity.get("face", "face_01_balanced")) if typeof(default_identity) == TYPE_DICTIONARY else "face_01_balanced"
		if module_name == default_face:
			clear_visual_module(&"face_plate")
		else:
			failures.append_array(_ensure_face_plate(manifest))
			if not failures.is_empty():
				return failures

	failures.append_array(_attach_base01_manifest_module(manifest, slot_name, module_name))
	if failures.is_empty():
		_active_identity_modules[slot_name] = module_name
	return failures

func set_skin_palette(palette_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	if not _ready_for_render:
		failures.append("assembler_not_ready")
		return failures
	var palette_name := String(palette_id)
	if palette_name.is_empty():
		failures.append("skin_palette_id_missing")
		return failures
	var palette := _load_json("%s/%s.json" % [SKIN_PALETTE_ROOT, palette_name])
	if palette.is_empty():
		failures.append("skin_palette_missing_or_invalid:%s" % palette_name)
		return failures
	if String(palette.get("palette_id", "")) != palette_name:
		failures.append("skin_palette_id_mismatch:%s" % palette_name)
		return failures
	var channels = palette.get("channels", {})
	if typeof(channels) != TYPE_DICTIONARY:
		failures.append("skin_palette_channels_invalid:%s" % palette_name)
		return failures
	for channel in SKIN_CHANNELS:
		var value := String(channels.get(channel, ""))
		if value.is_empty() or not Color.html_is_valid(value):
			failures.append("skin_palette_channel_invalid:%s:%s" % [palette_name, channel])
	if not failures.is_empty():
		return failures
	if palette_name != DEFAULT_SKIN_PALETTE_ID and _skin_shader() == null:
		failures.append("skin_palette_shader_missing")
		return failures
	_active_skin_palette = palette
	_apply_active_skin_palette_to_layers()
	return failures

func attach_visual_module(slot: StringName, node: CanvasItem) -> bool:
	if not _ready_for_render or node == null:
		return false
	var slot_name := String(slot)
	if not _allowed_slots().has(slot_name):
		return false
	if _layers.has(slot_name):
		var previous = _layers[slot_name]
		if is_instance_valid(previous):
			previous.queue_free()
	_layers[slot_name] = node
	node.name = "Module_%s" % slot_name
	add_child(node)
	_apply_active_skin_palette_to_node(slot_name, node)
	return true

func clear_visual_module(slot: StringName) -> void:
	var key := String(slot)
	if not _layers.has(key):
		_active_identity_modules.erase(key)
		return
	var node = _layers[key]
	_layers.erase(key)
	_active_identity_modules.erase(key)
	if is_instance_valid(node):
		node.queue_free()

func active_skin_palette() -> Dictionary:
	return _active_skin_palette.duplicate(true)

func active_skin_palette_id() -> StringName:
	return StringName(String(_active_skin_palette.get("palette_id", "")))

func active_identity_module_id(slot: StringName) -> StringName:
	return StringName(String(_active_identity_modules.get(String(slot), "")))

func is_ready_for_render() -> bool:
	return _ready_for_render

func profile_id() -> StringName:
	if _profile == null:
		return &""
	return StringName(String(_profile.get("profile_id")))

func _ensure_face_plate(manifest: Dictionary) -> PackedStringArray:
	var failures := PackedStringArray()
	if active_identity_module_id(&"face_plate") == StringName(FACE_PLATE_ID) and _layers.has("face_plate"):
		return failures
	failures.append_array(_attach_base01_manifest_module(manifest, "face_plate", FACE_PLATE_ID))
	if failures.is_empty():
		_active_identity_modules["face_plate"] = FACE_PLATE_ID
	return failures

func _attach_base01_manifest_module(manifest: Dictionary, slot_name: String, module_name: String) -> PackedStringArray:
	var failures := PackedStringArray()
	var modules = manifest.get("modules", {})
	if typeof(modules) != TYPE_DICTIONARY or not modules.has(module_name):
		failures.append("module_contract_missing:%s" % module_name)
		return failures
	var contract = modules[module_name]
	if typeof(contract) != TYPE_DICTIONARY:
		failures.append("module_contract_invalid:%s" % module_name)
		return failures
	if String(contract.get("slot", "")) != slot_name:
		failures.append("module_contract_slot_invalid:%s:%s" % [slot_name, module_name])
		return failures
	var asset_path := "res://%s" % String(contract.get("path", ""))
	if not ResourceLoader.exists(asset_path):
		failures.append("module_asset_missing:%s" % module_name)
		return failures
	var texture := load(asset_path) as Texture2D
	if texture == null:
		failures.append("module_texture_invalid:%s" % module_name)
		return failures
	var pivot = contract.get("pivot", [0.5, 0.92])
	if typeof(pivot) != TYPE_ARRAY or pivot.size() != 2:
		failures.append("module_pivot_invalid:%s" % module_name)
		return failures
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	var size := texture.get_size()
	sprite.position = Vector2(
		size.x * (0.5 - float(pivot[0])),
		size.y * (0.5 - float(pivot[1]))
	)
	sprite.z_index = _slot_z_index(slot_name)
	if not attach_visual_module(StringName(slot_name), sprite):
		failures.append("module_attach_failed:%s" % module_name)
	return failures

func _apply_active_skin_palette_to_layers() -> void:
	if _active_skin_palette.is_empty():
		return
	for slot in SKIN_TINT_SLOTS:
		if _layers.has(slot):
			var node = _layers[slot]
			if is_instance_valid(node):
				_apply_active_skin_palette_to_node(slot, node)

func _apply_active_skin_palette_to_node(slot: String, node: CanvasItem) -> void:
	if not SKIN_TINT_SLOTS.has(slot) or _active_skin_palette.is_empty():
		return
	var sprite := node as Sprite2D
	if sprite == null:
		return
	var palette_name := String(_active_skin_palette.get("palette_id", ""))
	if palette_name == DEFAULT_SKIN_PALETTE_ID:
		sprite.material = null
		return
	var shader := _skin_shader()
	if shader == null:
		return
	var channels = _active_skin_palette.get("channels", {})
	if typeof(channels) != TYPE_DICTIONARY:
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	for channel in SKIN_CHANNELS:
		material.set_shader_parameter(channel, Color.from_string(String(channels.get(channel, "#FFFFFF")), Color.WHITE))
	sprite.material = material

func _skin_shader() -> Shader:
	if not ResourceLoader.exists(SKIN_SHADER_PATH):
		return null
	return load(SKIN_SHADER_PATH) as Shader

func _clear_layers() -> void:
	for node in _layers.values():
		if is_instance_valid(node):
			node.queue_free()
	_layers.clear()
	_active_identity_modules.clear()
	_active_skin_palette.clear()
	_profile = null
	_ready_for_render = false

func _allowed_slots() -> PackedStringArray:
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

func _base01_manifest() -> Dictionary:
	var manifest := _load_json(BASE01_MANIFEST_PATH)
	if String(manifest.get("pack_id", "")) != "BASE01_DEFAULT_IDENTITY_MODULES":
		return {}
	return manifest

func _load_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _slot_z_index(slot: String) -> int:
	match slot:
		"face_plate":
			return 15
		"face":
			return 20
		"eyes":
			return 30
		"brows":
			return 40
		_:
			return 10
