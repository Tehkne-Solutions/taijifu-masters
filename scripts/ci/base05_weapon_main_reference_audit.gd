extends SceneTree

const MANIFEST_PATH := "res://assets/modular_fighters/base_05/manifest.json"
const AUDIT_PATH := "res://assets/modular_fighters/base_05/production/BASE05_WEAPON_MAIN_REFERENCE_AUDIT.json"
const LIAN_PRESET_PATH := "res://config/fighter-presets/preset_lian_wu.json"

func _init() -> void:
	var manifest: Dictionary = _json(MANIFEST_PATH)
	var audit: Dictionary = _json(AUDIT_PATH)
	var modular_preset: Dictionary = _json(LIAN_PRESET_PATH)
	if manifest.is_empty() or audit.is_empty() or modular_preset.is_empty():
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED json_missing")
		return

	if FirstPlayableController.PLAYER_PRESET != &"lian_wu_first_playable":
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED first_playable_preset")
		return
	var build: BuildProfile = BuildProfile.prototype_preset(FirstPlayableController.PLAYER_PRESET)
	if build.character_id != &"lian_wu" or build.weapon_id != &"serene_katana":
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED build_binding:%s:%s" % [String(build.character_id), String(build.weapon_id)])
		return
	if WeaponKitCatalog.label_for(build.weapon_id) != "KATANA SERENA":
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED kit_label")
		return
	if WeaponKitCatalog.preferred_range(build.weapon_id) != 112.0:
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED kit_behavior")
		return

	var modules_value: Variant = modular_preset.get("modules", {})
	if not (modules_value is Dictionary):
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED preset_modules_contract")
		return
	var preset_modules: Dictionary = modules_value as Dictionary
	if String(preset_modules.get("weapon_main", "")) != "katana_lian_wu":
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED visual_reference")
		return
	if String(modular_preset.get("combat_loadout_id", "")) != "combat_lian_wu_first_playable":
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED modular_metadata")
		return

	var required_value: Variant = manifest.get("required_references", {})
	if not (required_value is Dictionary):
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED required_references_contract")
		return
	var required_references: Dictionary = required_value as Dictionary
	var ref_value: Variant = required_references.get("katana_lian_wu", {})
	if not (ref_value is Dictionary):
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED katana_reference_contract")
		return
	var weapon_ref: Dictionary = ref_value as Dictionary
	if String(weapon_ref.get("combat_catalog_reference", "")) != "serene_katana":
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED manifest_kit")
		return
	if String(weapon_ref.get("visual_to_combat_binding_status", "")) != "verified_via_current_first_playable_fallback":
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED binding_state")
		return
	if String(weapon_ref.get("standalone_visual_status", "")) != "redraw_required":
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED art_state")
		return

	var manifest_modules_value: Variant = manifest.get("modules", {})
	if not (manifest_modules_value is Dictionary) or not (manifest_modules_value as Dictionary).is_empty():
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED premature_module")
		return
	var promotion_value: Variant = manifest.get("promotion", {})
	if not (promotion_value is Dictionary):
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED promotion_contract")
		return
	var promotion: Dictionary = promotion_value as Dictionary
	if bool(promotion.get("weapon_main_runtime_activation", true)) or bool(promotion.get("creator_exposure", true)):
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED premature_promotion")
		return

	var source_review_value: Variant = audit.get("character_lock_source_review", {})
	if not (source_review_value is Dictionary):
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED source_review_contract")
		return
	var source_review: Dictionary = source_review_value as Dictionary
	if String(source_review.get("decision", "")) != "redraw_required":
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED source_decision")
		return
	if not bool(source_review.get("whole_character_crop_as_weapon_module_forbidden", false)):
		_fail("BASE05_1_REFERENCE_AUDIT=BLOCKED unsafe_extraction_allowed")
		return

	print("BASE05_1_COMBAT_BINDING=PASS visual=katana_lian_wu kit=serene_katana owner=BuildProfile_fallback")
	print("BASE05_1_MODULAR_LOADOUT_METADATA=PASS id=combat_lian_wu_first_playable runtime_owner=false")
	print("BASE05_1_SOURCE_REVIEW=PASS neutral=partial_hilt combat=partial_hilt standalone=false redraw_required=true")
	print("BASE05_1_RUNTIME=BLOCKED expected=true weapon_main=false creator=false")
	print("BASE05_1_REFERENCE_AUDIT=PASS")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}

func _fail(message: String) -> void:
	push_error(message)
	print(message)
	quit(1)

# Tehkné Solutions
