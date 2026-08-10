extends SceneTree

const BASE05_MANIFEST := "res://assets/modular_fighters/base_05/manifest.json"
const LIAN_PRESET := "res://config/fighter-presets/preset_lian_wu.json"

func _init() -> void:
	var manifest := _json(BASE05_MANIFEST)
	if manifest.is_empty():
		_fail("BASE05_FOUNDATION=BLOCKED manifest_missing")
		return
	if String(manifest.get("pack_id", "")) != "BASE05_WEAPONS":
		_fail("BASE05_FOUNDATION=BLOCKED pack_id")
		return
	var runtime_main := bool(manifest.get("promotion", {}).get("weapon_main_runtime_activation", false))
	var creator_live := bool(manifest.get("promotion", {}).get("creator_exposure", false))
	if bool(manifest.get("promotion", {}).get("weapon_offhand_runtime_activation", true)):
		_fail("BASE05_FOUNDATION=BLOCKED weapon_offhand_premature")
		return
	if creator_live:
		var control = manifest.get("public_controls", {}).get("weapon_set", {})
		if not (control is Dictionary):
			_fail("BASE05_FOUNDATION=BLOCKED creator_control_contract")
			return
		if not bool(control.get("creator_exposed", false)) or not bool(control.get("selection_atomic", false)):
			_fail("BASE05_FOUNDATION=BLOCKED creator_atomicity")
			return
		if bool(control.get("direct_slot_controls", true)) or bool(control.get("weapon_back_control", true)) or bool(control.get("combat_loadout_mutation", true)):
			_fail("BASE05_FOUNDATION=BLOCKED creator_ownership")
			return

	if ModularFighterLayerPolicy.z_index_for(&"weapon_back") != 3:
		_fail("BASE05_FOUNDATION=BLOCKED weapon_back_layer")
		return
	if ModularFighterLayerPolicy.z_index_for(&"weapon_main") != 80:
		_fail("BASE05_FOUNDATION=BLOCKED weapon_main_layer")
		return
	if ModularFighterLayerPolicy.z_index_for(&"weapon_offhand") != 81:
		_fail("BASE05_FOUNDATION=BLOCKED weapon_offhand_layer")
		return

	# The shared runtime scope is immutable: weapon_back stays delegated to
	# SHARED_MODULAR_EQUIPMENT. BASE-05 weapon_main evolves through dedicated
	# methods on the same visual runtime and must never be injected here.
	var runtime_slots := ModularFighterEquipmentRuntime.runtime_slots()
	if runtime_slots != [&"weapon_back"]:
		_fail("BASE05_FOUNDATION=BLOCKED shared_runtime_scope:%s" % str(runtime_slots))
		return
	if not ModularFighterEquipmentRuntime.module_ids(&"weapon_main").is_empty():
		_fail("BASE05_FOUNDATION=BLOCKED shared_weapon_main_scope")
		return
	if not ModularFighterEquipmentRuntime.module_ids(&"weapon_offhand").is_empty():
		_fail("BASE05_FOUNDATION=BLOCKED weapon_offhand_module_premature")
		return
	if not ModularFighterEquipmentRuntime.module_ids(&"weapon_back").has("sheath_lian_wu_blue"):
		_fail("BASE05_FOUNDATION=BLOCKED sheath_reference")
		return
	if ModularFighterEquipmentRuntime.weapon_main_runtime_activation_enabled() != runtime_main:
		_fail("BASE05_FOUNDATION=BLOCKED weapon_main_activation_mismatch")
		return
	if ModularFighterEquipmentRuntime.weapon_set_creator_exposure_enabled() != creator_live:
		_fail("BASE05_FOUNDATION=BLOCKED creator_activation_mismatch")
		return

	var modules = manifest.get("modules", {})
	if runtime_main:
		if not (modules is Dictionary) or not modules.has("katana_lian_wu"):
			_fail("BASE05_FOUNDATION=BLOCKED promoted_weapon_main_missing")
			return
		var katana = modules["katana_lian_wu"]
		if not (katana is Dictionary) or String(katana.get("slot", "")) != "weapon_main":
			_fail("BASE05_FOUNDATION=BLOCKED promoted_weapon_main_slot")
			return
	else:
		if not modules.is_empty():
			_fail("BASE05_FOUNDATION=BLOCKED pre_runtime_modules_present")
			return

	var preset := _json(LIAN_PRESET)
	if String(preset.get("modules", {}).get("weapon_main", "")) != "katana_lian_wu":
		_fail("BASE05_FOUNDATION=BLOCKED lian_weapon_main_reference")
		return
	if String(preset.get("modules", {}).get("weapon_back", "")) != "sheath_lian_wu_blue":
		_fail("BASE05_FOUNDATION=BLOCKED lian_weapon_back_reference")
		return

	var profile := ModularFighterProfile.new()
	profile.profile_id = &"base05_foundation_probe"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_module(&"weapon_main", &"katana_lian_wu")
	profile.set_module(&"weapon_back", &"sheath_lian_wu_blue")
	var profile_failures := profile.validate_against_standard()
	if not profile_failures.is_empty():
		_fail("BASE05_FOUNDATION=BLOCKED standard_slots:%s" % ",".join(profile_failures))
		return

	if WeaponKitCatalog.label_for(&"serene_katana") != "KATANA SERENA":
		_fail("BASE05_FOUNDATION=BLOCKED serene_katana_catalog")
		return
	if WeaponKitCatalog.preferred_range(&"serene_katana") <= 0.0:
		_fail("BASE05_FOUNDATION=BLOCKED serene_katana_behavior")
		return

	var binding_state := String(manifest.get("required_references", {}).get("katana_lian_wu", {}).get("visual_to_combat_binding_status", ""))
	if not ["pending_battle_loadout_verification", "verified_via_current_first_playable_fallback"].has(binding_state):
		_fail("BASE05_FOUNDATION=BLOCKED binding_lifecycle:%s" % binding_state)
		return

	print("BASE05_FOUNDATION=PASS pack=BASE05_WEAPONS")
	print("BASE05_OWNERSHIP=PASS combat=WeaponKitCatalog_and_BattleLoadoutCatalog visual=ModularFighterEquipmentRuntime")
	print("BASE05_SLOTS=PASS weapon_back=3 weapon_main=80 weapon_offhand=81 runtime_main=%s runtime_offhand=false" % str(runtime_main).to_lower())
	print("BASE05_LIAN_REFERENCE=PASS weapon_main=katana_lian_wu weapon_back=sheath_lian_wu_blue combat_kit=serene_katana binding=%s" % binding_state)
	print("BASE05_CREATOR_LIFECYCLE=PASS exposed=%s unit=weapon_set direct_slots=false weapon_back=false combat_mutation=false" % str(creator_live).to_lower())
	print("BASE05_FOUNDATION_LIFECYCLE=PASS status=%s" % String(manifest.get("status", "")))
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _fail(message: String) -> void:
	push_error(message)
	print(message)
	quit(1)

# Tehkné Solutions
