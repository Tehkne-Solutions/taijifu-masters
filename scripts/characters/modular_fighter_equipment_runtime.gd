class_name ModularFighterEquipmentRuntime
extends RefCounted

## Shared visual-equipment boundary for canonical modular-fighter weapon slots.
## Combat weapon behavior remains owned by WeaponKitCatalog/BattleLoadoutCatalog.
## This runtime resolves only visual profile modules into ModularFighterAssembler.
## Tehkné Solutions

const MANIFEST_PATH := "res://assets/modular_fighters/shared_equipment/manifest.json"
const BASE05_MANIFEST_PATH := "res://assets/modular_fighters/base_05/manifest.json"
const WEAPON_MAIN_SLOT := &"weapon_main"
const WEAPON_OFFHAND_SLOT := &"weapon_offhand"
const WEAPON_SET_SLOTS := [WEAPON_MAIN_SLOT, WEAPON_OFFHAND_SLOT]

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

## BASE-05.4 public selection is a weapon_set, never a raw visual slot. The set
## owns weapon_main + weapon_offhand atomically while weapon_back stays delegated
## to SHARED_MODULAR_EQUIPMENT and combat_loadout_id stays outside visual editing.
static func weapon_set_creator_exposure_enabled() -> bool:
	var manifest := _base05_manifest()
	var controls = manifest.get("public_controls", {})
	if not (controls is Dictionary):
		return false
	var weapon_set = controls.get("weapon_set", {})
	var promotion = manifest.get("promotion", {})
	return (
		weapon_set is Dictionary
		and promotion is Dictionary
		and bool(weapon_set.get("creator_exposed", false))
		and bool(promotion.get("creator_exposure", false))
	)

static func creator_weapon_set_ids() -> PackedStringArray:
	var result := PackedStringArray()
	if not weapon_set_creator_exposure_enabled():
		return result
	var sets = _base05_manifest().get("weapon_sets", {})
	if not (sets is Dictionary):
		return result
	var others := PackedStringArray()
	for raw_id in sets.keys():
		var set_id := String(raw_id)
		var contract = sets[set_id]
		if not (contract is Dictionary):
			continue
		if not bool(contract.get("production_ready", false)) or not bool(contract.get("creator_ready", false)):
			continue
		if set_id == "weapon_none":
			result.append(set_id)
		else:
			others.append(set_id)
	others.sort()
	result.append_array(others)
	return result

static func weapon_set_label(set_id: StringName) -> String:
	var contract := _weapon_set_contract(set_id)
	return String(contract.get("label", String(set_id))) if not contract.is_empty() else String(set_id)

static func profile_weapon_set_id(profile: ModularFighterProfile) -> StringName:
	if profile == null:
		return &""
	var sets = _base05_manifest().get("weapon_sets", {})
	if not (sets is Dictionary):
		return &""
	var main_id := String(profile.module_id(WEAPON_MAIN_SLOT))
	var offhand_id := String(profile.module_id(WEAPON_OFFHAND_SLOT))
	for raw_id in sets.keys():
		var set_id := String(raw_id)
		var contract = sets[set_id]
		if not (contract is Dictionary):
			continue
		var expected_main := String(contract.get("weapon_main", ""))
		var expected_offhand := String(contract.get("weapon_offhand", ""))
		if main_id == expected_main and offhand_id == expected_offhand:
			return StringName(set_id)
	return &""

static func validate_profile_weapon_set(profile: ModularFighterProfile) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("weapon_set_profile_missing")
		return failures
	var set_id := profile_weapon_set_id(profile)
	if set_id == &"":
		failures.append("weapon_set_profile_not_atomic")
		return failures
	var contract := _weapon_set_contract(set_id)
	if contract.is_empty() or not bool(contract.get("runtime_ready", false)):
		failures.append("weapon_set_profile_not_runtime_ready:%s" % String(set_id))
	return failures

static func set_profile_weapon_set(profile: ModularFighterProfile, set_id: StringName) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("weapon_set_profile_missing")
		return failures
	if not creator_weapon_set_ids().has(String(set_id)):
		failures.append("weapon_set_not_creator_ready:%s" % String(set_id))
		return failures
	var contract := _weapon_set_contract(set_id)
	if contract.is_empty():
		failures.append("weapon_set_contract_missing:%s" % String(set_id))
		return failures
	var weapon_back_before := profile.module_id(&"weapon_back")
	var combat_before := profile.combat_loadout_id
	_apply_optional_module(profile, WEAPON_MAIN_SLOT, contract.get("weapon_main", null))
	_apply_optional_module(profile, WEAPON_OFFHAND_SLOT, contract.get("weapon_offhand", null))
	if profile.module_id(&"weapon_back") != weapon_back_before:
		failures.append("weapon_set_mutated_weapon_back")
	if profile.combat_loadout_id != combat_before:
		failures.append("weapon_set_mutated_combat_loadout")
	failures.append_array(validate_profile_weapon_set(profile))
	return failures

static func weapon_set_creator_signature(profile: ModularFighterProfile) -> Dictionary:
	return {
		"creator_exposure": weapon_set_creator_exposure_enabled(),
		"selection_unit": "weapon_set",
		"atomic_slots": ["weapon_main", "weapon_offhand"],
		"direct_slot_controls": false,
		"weapon_back_creator_control": false,
		"combat_loadout_mutation": false,
		"production_sets": Array(creator_weapon_set_ids()),
		"current_set": String(profile_weapon_set_id(profile)),
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

static func _weapon_set_contract(set_id: StringName) -> Dictionary:
	var sets = _base05_manifest().get("weapon_sets", {})
	if not (sets is Dictionary):
		return {}
	var contract = sets.get(String(set_id), {})
	return contract as Dictionary if contract is Dictionary else {}

static func _apply_optional_module(profile: ModularFighterProfile, slot: StringName, value: Variant) -> void:
	var module_id := String(value) if value != null else ""
	if module_id.is_empty():
		profile.clear_module(slot)
	else:
		profile.set_module(slot, StringName(module_id))

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
