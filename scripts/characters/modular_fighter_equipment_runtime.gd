class_name ModularFighterEquipmentRuntime
extends RefCounted

## Shared visual-equipment boundary for canonical modular-fighter weapon slots.
## Combat weapon behavior remains owned by WeaponKitCatalog/BattleLoadoutCatalog.
## This runtime resolves only visual profile modules into ModularFighterAssembler.
## Tehkné Solutions

const MANIFEST_PATH := "res://assets/modular_fighters/shared_equipment/manifest.json"
const BASE05_MANIFEST_PATH := "res://assets/modular_fighters/base_05/manifest.json"
const WEAPON_MAIN_SLOT := &"weapon_main"

static func runtime_activation_enabled() -> bool:
	var promotion = _manifest().get("promotion", {})
	return promotion is Dictionary and bool(promotion.get("runtime_activation", false))

static func runtime_slots() -> Array[StringName]:
	var result: Array[StringName] = []
	var values = _manifest().get("runtime_slots", [])
	if values is Array:
		for value in values:
			result.append(StringName(String(value)))
	return result

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
	for slot in runtime_slots():
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
	for slot in runtime_slots():
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
		var sprite_result := _sprite_from_contract(slot, module_id, contract)
		if not bool(sprite_result.get("ok", false)):
			failures.append(String(sprite_result.get("failure", "equipment_sprite_invalid:%s" % module_id)))
			continue
		pending.append({"slot": slot, "sprite": sprite_result["sprite"], "module": module_id})
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
		for slot in runtime_slots():
			assembler.clear_visual_module(slot)
	return failures

## BASE-05 weapon_main remains in this same visual runtime instead of creating a
## second weapon system. The node is attached once, hidden by default, and its
## visibility is driven by the presenter's visual state. Combat behavior stays
## entirely outside this class.
static func weapon_main_runtime_activation_enabled() -> bool:
	var promotion = _base05_manifest().get("promotion", {})
	return promotion is Dictionary and bool(promotion.get("weapon_main_runtime_activation", false))

static func validate_weapon_main_profile(profile: ModularFighterProfile) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("weapon_main_profile_missing")
		return failures
	var module_id := String(profile.module_id(WEAPON_MAIN_SLOT))
	if module_id.is_empty():
		return failures
	var manifest := _base05_manifest()
	var modules = manifest.get("modules", {})
	if not (modules is Dictionary) or not modules.has(module_id):
		failures.append("weapon_main_module_unknown:%s" % module_id)
		return failures
	var contract = modules[module_id]
	if not (contract is Dictionary):
		failures.append("weapon_main_contract_invalid:%s" % module_id)
		return failures
	if String(contract.get("slot", "")) != String(WEAPON_MAIN_SLOT):
		failures.append("weapon_main_slot_mismatch:%s" % module_id)
	if String(contract.get("combat_reference", "")) == "":
		failures.append("weapon_main_combat_reference_missing:%s" % module_id)
	return failures

static func assemble_weapon_main_profile(profile: ModularFighterProfile, assembler: ModularFighterAssembler, allow_candidate := false) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("weapon_main_profile_missing")
		return failures
	if assembler == null or not assembler.is_ready_for_render():
		failures.append("weapon_main_assembler_not_ready")
		return failures
	var module_id := String(profile.module_id(WEAPON_MAIN_SLOT))
	if module_id.is_empty():
		assembler.clear_visual_module(WEAPON_MAIN_SLOT)
		return failures
	if not weapon_main_runtime_activation_enabled() and not allow_candidate:
		failures.append("weapon_main_runtime_not_promoted")
		return failures
	failures.append_array(validate_weapon_main_profile(profile))
	if not failures.is_empty():
		return failures
	var modules = _base05_manifest().get("modules", {})
	var contract = modules.get(module_id, {})
	if not (contract is Dictionary):
		failures.append("weapon_main_contract_invalid:%s" % module_id)
		return failures
	if not bool(contract.get("runtime_ready", false)) and not allow_candidate:
		failures.append("weapon_main_module_runtime_blocked:%s" % module_id)
		return failures
	var sprite_result := _sprite_from_contract(WEAPON_MAIN_SLOT, module_id, contract)
	if not bool(sprite_result.get("ok", false)):
		failures.append(String(sprite_result.get("failure", "weapon_main_sprite_invalid:%s" % module_id)))
		return failures
	var sprite := sprite_result["sprite"] as Sprite2D
	sprite.visible = false
	assembler.clear_visual_module(WEAPON_MAIN_SLOT)
	if not assembler.attach_visual_module(WEAPON_MAIN_SLOT, sprite):
		sprite.free()
		failures.append("weapon_main_attach_failed:%s" % module_id)
	return failures

static func set_weapon_main_visible(assembler: ModularFighterAssembler, visible: bool) -> bool:
	if assembler == null:
		return false
	var node := assembler.get_node_or_null("Module_weapon_main") as Sprite2D
	if node == null:
		return not visible
	node.visible = visible
	return node.visible == visible

static func weapon_main_signature(profile: ModularFighterProfile, assembler: ModularFighterAssembler) -> Dictionary:
	var node := assembler.get_node_or_null("Module_weapon_main") as Sprite2D if assembler != null else null
	var module_id := String(profile.module_id(WEAPON_MAIN_SLOT)) if profile != null else ""
	var contract = _base05_manifest().get("modules", {}).get(module_id, {})
	return {
		"runtime_activation": weapon_main_runtime_activation_enabled(),
		"module_id": module_id,
		"present": node != null,
		"visible": node.visible if node != null else false,
		"z": node.z_index if node != null else -1,
		"combat_reference": String(contract.get("combat_reference", "")) if contract is Dictionary else "",
		"combat_logic_owner": "WeaponKitCatalog_and_BattleLoadoutCatalog",
		"visual_owner": "ModularFighterEquipmentRuntime",
		"signature": "Tehkné Solutions",
	}

static func runtime_signature(profile: ModularFighterProfile, assembler: ModularFighterAssembler) -> Dictionary:
	var nodes := {}
	for slot in runtime_slots():
		var node := assembler.get_node_or_null("Module_%s" % String(slot)) as Sprite2D if assembler != null else null
		nodes[String(slot)] = {
			"module_id": String(profile.module_id(slot)) if profile != null else "",
			"present": node != null,
			"z": node.z_index if node != null else -1,
		}
	return {
		"runtime_activation": runtime_activation_enabled(),
		"runtime_slots": runtime_slots().map(func(value): return String(value)),
		"nodes": nodes,
		"weapon_main": weapon_main_signature(profile, assembler),
		"combat_logic_owner": "WeaponKitCatalog_and_BattleLoadoutCatalog",
		"visual_owner": "SHARED_MODULAR_EQUIPMENT_plus_BASE05_via_ModularFighterEquipmentRuntime",
		"signature": "Tehkné Solutions",
	}

static func _sprite_from_contract(slot: StringName, module_id: String, contract: Dictionary) -> Dictionary:
	var asset_path := "res://%s" % String(contract.get("path", ""))
	if not ResourceLoader.exists(asset_path):
		return {"ok": false, "failure": "equipment_asset_missing:%s" % module_id}
	var texture := load(asset_path) as Texture2D
	if texture == null or texture.get_size() != Vector2(1024, 1024):
		return {"ok": false, "failure": "equipment_texture_invalid:%s" % module_id}
	var pivot = contract.get("pivot", [0.5, 0.92])
	if not (pivot is Array) or pivot.size() != 2:
		return {"ok": false, "failure": "equipment_pivot_invalid:%s" % module_id}
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = Vector2(
		texture.get_width() * (0.5 - float(pivot[0])),
		texture.get_height() * (0.5 - float(pivot[1]))
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_index = ModularFighterLayerPolicy.z_index_for(slot)
	return {"ok": true, "sprite": sprite}

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

static func _base05_manifest() -> Dictionary:
	if not FileAccess.file_exists(BASE05_MANIFEST_PATH):
		return {}
	var file := FileAccess.open(BASE05_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or String(parsed.get("pack_id", "")) != "BASE05_WEAPONS":
		return {}
	return parsed

# Tehkné Solutions
