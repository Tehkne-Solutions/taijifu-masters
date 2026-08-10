class_name ModularFighterEquipmentRuntime
extends RefCounted

## Shared visual-equipment boundary for canonical modular-fighter weapon slots.
## Combat weapon behavior remains owned by WeaponKitCatalog/BattleLoadoutCatalog.
## This runtime resolves only visual profile modules into ModularFighterAssembler.
## Tehkné Solutions

const MANIFEST_PATH := "res://assets/modular_fighters/shared_equipment/manifest.json"
const EQUIPMENT_SLOTS := [&"weapon_main", &"weapon_offhand", &"weapon_back"]

static func runtime_activation_enabled() -> bool:
	var promotion = _manifest().get("promotion", {})
	return promotion is Dictionary and bool(promotion.get("runtime_activation", false))

static func module_ids(slot: StringName = &"") -> PackedStringArray:
	var result := PackedStringArray()
	var modules = _manifest().get("modules", {})
	if not (modules is Dictionary):
		return result
	for raw_id in modules.keys():
		var module_id := String(raw_id)
		var contract = modules[module_id]
		if not (contract is Dictionary):
			continue
		if slot != &"" and String(contract.get("slot", "")) != String(slot):
			continue
		result.append(module_id)
	result.sort()
	return result

static func validate_profile(profile: ModularFighterProfile) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("equipment_profile_missing")
		return failures
	var modules = _manifest().get("modules", {})
	if not (modules is Dictionary):
		failures.append("equipment_manifest_modules_invalid")
		return failures
	for slot in EQUIPMENT_SLOTS:
		var module_id := String(profile.module_id(slot))
		if module_id.is_empty():
			continue
		if not modules.has(module_id):
			failures.append("equipment_module_unknown:%s:%s" % [String(slot), module_id])
			continue
		var contract = modules[module_id]
		if not (contract is Dictionary) or String(contract.get("slot", "")) != String(slot):
			failures.append("equipment_module_slot_mismatch:%s:%s" % [String(slot), module_id])
	return failures

static func assemble_profile(profile: ModularFighterProfile, assembler: ModularFighterAssembler, allow_candidate := false) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("equipment_profile_missing")
		return failures
	if assembler == null or not assembler.is_ready_for_render():
		failures.append("equipment_assembler_not_ready")
		return failures
	if not runtime_activation_enabled() and not allow_candidate:
		failures.append("equipment_runtime_not_promoted")
		return failures
	failures.append_array(validate_profile(profile))
	if not failures.is_empty():
		return failures

	var modules = _manifest().get("modules", {})
	var pending: Array[Dictionary] = []
	for slot in EQUIPMENT_SLOTS:
		var module_id := String(profile.module_id(slot))
		if module_id.is_empty():
			continue
		var contract = modules.get(module_id, {})
		if not (contract is Dictionary):
			failures.append("equipment_contract_invalid:%s" % module_id)
			continue
		if not bool(contract.get("runtime_ready", false)) and not allow_candidate:
			failures.append("equipment_module_runtime_blocked:%s" % module_id)
			continue
		var asset_path := "res://%s" % String(contract.get("path", ""))
		if not ResourceLoader.exists(asset_path):
			failures.append("equipment_asset_missing:%s" % module_id)
			continue
		var texture := load(asset_path) as Texture2D
		if texture == null or texture.get_size() != Vector2(1024, 1024):
			failures.append("equipment_texture_invalid:%s" % module_id)
			continue
		var pivot = contract.get("pivot", [0.5, 0.92])
		if not (pivot is Array) or pivot.size() != 2:
			failures.append("equipment_pivot_invalid:%s" % module_id)
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
		pending.append({"slot": slot, "sprite": sprite, "module": module_id})
	if not failures.is_empty():
		for item in pending:
			(item["sprite"] as Sprite2D).free()
		return failures

	for item in pending:
		var slot := item["slot"] as StringName
		assembler.clear_visual_module(slot)
		if not assembler.attach_visual_module(slot, item["sprite"] as Sprite2D):
			failures.append("equipment_attach_failed:%s" % String(item["module"]))
			break
	if not failures.is_empty():
		for slot in EQUIPMENT_SLOTS:
			assembler.clear_visual_module(slot)
	return failures

static func runtime_signature(profile: ModularFighterProfile, assembler: ModularFighterAssembler) -> Dictionary:
	var nodes := {}
	for slot in EQUIPMENT_SLOTS:
		var node := assembler.get_node_or_null("Module_%s" % String(slot)) as Sprite2D if assembler != null else null
		nodes[String(slot)] = {
			"module_id": String(profile.module_id(slot)) if profile != null else "",
			"present": node != null,
			"z": node.z_index if node != null else -1,
		}
	return {
		"runtime_activation": runtime_activation_enabled(),
		"nodes": nodes,
		"combat_logic_owner": "WeaponKitCatalog_and_BattleLoadoutCatalog",
		"visual_owner": "SHARED_MODULAR_EQUIPMENT",
		"signature": "Tehkné Solutions",
	}

static func _manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or String(parsed.get("pack_id", "")) != "SHARED_MODULAR_EQUIPMENT":
		return {}
	return parsed

# Tehkné Solutions
