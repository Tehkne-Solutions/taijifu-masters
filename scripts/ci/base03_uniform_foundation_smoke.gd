extends SceneTree

const MANIFEST_PATH := "res://assets/modular_fighters/base_03/manifest.json"
const CONTRACT_PATH := "res://assets/modular_fighters/base_03/production/BASE03_UNIFORM_FOUNDATION.json"
const STANDARD_PATH := "res://config/modular-fighter-standard-v1.json"
const UNIFORM_SLOTS := [
	&"torso_inner", &"torso_outer", &"arms", &"hands", &"waist", &"legs", &"feet"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := PackedStringArray()
	var manifest := _load_json(MANIFEST_PATH)
	var contract := _load_json(CONTRACT_PATH)
	var standard := _load_json(STANDARD_PATH)

	if String(manifest.get("pack_id", "")) != "BASE03_MARTIAL_ARTS_UNIFORMS":
		failures.append("base03_manifest_missing")
	if String(manifest.get("status", "")) != "foundation_no_art_assets":
		failures.append("base03_foundation_status")
	if String(manifest.get("default_set_id", "")) != "uniform_none":
		failures.append("base03_default_set")
	var modules = manifest.get("modules", {})
	if not (modules is Dictionary) or not modules.is_empty():
		failures.append("base03_foundation_must_not_claim_art_modules")
	var sets = manifest.get("sets", {})
	if not (sets is Dictionary) or not sets.has("uniform_none"):
		failures.append("base03_uniform_none_missing")
	else:
		var none_set = sets["uniform_none"]
		if not (none_set is Dictionary):
			failures.append("base03_uniform_none_invalid")
		else:
			for slot in UNIFORM_SLOTS:
				if none_set.get(String(slot), "invalid") != null:
					failures.append("base03_uniform_none_slot_not_empty:%s" % String(slot))
			if not bool(none_set.get("production_ready", false)):
				failures.append("base03_uniform_none_not_ready")

	var promotion = manifest.get("promotion", {})
	if not (promotion is Dictionary):
		failures.append("base03_promotion_contract")
	else:
		if bool(promotion.get("art_assets_present", true)):
			failures.append("base03_art_assets_must_be_false")
		if bool(promotion.get("creator_exposure", true)):
			failures.append("base03_creator_exposure_must_be_false")
		if bool(promotion.get("battle_activation", true)):
			failures.append("base03_battle_activation_must_be_false")

	if String(contract.get("component_id", "")) != "BASE03_UNIFORM_FOUNDATION":
		failures.append("base03_contract_missing")
	if String(contract.get("status", "")) != "foundation_candidate_art_blocked":
		failures.append("base03_contract_status")
	var set_contract = contract.get("set_contract", {})
	if not (set_contract is Dictionary):
		failures.append("base03_set_contract_missing")
	else:
		if String(set_contract.get("public_selection_unit", "")) != "uniform_set":
			failures.append("base03_selection_unit")
		var atomic_slots = set_contract.get("atomic_slots", [])
		if not (atomic_slots is Array) or atomic_slots != ["torso_inner", "torso_outer", "arms", "hands", "waist", "legs", "feet"]:
			failures.append("base03_atomic_slots")
		if bool(set_contract.get("direct_piece_controls", true)):
			failures.append("base03_direct_piece_controls")
		if bool(set_contract.get("cross_set_piece_mixing", true)):
			failures.append("base03_cross_set_piece_mixing")

	var standard_slots = standard.get("slots", [])
	var creator_slots = standard.get("creator_v1_editable_slots", [])
	for slot in UNIFORM_SLOTS:
		if not (standard_slots is Array) or not standard_slots.has(String(slot)):
			failures.append("standard_uniform_slot_missing:%s" % String(slot))
		if not (creator_slots is Array) or not creator_slots.has(String(slot)):
			failures.append("creator_standard_uniform_slot_missing:%s" % String(slot))

	var expected_z := {
		"torso_inner": 11,
		"legs": 11,
		"feet": 12,
		"arms": 12,
		"hands": 13,
		"waist": 14,
		"torso_outer": 65,
	}
	for slot_name in expected_z.keys():
		var resolved := ModularFighterLayerPolicy.z_index_for(StringName(slot_name))
		if resolved != int(expected_z[slot_name]):
			failures.append("uniform_layer_policy_mismatch:%s:%d" % [slot_name, resolved])

	# Existing profile schema already owns all required slots and can clear them.
	var profile := ModularFighterProfile.new()
	profile.profile_id = &"c67_uniform_foundation_probe"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	for slot in UNIFORM_SLOTS:
		profile.set_module(slot, StringName("future_%s_probe" % String(slot)))
	var profile_failures := profile.validate_against_standard()
	if not profile_failures.is_empty():
		failures.append("profile_rejects_uniform_slots:%s" % ",".join(profile_failures))
	for slot in UNIFORM_SLOTS:
		profile.clear_module(slot)
		if profile.module_id(slot) != &"":
			failures.append("profile_uniform_clear_failed:%s" % String(slot))

	if not failures.is_empty():
		for failure in failures:
			push_error("C67_0_UNIFORM_FOUNDATION=BLOCKED %s" % failure)
		quit(2)
		return

	print("C67_0_UNIFORM_FOUNDATION=PASS")
	print("C67_0_UNIFORM_SET=PASS unit=uniform_set slots=7 atomic=true")
	print("C67_0_PROFILE_STORAGE=PASS generic_modules=true")
	print("C67_0_LAYER_POLICY=PASS current_policy_frozen=true hair_visual_review_required=true")
	print("C67_0_ART_PROMOTION=BLOCKED reason=first_canonical_uniform_art_pack_missing")
	print("C67_0_CREATOR_EXPOSURE=BLOCKED")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

# Tehkné Solutions
