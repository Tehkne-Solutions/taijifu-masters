class_name ModularFighterArmorRuntime
extends RefCounted

## BASE-04 Armor & Accessories runtime.
## armor_set owns head_accessory + shoulders atomically; back_accessory is independent.
## Tehkné Solutions

const MANIFEST_PATH := "res://assets/modular_fighters/base_04/manifest.json"
const DEFAULT_ARMOR_SET := &"armor_none"
const DEFAULT_BACK_ACCESSORY := &"back_none"
const ARMOR_SLOTS := [&"head_accessory", &"shoulders"]
const BACK_SLOT := &"back_accessory"

static func armor_set_ids(production_only := false) -> PackedStringArray:
	var result := PackedStringArray()
	var sets = _manifest().get("armor_sets", {})
	if not (sets is Dictionary):
		return result
	for raw_id in sets.keys():
		var set_id := String(raw_id)
		var contract = sets[set_id]
		if production_only and (not (contract is Dictionary) or not bool(contract.get("production_ready", false))):
			continue
		result.append(set_id)
	result.sort()
	return result

static func creator_armor_set_ids() -> PackedStringArray:
	var result := PackedStringArray()
	if not creator_exposure_enabled():
		return result
	result = armor_set_ids(true)
	var default_text := String(DEFAULT_ARMOR_SET)
	var default_index := result.find(default_text)
	if default_index > 0:
		result.remove_at(default_index)
		result.insert(0, default_text)
	return result

static func armor_set_label(set_id: StringName) -> String:
	var sets = _manifest().get("armor_sets", {})
	var key := String(set_id)
	if not (sets is Dictionary) or not sets.has(key) or not (sets[key] is Dictionary):
		return key
	return String((sets[key] as Dictionary).get("label", key))

static func creator_exposure_enabled() -> bool:
	var promotion = _manifest().get("promotion", {})
	return promotion is Dictionary and bool(promotion.get("creator_exposure", false))

static func back_accessory_creator_exposure_enabled() -> bool:
	var promotion = _manifest().get("promotion", {})
	return promotion is Dictionary and bool(promotion.get("back_accessory_creator_exposure", false))

static func back_accessory_ids(production_only := false) -> PackedStringArray:
	var result := PackedStringArray()
	var items = _manifest().get("back_accessories", {})
	if not (items is Dictionary):
		return result
	for raw_id in items.keys():
		var item_id := String(raw_id)
		var contract = items[item_id]
		if production_only and (not (contract is Dictionary) or not bool(contract.get("production_ready", false))):
			continue
		result.append(item_id)
	result.sort()
	return result

static func back_accessory_label(accessory_id: StringName) -> String:
	var items = _manifest().get("back_accessories", {})
	var key := String(accessory_id)
	if not (items is Dictionary) or not items.has(key) or not (items[key] is Dictionary):
		return key
	return String((items[key] as Dictionary).get("label", key))

static func set_profile_armor_set(profile: ModularFighterProfile, set_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("armor_profile_missing")
		return failures
	var sets = _manifest().get("armor_sets", {})
	var key := String(set_id)
	if not (sets is Dictionary) or not sets.has(key):
		failures.append("armor_set_unknown:%s" % key)
		return failures
	var set_contract = sets[key]
	if not (set_contract is Dictionary):
		failures.append("armor_set_contract_invalid:%s" % key)
		return failures
	if key != String(DEFAULT_ARMOR_SET) and not bool(set_contract.get("runtime_ready", false)):
		failures.append("armor_set_runtime_blocked:%s" % key)
		return failures
	var resolved := {}
	for slot in ARMOR_SLOTS:
		resolved[String(slot)] = _module_ref(set_contract.get(String(slot), null))
	failures.append_array(_validate_module_refs(resolved))
	if not failures.is_empty():
		return failures
	for slot in ARMOR_SLOTS:
		var module_id := String(resolved.get(String(slot), ""))
		if module_id.is_empty():
			profile.clear_module(slot)
		else:
			profile.set_module(slot, StringName(module_id))
	return failures

static func set_profile_back_accessory(profile: ModularFighterProfile, accessory_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("armor_profile_missing")
		return failures
	var items = _manifest().get("back_accessories", {})
	var key := String(accessory_id)
	if not (items is Dictionary) or not items.has(key):
		failures.append("back_accessory_unknown:%s" % key)
		return failures
	var contract = items[key]
	if not (contract is Dictionary):
		failures.append("back_accessory_contract_invalid:%s" % key)
		return failures
	if key != String(DEFAULT_BACK_ACCESSORY) and not bool(contract.get("runtime_ready", false)):
		failures.append("back_accessory_runtime_blocked:%s" % key)
		return failures
	var module_id := _module_ref(contract.get("back_accessory", null))
	failures.append_array(_validate_module_refs({String(BACK_SLOT): module_id}))
	if not failures.is_empty():
		return failures
	if module_id.is_empty():
		profile.clear_module(BACK_SLOT)
	else:
		profile.set_module(BACK_SLOT, StringName(module_id))
	return failures

static func profile_armor_set_id(profile: ModularFighterProfile) -> StringName:
	if profile == null:
		return &""
	var sets = _manifest().get("armor_sets", {})
	if not (sets is Dictionary):
		return &""
	for raw_id in sets.keys():
		var set_id := String(raw_id)
		var contract = sets[set_id]
		if not (contract is Dictionary):
			continue
		var matches := true
		for slot in ARMOR_SLOTS:
			if String(profile.module_id(slot)) != _module_ref(contract.get(String(slot), null)):
				matches = false
				break
		if matches:
			return StringName(set_id)
	return &""

static func profile_back_accessory_id(profile: ModularFighterProfile) -> StringName:
	if profile == null:
		return &""
	var current := String(profile.module_id(BACK_SLOT))
	var items = _manifest().get("back_accessories", {})
	if not (items is Dictionary):
		return &""
	for raw_id in items.keys():
		var item_id := String(raw_id)
		var contract = items[item_id]
		if contract is Dictionary and current == _module_ref(contract.get("back_accessory", null)):
			return StringName(item_id)
	return &""

static func validate_profile(profile: ModularFighterProfile) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("armor_profile_missing")
		return failures
	if profile_armor_set_id(profile) == &"":
		failures.append("armor_profile_not_atomic_set")
	if profile_back_accessory_id(profile) == &"":
		failures.append("back_accessory_profile_unknown")
	return failures

static func assemble_profile(profile: ModularFighterProfile, assembler: ModularFighterAssembler) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("armor_profile_missing")
		return failures
	if assembler == null or not assembler.is_ready_for_render():
		failures.append("armor_assembler_not_ready")
		return failures
	failures.append_array(validate_profile(profile))
	if not failures.is_empty():
		return failures
	failures.append_array(_assemble_boundary(profile, assembler, ARMOR_SLOTS, "armor_set"))
	if failures.is_empty():
		failures.append_array(_assemble_boundary(profile, assembler, [BACK_SLOT], "back_accessory"))
	return failures

static func runtime_signature(profile: ModularFighterProfile, assembler: ModularFighterAssembler) -> Dictionary:
	var head := assembler.get_node_or_null("Module_head_accessory") as Sprite2D if assembler != null else null
	var shoulders := assembler.get_node_or_null("Module_shoulders") as Sprite2D if assembler != null else null
	var back := assembler.get_node_or_null("Module_back_accessory") as Sprite2D if assembler != null else null
	return {
		"armor_set_id": String(profile_armor_set_id(profile)),
		"back_accessory_id": String(profile_back_accessory_id(profile)),
		"head_accessory_present": head != null,
		"shoulders_present": shoulders != null,
		"back_accessory_present": back != null,
		"head_accessory_z": head.z_index if head != null else -1,
		"shoulders_z": shoulders.z_index if shoulders != null else -1,
		"back_accessory_z": back.z_index if back != null else -1,
		"armor_set_atomic": true,
		"back_accessory_independent": true,
		"creator_exposure": creator_exposure_enabled(),
		"back_accessory_creator_exposure": back_accessory_creator_exposure_enabled(),
		"signature": "Tehkné Solutions"
	}

static func _assemble_boundary(profile: ModularFighterProfile, assembler: ModularFighterAssembler, slots: Array, boundary: String) -> PackedStringArray:
	var failures := PackedStringArray()
	var modules = _manifest().get("modules", {})
	if not (modules is Dictionary):
		failures.append("armor_modules_contract_invalid")
		return failures
	var pending: Array[Dictionary] = []
	for raw_slot in slots:
		var slot := StringName(raw_slot)
		var module_id := String(profile.module_id(slot))
		if module_id.is_empty():
			continue
		if not modules.has(module_id):
			failures.append("armor_runtime_module_missing:%s" % module_id)
			continue
		var contract = modules[module_id]
		if not (contract is Dictionary) or String(contract.get("slot", "")) != String(slot):
			failures.append("armor_runtime_slot_mismatch:%s" % module_id)
			continue
		var asset_path := "res://%s" % String(contract.get("path", ""))
		if not ResourceLoader.exists(asset_path):
			failures.append("armor_asset_missing:%s" % module_id)
			continue
		var texture := load(asset_path) as Texture2D
		if texture == null or texture.get_size() != Vector2(1024, 1024):
			failures.append("armor_texture_invalid:%s" % module_id)
			continue
		var pivot = contract.get("pivot", [0.5, 0.92])
		if not (pivot is Array) or pivot.size() != 2:
			failures.append("armor_pivot_invalid:%s" % module_id)
			continue
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = true
		sprite.position = Vector2(texture.get_width() * (0.5 - float(pivot[0])), texture.get_height() * (0.5 - float(pivot[1])))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.z_index = ModularFighterLayerPolicy.z_index_for(slot)
		pending.append({"slot": slot, "sprite": sprite, "module": module_id})
	if not failures.is_empty():
		for item in pending:
			(item["sprite"] as Sprite2D).free()
		return failures
	for raw_slot in slots:
		assembler.clear_visual_module(StringName(raw_slot))
	for item in pending:
		if not assembler.attach_visual_module(item["slot"] as StringName, item["sprite"] as Sprite2D):
			failures.append("armor_attach_failed:%s:%s" % [boundary, String(item["module"])])
			break
	if not failures.is_empty():
		for raw_slot in slots:
			assembler.clear_visual_module(StringName(raw_slot))
	return failures

static func _validate_module_refs(resolved: Dictionary) -> PackedStringArray:
	var failures := PackedStringArray()
	var modules = _manifest().get("modules", {})
	if not (modules is Dictionary):
		failures.append("armor_modules_contract_invalid")
		return failures
	for raw_slot in resolved.keys():
		var slot := String(raw_slot)
		var module_id := String(resolved[raw_slot])
		if module_id.is_empty():
			continue
		if not modules.has(module_id):
			failures.append("armor_module_missing:%s:%s" % [slot, module_id])
			continue
		var contract = modules[module_id]
		if not (contract is Dictionary) or String(contract.get("slot", "")) != slot:
			failures.append("armor_module_slot_mismatch:%s:%s" % [slot, module_id])
	return failures

static func _module_ref(value: Variant) -> String:
	return "" if value == null else String(value)

static func _manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or String(parsed.get("pack_id", "")) != "BASE04_ARMOR_ACCESSORIES":
		return {}
	return parsed

# Tehkné Solutions
