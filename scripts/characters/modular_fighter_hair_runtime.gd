class_name ModularFighterHairRuntime
extends RefCounted

## BASE-02 Hair pack boundary. Keeps hairstyle selection atomic while reusing the
## generic profile modules dictionary and ModularFighterAssembler slot contract.
## Tehkné Solutions

const MANIFEST_PATH := "res://assets/modular_fighters/base_02/manifest.json"
const DEFAULT_STYLE := &"hair_none"
const HAIR_BACK := &"hair_back"
const HAIR_FRONT := &"hair_front"

static func style_ids() -> PackedStringArray:
	var result := PackedStringArray()
	var manifest := _manifest()
	var styles = manifest.get("styles", {})
	if not (styles is Dictionary):
		return result
	for raw_id in styles.keys():
		result.append(str(raw_id))
	result.sort()
	return result

static func creator_style_ids() -> PackedStringArray:
	var result := PackedStringArray()
	var manifest := _manifest()
	var styles = manifest.get("styles", {})
	if not (styles is Dictionary):
		return result
	for raw_id in styles.keys():
		var style_id := str(raw_id)
		var style = styles[style_id]
		if style is Dictionary and bool(style.get("production_ready", false)):
			result.append(style_id)
	result.sort()
	return result

static func style_label(style_id: StringName) -> String:
	var manifest := _manifest()
	var styles = manifest.get("styles", {})
	var key := str(style_id)
	if not (styles is Dictionary) or not styles.has(key):
		return key
	var style = styles[key]
	if not (style is Dictionary):
		return key
	return str(style.get("label", key))

static func creator_exposure_enabled() -> bool:
	var manifest := _manifest()
	var promotion = manifest.get("promotion", {})
	return promotion is Dictionary and bool(promotion.get("creator_exposure", false))

static func set_profile_style(profile: ModularFighterProfile, style_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("hair_profile_missing")
		return failures
	var manifest := _manifest()
	if manifest.is_empty():
		failures.append("hair_manifest_missing")
		return failures
	var styles = manifest.get("styles", {})
	var style_name := str(style_id)
	if not (styles is Dictionary) or not styles.has(style_name):
		failures.append("hair_style_unknown:%s" % style_name)
		return failures
	var style = styles[style_name]
	if not (style is Dictionary):
		failures.append("hair_style_contract_invalid:%s" % style_name)
		return failures

	var back_id := str(style.get("hair_back", ""))
	var front_id := str(style.get("hair_front", ""))
	if style_name == str(DEFAULT_STYLE):
		if not back_id.is_empty() or not front_id.is_empty():
			failures.append("hair_none_must_be_empty")
			return failures
		profile.clear_module(HAIR_BACK)
		profile.clear_module(HAIR_FRONT)
		return failures

	var modules = manifest.get("modules", {})
	if not (modules is Dictionary):
		failures.append("hair_modules_contract_invalid")
		return failures
	for pair in [[str(HAIR_BACK), back_id], [str(HAIR_FRONT), front_id]]:
		var slot_name: String = pair[0]
		var module_name: String = pair[1]
		if module_name.is_empty() or not modules.has(module_name):
			failures.append("hair_style_module_missing:%s:%s" % [style_name, slot_name])
			continue
		var contract = modules[module_name]
		if not (contract is Dictionary) or str(contract.get("slot", "")) != slot_name:
			failures.append("hair_style_slot_mismatch:%s:%s" % [style_name, slot_name])
	if not failures.is_empty():
		return failures

	# Atomic commit: do not mutate one side until the full pair is valid.
	profile.set_module(HAIR_BACK, StringName(back_id))
	profile.set_module(HAIR_FRONT, StringName(front_id))
	return failures

static func profile_style_id(profile: ModularFighterProfile) -> StringName:
	if profile == null:
		return &""
	var back_id := str(profile.module_id(HAIR_BACK))
	var front_id := str(profile.module_id(HAIR_FRONT))
	var manifest := _manifest()
	var styles = manifest.get("styles", {})
	if not (styles is Dictionary):
		return &""
	if back_id.is_empty() and front_id.is_empty():
		return StringName(str(manifest.get("default_style_id", "hair_none")))
	for raw_style in styles.keys():
		var style_name := str(raw_style)
		var style = styles[style_name]
		if not (style is Dictionary):
			continue
		if str(style.get("hair_back", "")) == back_id and str(style.get("hair_front", "")) == front_id:
			return StringName(style_name)
	return &""

static func validate_profile_pair(profile: ModularFighterProfile) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("hair_profile_missing")
		return failures
	var back_id := str(profile.module_id(HAIR_BACK))
	var front_id := str(profile.module_id(HAIR_FRONT))
	if back_id.is_empty() and front_id.is_empty():
		return failures
	if profile_style_id(profile) == &"":
		failures.append("hair_profile_pair_not_atomic")
	return failures

static func assemble_profile(profile: ModularFighterProfile, assembler: ModularFighterAssembler) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("hair_profile_missing")
		return failures
	if assembler == null or not assembler.is_ready_for_render():
		failures.append("hair_assembler_not_ready")
		return failures
	failures.append_array(validate_profile_pair(profile))
	if not failures.is_empty():
		return failures

	var style_id := profile_style_id(profile)
	if style_id == &"" or style_id == DEFAULT_STYLE:
		assembler.clear_visual_module(HAIR_BACK)
		assembler.clear_visual_module(HAIR_FRONT)
		return failures

	var manifest := _manifest()
	var styles = manifest.get("styles", {})
	var style = styles.get(str(style_id), {}) if styles is Dictionary else {}
	if not (style is Dictionary):
		failures.append("hair_style_contract_invalid:%s" % str(style_id))
		return failures
	var modules = manifest.get("modules", {})
	if not (modules is Dictionary):
		failures.append("hair_modules_contract_invalid")
		return failures

	# Build both sprites before attaching either one. This keeps runtime mutation atomic.
	var pending: Array[Dictionary] = []
	for pair in [[HAIR_BACK, str(style.get("hair_back", ""))], [HAIR_FRONT, str(style.get("hair_front", ""))]]:
		var slot: StringName = pair[0]
		var module_name: String = pair[1]
		if module_name.is_empty() or not modules.has(module_name):
			failures.append("hair_runtime_module_missing:%s" % module_name)
			continue
		var contract = modules[module_name]
		if not (contract is Dictionary) or str(contract.get("slot", "")) != str(slot):
			failures.append("hair_runtime_slot_mismatch:%s" % module_name)
			continue
		var asset_path := "res://%s" % str(contract.get("path", ""))
		if not ResourceLoader.exists(asset_path):
			failures.append("hair_asset_missing:%s" % module_name)
			continue
		var texture := load(asset_path) as Texture2D
		if texture == null or texture.get_size() != Vector2(1024, 1024):
			failures.append("hair_texture_invalid:%s" % module_name)
			continue
		var pivot = contract.get("pivot", [0.5, 0.92])
		if not (pivot is Array) or pivot.size() != 2:
			failures.append("hair_pivot_invalid:%s" % module_name)
			continue
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = true
		sprite.position = Vector2(
			texture.get_width() * (0.5 - float(pivot[0])),
			texture.get_height() * (0.5 - float(pivot[1]))
		)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.z_index = ModularFighterLayerPolicy.z_index_for(slot)
		pending.append({"slot": slot, "sprite": sprite, "module": module_name})
	if not failures.is_empty():
		for item in pending:
			(item["sprite"] as Sprite2D).free()
		return failures

	for item in pending:
		var slot := item["slot"] as StringName
		var sprite := item["sprite"] as Sprite2D
		if not assembler.attach_visual_module(slot, sprite):
			failures.append("hair_attach_failed:%s" % str(item["module"]))
			break
	if not failures.is_empty():
		assembler.clear_visual_module(HAIR_BACK)
		assembler.clear_visual_module(HAIR_FRONT)
	return failures

static func runtime_signature(profile: ModularFighterProfile, assembler: ModularFighterAssembler) -> Dictionary:
	var back := assembler.get_node_or_null("Module_hair_back") as Sprite2D if assembler != null else null
	var front := assembler.get_node_or_null("Module_hair_front") as Sprite2D if assembler != null else null
	return {
		"style_id": str(profile_style_id(profile)),
		"hair_back_present": back != null,
		"hair_front_present": front != null,
		"hair_back_z": back.z_index if back != null else -1,
		"hair_front_z": front.z_index if front != null else -1,
		"atomic_pair": true,
		"creator_exposure": creator_exposure_enabled(),
		"signature": "Tehkné Solutions",
	}

static func _manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or str(parsed.get("pack_id", "")) != "BASE02_HAIR":
		return {}
	return parsed

# Tehkné Solutions
