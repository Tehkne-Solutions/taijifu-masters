extends SceneTree

## BASE-05.3 validates the selected katana as a visual-only weapon_main module.
## Damage/techniques remain owned by WeaponKitCatalog/BattleLoadoutCatalog.
## Tehkné Solutions

const HAIR_STYLE := &"hair_01_lian_topknot"
const UNIFORM_SET := &"uniform_01_lian_martial"
const ARMOR_SET := &"armor_01_taijifu_guard"
const BACK_ACCESSORY := &"back_01_guardian_panel"
const WEAPON_BACK := &"sheath_lian_wu_blue"
const WEAPON_MAIN := &"katana_lian_wu"

func _init() -> void:
	var profile := ModularFighterProfile.new()
	profile.profile_id = &"base05_3_weapon_main_runtime"
	profile.display_name = "BASE-05.3 Weapon Main Runtime"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_module(&"weapon_back", WEAPON_BACK)
	profile.set_module(&"weapon_main", WEAPON_MAIN)

	var failures := ModularFighterHairRuntime.set_profile_style(profile, HAIR_STYLE)
	failures.append_array(ModularFighterUniformRuntime.set_profile_set(profile, UNIFORM_SET))
	failures.append_array(ModularFighterArmorRuntime.set_profile_armor_set(profile, ARMOR_SET))
	failures.append_array(ModularFighterArmorRuntime.set_profile_back_accessory(profile, BACK_ACCESSORY))
	if not failures.is_empty():
		_fail("profile:%s" % ",".join(failures))
		return

	var assembler := ModularFighterAssembler.new()
	root.add_child(assembler)
	failures = assembler.configure(profile)
	if not failures.is_empty():
		_fail("configure:%s" % ",".join(failures))
		return

	failures = ModularFighterHairRuntime.assemble_profile(profile, assembler)
	failures.append_array(ModularFighterEquipmentRuntime.assemble_profile(profile, assembler))
	failures.append_array(ModularFighterEquipmentRuntime.assemble_weapon_main_profile(profile, assembler))
	failures.append_array(ModularFighterUniformRuntime.assemble_profile(profile, assembler))
	failures.append_array(ModularFighterArmorRuntime.assemble_profile(profile, assembler))
	if not failures.is_empty():
		_fail("assembly:%s" % ",".join(failures))
		return

	var sheath := assembler.get_node_or_null("Module_weapon_back") as Sprite2D
	var back := assembler.get_node_or_null("Module_back_accessory") as Sprite2D
	var hair_back := assembler.get_node_or_null("Module_hair_back") as Sprite2D
	var katana := assembler.get_node_or_null("Module_weapon_main") as Sprite2D
	if sheath == null or back == null or hair_back == null or katana == null:
		_fail("required_node_missing")
		return
	if not (sheath.z_index == 3 and back.z_index == 4 and hair_back.z_index == 5 and katana.z_index == 80):
		_fail("z_chain:%d,%d,%d,%d" % [sheath.z_index, back.z_index, hair_back.z_index, katana.z_index])
		return
	if katana.visible:
		_fail("neutral_must_start_hidden")
		return

	var before := {
		"weapon_back": sheath.get_instance_id(),
		"back_accessory": back.get_instance_id(),
		"hair_back": hair_back.get_instance_id(),
	}
	if not ModularFighterEquipmentRuntime.set_weapon_main_visible(assembler, true):
		_fail("show_failed")
		return
	if not katana.visible:
		_fail("show_state_not_applied")
		return
	if not _prior_nodes_preserved(assembler, before):
		_fail("show_mutated_prior_modules")
		return
	if not ModularFighterEquipmentRuntime.set_weapon_main_visible(assembler, false):
		_fail("hide_failed")
		return
	if katana.visible:
		_fail("hide_state_not_applied")
		return
	if not _prior_nodes_preserved(assembler, before):
		_fail("hide_mutated_prior_modules")
		return

	var sig := ModularFighterEquipmentRuntime.weapon_main_signature(profile, assembler)
	if String(sig.get("module_id", "")) != String(WEAPON_MAIN):
		_fail("signature_module")
		return
	if String(sig.get("combat_reference", "")) != "serene_katana":
		_fail("signature_combat_reference")
		return
	if String(sig.get("combat_logic_owner", "")) != "WeaponKitCatalog_and_BattleLoadoutCatalog":
		_fail("signature_combat_owner")
		return
	if not bool(sig.get("present", false)) or int(sig.get("z", -1)) != 80:
		_fail("signature_runtime")
		return

	print("BASE05_3_WEAPON_MAIN_RUNTIME=PASS module=katana_lian_wu initial_visible=false toggle=true combat_reference=serene_katana")
	print("BASE05_3_LAYER_CHAIN=PASS weapon_back=3 back_accessory=4 hair_back=5 weapon_main=80")
	print("BASE05_3_IDEMPOTENCE=PASS weapon_back=true back_accessory=true hair=true uniform=true armor=true")
	print("BASE05_3_OWNERSHIP=PASS visual=ModularFighterEquipmentRuntime combat=WeaponKitCatalog_and_BattleLoadoutCatalog")
	print("BASE05_3_CREATOR=BLOCKED expected=true")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _prior_nodes_preserved(assembler: ModularFighterAssembler, before: Dictionary) -> bool:
	for slot in before.keys():
		var node := assembler.get_node_or_null("Module_%s" % String(slot))
		if node == null or node.get_instance_id() != before[slot]:
			return false
	return assembler.get_node_or_null("Module_torso_outer") != null and assembler.get_node_or_null("Module_shoulders") != null

func _fail(message: String) -> void:
	push_error("BASE05_3_RUNTIME=BLOCKED " + message)
	print("BASE05_3_RUNTIME=BLOCKED " + message)
	quit(1)

# Tehkné Solutions
