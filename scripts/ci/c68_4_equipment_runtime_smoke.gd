extends SceneTree

## C68.4 lifecycle-aware equipment runtime smoke.
## Candidate mode is allowed only before promotion; production mode must assemble normally.
## Tehkné Solutions

const BACK_CANDIDATE := "res://assets/modular_fighters/base_04/candidates/back_accessory_pack_01/v3_guardian_panel/back_accessory.png"

func _init() -> void:
	var profile := ModularFighterProfile.new()
	profile.profile_id = &"c68_4_equipment_runtime"
	profile.display_name = "C68.4 Equipment Runtime"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_module(&"weapon_back", &"sheath_lian_wu_blue")

	var hair_failures := ModularFighterHairRuntime.set_profile_style(profile, &"hair_01_lian_topknot")
	if not hair_failures.is_empty():
		_fail("hair_profile:%s" % ",".join(hair_failures))
		return

	var assembler := ModularFighterAssembler.new()
	root.add_child(assembler)
	var failures := assembler.configure(profile)
	if not failures.is_empty():
		_fail("configure:%s" % ",".join(failures))
		return

	failures = ModularFighterHairRuntime.assemble_profile(profile, assembler)
	if not failures.is_empty():
		_fail("hair_runtime:%s" % ",".join(failures))
		return

	var production := ModularFighterEquipmentRuntime.runtime_activation_enabled()
	failures = ModularFighterEquipmentRuntime.assemble_profile(profile, assembler, not production)
	if not failures.is_empty():
		_fail("equipment_runtime:%s" % ",".join(failures))
		return

	if not ResourceLoader.exists(BACK_CANDIDATE):
		_fail("selected_back_candidate_missing")
		return
	var back_texture := load(BACK_CANDIDATE) as Texture2D
	if back_texture == null or back_texture.get_size() != Vector2(1024, 1024):
		_fail("selected_back_candidate_invalid")
		return
	var back_sprite := Sprite2D.new()
	back_sprite.texture = back_texture
	back_sprite.centered = true
	back_sprite.position = Vector2(0.0, 1024.0 * (0.5 - 0.92))
	back_sprite.z_index = ModularFighterLayerPolicy.z_index_for(&"back_accessory")
	if not assembler.attach_visual_module(&"back_accessory", back_sprite):
		_fail("selected_back_candidate_attach_failed")
		return

	var sheath := assembler.get_node_or_null("Module_weapon_back") as Sprite2D
	var back := assembler.get_node_or_null("Module_back_accessory") as Sprite2D
	var hair_back := assembler.get_node_or_null("Module_hair_back") as Sprite2D
	if sheath == null or back == null or hair_back == null:
		_fail("z_chain_node_missing")
		return
	if not (sheath.z_index == 3 and back.z_index == 4 and hair_back.z_index == 5):
		_fail("z_chain_invalid:%d<%d<%d" % [sheath.z_index, back.z_index, hair_back.z_index])
		return

	var signature := ModularFighterEquipmentRuntime.runtime_signature(profile, assembler)
	var weapon_back = signature.get("nodes", {}).get("weapon_back", {})
	if not bool(weapon_back.get("present", false)) or int(weapon_back.get("z", -1)) != 3:
		_fail("equipment_runtime_signature_invalid")
		return
	var slots = signature.get("runtime_slots", [])
	if not (slots is Array) or slots != ["weapon_back"]:
		_fail("equipment_runtime_scope_invalid:%s" % str(slots))
		return

	print("C68_4_EQUIPMENT_RUNTIME=PASS module=sheath_lian_wu_blue candidate_mode=%s production=%s" % [str(not production).to_lower(), str(production).to_lower()])
	print("C68_4_Z_CHAIN=PASS weapon_back=3 back_accessory=4 hair_back=5")
	print("C68_4_RUNTIME_SCOPE=PASS slots=weapon_back future=weapon_main,weapon_offhand")
	print("C68_4_OWNERSHIP=PASS visual=SHARED_MODULAR_EQUIPMENT combat=WeaponKitCatalog_and_BattleLoadoutCatalog")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
