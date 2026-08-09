extends SceneTree

const MANIFEST_PATH := "res://assets/modular_fighters/base_02/manifest.json"
const CONTRACT_PATH := "res://assets/modular_fighters/base_02/production/BASE02_HAIR_FOUNDATION.json"
const STANDARD_PATH := "res://config/modular-fighter-standard-v1.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := PackedStringArray()
	var manifest := _load_json(MANIFEST_PATH)
	var contract := _load_json(CONTRACT_PATH)
	var standard := _load_json(STANDARD_PATH)

	if String(manifest.get("pack_id", "")) != "BASE02_HAIR":
		failures.append("base02_manifest_missing")
	if String(manifest.get("default_style_id", "")) != "hair_none":
		failures.append("base02_default_style")
	var styles = manifest.get("styles", {})
	if not (styles is Dictionary) or not styles.has("hair_none"):
		failures.append("base02_hair_none_missing")
	else:
		var none_style = styles["hair_none"]
		if not (none_style is Dictionary):
			failures.append("base02_hair_none_invalid")
		else:
			if none_style.get("hair_back", "invalid") != null or none_style.get("hair_front", "invalid") != null:
				failures.append("base02_hair_none_must_be_empty")
			if not bool(none_style.get("production_ready", false)):
				failures.append("base02_hair_none_not_ready")

	var status := String(manifest.get("status", ""))
	var modules = manifest.get("modules", {})
	var promotion = manifest.get("promotion", {})
	if not (modules is Dictionary):
		failures.append("base02_modules_invalid")
	if not (promotion is Dictionary):
		failures.append("base02_promotion_contract")
	elif status == "foundation_no_art_assets":
		# Original C66.0 state: before any canonical Hair pack exists.
		if not modules.is_empty():
			failures.append("base02_foundation_must_not_claim_art_modules")
		if bool(promotion.get("art_assets_present", true)):
			failures.append("base02_foundation_art_assets_must_be_false")
		if bool(promotion.get("battle_activation", true)):
			failures.append("base02_foundation_battle_activation_must_be_false")
	else:
		# Once C66.1+ promotes real art, this gate keeps validating the foundation
		# invariants instead of permanently demanding an empty pack.
		if modules.is_empty():
			failures.append("base02_promoted_pack_modules_missing")
		if not bool(promotion.get("art_assets_present", false)):
			failures.append("base02_promoted_pack_art_assets_false")

	# The immutable C66.0 production record still documents the original
	# foundation checkpoint; later packs supersede its promotion blocker without
	# rewriting that historical evidence.
	if String(contract.get("component_id", "")) != "BASE02_HAIR_FOUNDATION":
		failures.append("base02_contract_missing")
	if String(contract.get("stage", "")) != "C66.0":
		failures.append("base02_contract_stage")
	var style_contract = contract.get("style_contract", {})
	if not (style_contract is Dictionary):
		failures.append("base02_style_contract_missing")
	else:
		if String(style_contract.get("creator_selection_unit", "")) != "hair_style":
			failures.append("base02_atomic_style_unit")
		var atomic_slots = style_contract.get("atomic_pair_slots", [])
		if not (atomic_slots is Array) or atomic_slots != ["hair_back", "hair_front"]:
			failures.append("base02_atomic_pair_slots")
		if bool(style_contract.get("cross_style_mixing", true)):
			failures.append("base02_cross_style_mixing")

	var slots = standard.get("slots", [])
	var creator_slots = standard.get("creator_v1_editable_slots", [])
	if not (slots is Array) or not slots.has("hair_back") or not slots.has("hair_front"):
		failures.append("standard_hair_slots_missing")
	if not (creator_slots is Array) or not creator_slots.has("hair_back") or not creator_slots.has("hair_front"):
		failures.append("creator_standard_hair_slots_missing")

	if not ModularFighterLayerPolicy.hair_order_is_valid():
		failures.append("hair_layer_order_invalid")
	var signature := ModularFighterLayerPolicy.contract_signature()
	if int(signature.get("hair_back", 999)) != 5:
		failures.append("hair_back_z_invalid")
	if int(signature.get("hair_front", -1)) != 50:
		failures.append("hair_front_z_invalid")
	if int(signature.get("head_accessory", -1)) != 60:
		failures.append("head_accessory_z_invalid")

	var profile := ModularFighterProfile.new()
	profile.profile_id = &"c66_hair_foundation_probe"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_module(&"hair_back", &"future_hair_back_probe")
	profile.set_module(&"hair_front", &"future_hair_front_probe")
	var profile_failures := profile.validate_against_standard()
	if not profile_failures.is_empty():
		failures.append("profile_rejects_standard_hair_slots:%s" % ",".join(profile_failures))
	profile.clear_module(&"hair_back")
	profile.clear_module(&"hair_front")
	if profile.module_id(&"hair_back") != &"" or profile.module_id(&"hair_front") != &"":
		failures.append("profile_hair_clear_failed")

	if not failures.is_empty():
		for failure in failures:
			push_error("C66_0_HAIR_FOUNDATION=BLOCKED %s" % failure)
		quit(2)
		return

	print("C66_0_HAIR_FOUNDATION=PASS")
	print("C66_0_FOUNDATION_INVARIANTS=PASS manifest_status=%s" % status)
	print("C66_0_HAIR_SLOTS=PASS back=hair_back front=hair_front")
	print("C66_0_HAIR_LAYER_ORDER=PASS back=5 body=10 face_plate=15 face=20 eyes=30 brows=40 front=50 head_accessory=60")
	print("C66_0_PROFILE_STORAGE=PASS generic_modules=true")
	if status == "foundation_no_art_assets":
		print("C66_0_ART_STAGE=FOUNDATION_BLOCKED")
	else:
		print("C66_0_ART_STAGE=SUPERSEDED_BY_PROMOTED_PACK")
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
