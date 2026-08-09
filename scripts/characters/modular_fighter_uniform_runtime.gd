class_name ModularFighterUniformRuntime
extends RefCounted

## BASE-03 Martial Arts Uniform pack boundary. Public selection is atomic by
## uniform_set while the assembler keeps each garment slot as an independent node.
## Tehkné Solutions

const MANIFEST_PATH := "res://assets/modular_fighters/base_03/manifest.json"
const DEFAULT_SET := &"uniform_none"
const UNIFORM_SLOTS := [
	&"torso_inner", &"torso_outer", &"arms", &"hands", &"waist", &"legs", &"feet",
]

static func set_ids() -> PackedStringArray:
	var result := PackedStringArray()
	var manifest := _manifest()
	var sets = manifest.get("sets", {})
	if not (sets is Dictionary):
		return result
	for raw_id in sets.keys():
		result.append(str(raw_id))
	result.sort()
	return result

static func creator_set_ids() -> PackedStringArray:
	var result := PackedStringArray()
	if not creator_exposure_enabled():
		return result
	var manifest := _manifest()
	var sets = manifest.get("sets", {})
	if not (sets is Dictionary):
		return result
	for raw_id in sets.keys():
		var set_id := str(raw_id)
		var set_contract = sets[set_id]
		if set_contract is Dictionary and bool(set_contract.get("production_ready", false)):
			result.append(set_id)
	result.sort()
	return result

static func set_label(set_id: StringName) -> String:
	var sets = _manifest().get("sets", {})
	var key := str(set_id)
	if not (sets is Dictionary) or not sets.has(key) or not (sets[key] is Dictionary):
		return key
	return str((sets[key] as Dictionary).get("label", key))

static func creator_exposure_enabled() -> bool:
	var promotion = _manifest().get("promotion", {})
	return promotion is Dictionary and bool(promotion.get("creator_exposure", false))

static func set_profile_set(profile: ModularFighterProfile, set_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("uniform_profile_missing")
		return failures
	var manifest := _manifest()
	if manifest.is_empty():
		failures.append("uniform_manifest_missing")
		return failures
	var sets = manifest.get("sets", {})
	var set_name := str(set_id)
	if not (sets is Dictionary) or not sets.has(set_name):
		failures.append("uniform_set_unknown:%s" % set_name)
		return failures
	var set_contract = sets[set_name]
	if not (set_contract is Dictionary):
		failures.append("uniform_set_contract_invalid:%s" % set_name)
		return failures
	if set_name != str(DEFAULT_SET) and not bool(set_contract.get("runtime_ready", false)):
		failures.append("uniform_set_runtime_blocked:%s" % set_name)
		return failures

	var modules = manifest.get("modules", {})
	if not (modules is Dictionary):
		failures.append("uniform_modules_contract_invalid")
		return failures
	var resolved: Dictionary = {}
	for slot in UNIFORM_SLOTS:
		var slot_name := str(slot)
		var module_name := _module_ref(set_contract.get(slot_name, null))
		resolved[slot_name] = module_name
		if module_name.is_empty():
			continue
		if not modules.has(module_name):
			failures.append("uniform_set_module_missing:%s:%s" % [set_name, slot_name])
			continue
		var module_contract = modules[module_name]
		if not (module_contract is Dictionary) or str(module_contract.get("slot", "")) != slot_name:
			failures.append("uniform_set_slot_mismatch:%s:%s" % [set_name, slot_name])
	if not failures.is_empty():
		return failures

	# Atomic profile mutation: only commit after every referenced module validates.
	for slot in UNIFORM_SLOTS:
		profile.clear_module(slot)
		var module_name := str(resolved.get(str(slot), ""))
		if not module_name.is_empty():
			profile.set_module(slot, StringName(module_name))
	return failures

static func profile_set_id(profile: ModularFighterProfile) -> StringName:
	if profile == null:
		return &""
	var manifest := _manifest()
	var sets = manifest.get("sets", {})
	if not (sets is Dictionary):
		return &""
	var has_any := false
	for slot in UNIFORM_SLOTS:
		if profile.module_id(slot) != &"":
			has_any = true
			break
	if not has_any:
		return StringName(str(manifest.get("default_set_id", "uniform_none")))
	for raw_set in sets.keys():
		var set_name := str(raw_set)
		var set_contract = sets[set_name]
		if not (set_contract is Dictionary):
			continue
		var matches := true
		for slot in UNIFORM_SLOTS:
			if str(profile.module_id(slot)) != _module_ref(set_contract.get(str(slot), null)):
				matches = false
				break
		if matches:
			return StringName(set_name)
	return &""

static func validate_profile_set(profile: ModularFighterProfile) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("uniform_profile_missing")
		return failures
	if profile_set_id(profile) == &"":
		failures.append("uniform_profile_not_atomic_set")
	return failures

static func assemble_profile(profile: ModularFighterProfile, assembler: ModularFighterAssembler) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("uniform_profile_missing")
		return failures
	if assembler == null or not assembler.is_ready_for_render():
		failures.append("uniform_assembler_not_ready")
		return failures
	failures.append_array(validate_profile_set(profile))
	if not failures.is_empty():
		return failures

	var set_id := profile_set_id(profile)
	if set_id == DEFAULT_SET:
		for slot in UNIFORM_SLOTS:
			assembler.clear_visual_module(slot)
		return failures

	var manifest := _manifest()
	var sets = manifest.get("sets", {})
	var modules = manifest.get("modules", {})
	var set_contract = sets.get(str(set_id), {}) if sets is Dictionary else {}
	if not (set_contract is Dictionary) or not (modules is Dictionary):
		failures.append("uniform_runtime_contract_invalid:%s" % str(set_id))
		return failures
	if not bool(set_contract.get("runtime_ready", false)):
		failures.append("uniform_runtime_set_blocked:%s" % str(set_id))
		return failures

	var pending: Array[Dictionary] = []
	for slot in UNIFORM_SLOTS:
		var module_name := _module_ref(set_contract.get(str(slot), null))
		if module_name.is_empty():
			continue
		if not modules.has(module_name):
			failures.append("uniform_runtime_module_missing:%s" % module_name)
			continue
		var contract = modules[module_name]
		if not (contract is Dictionary) or str(contract.get("slot", "")) != str(slot):
			failures.append("uniform_runtime_slot_mismatch:%s" % module_name)
			continue
		var asset_path := "res://%s" % str(contract.get("path", ""))
		if not ResourceLoader.exists(asset_path):
			failures.append("uniform_asset_missing:%s" % module_name)
			continue
		var texture := load(asset_path) as Texture2D
		if texture == null or texture.get_size() != Vector2(1024, 1024):
			failures.append("uniform_texture_invalid:%s" % module_name)
			continue
		var pivot = contract.get("pivot", [0.5, 0.92])
		if not (pivot is Array) or pivot.size() != 2:
			failures.append("uniform_pivot_invalid:%s" % module_name)
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

	# Atomic assembler mutation: clear the full set only after all sprites exist.
	for slot in UNIFORM_SLOTS:
		assembler.clear_visual_module(slot)
	for item in pending:
		var slot := item["slot"] as StringName
		var sprite := item["sprite"] as Sprite2D
		if not assembler.attach_visual_module(slot, sprite):
			failures.append("uniform_attach_failed:%s" % str(item["module"]))
			break
	if not failures.is_empty():
		for slot in UNIFORM_SLOTS:
			assembler.clear_visual_module(slot)
	return failures

static func runtime_signature(profile: ModularFighterProfile, assembler: ModularFighterAssembler) -> Dictionary:
	var nodes: Dictionary = {}
	for slot in UNIFORM_SLOTS:
		var node := assembler.get_node_or_null("Module_%s" % str(slot)) as Sprite2D if assembler != null else null
		nodes[str(slot)] = {
			"module_id": str(profile.module_id(slot)) if profile != null else "",
			"present": node != null,
			"z": node.z_index if node != null else -1,
		}
	return {
		"set_id": str(profile_set_id(profile)),
		"nodes": nodes,
		"atomic_set": true,
		"creator_exposure": creator_exposure_enabled(),
		"signature": "Tehkné Solutions",
	}

static func _module_ref(value: Variant) -> String:
	return "" if value == null else str(value)

static func _manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or str(parsed.get("pack_id", "")) != "BASE03_MARTIAL_ARTS_UNIFORMS":
		return {}
	return parsed

# Tehkné Solutions
