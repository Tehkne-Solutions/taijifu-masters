extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const TEST_PRESET := &"c68_5_back_accessory_creator_probe"
const BACK_NONE := &"back_none"
const BACK_GUARDIAN := &"back_01_guardian_panel"
const HAIR_TOPKNOT := &"hair_01_lian_topknot"
const UNIFORM_LIAN := &"uniform_01_lian_martial"
const ARMOR_GUARD := &"armor_01_taijifu_guard"
const WEAPON_BACK := &"sheath_lian_wu_blue"

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	print(message)
	_cleanup()
	FirstPlayableSession.reset()
	quit(2)

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-C68-5")

	if not ModularFighterArmorRuntime.back_accessory_creator_exposure_enabled():
		_fail("C68_5_CREATOR=BLOCKED manifest_exposure_false")
		return
	var creator_items := ModularFighterArmorRuntime.creator_back_accessory_ids()
	if creator_items != PackedStringArray(["back_none", "back_01_guardian_panel"]):
		_fail("C68_5_CREATOR=BLOCKED production_filter:%s" % str(creator_items))
		return

	var packed := load(CREATOR_SCENE) as PackedScene
	var creator := packed.instantiate() as ModularFighterCreatorScene if packed != null else null
	if creator == null:
		_fail("C68_5_CREATOR=BLOCKED instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(10):
		await process_frame

	var option := creator.back_accessory_option()
	if option == null or option.name != "BackAccessoryOption":
		_fail("C68_5_CREATOR=BLOCKED option_missing")
		return
	if option.item_count != 2 or option.disabled:
		_fail("C68_5_CREATOR=BLOCKED option_count")
		return
	for forbidden_name in ["HeadAccessoryOption", "ShouldersOption", "WeaponBackOption", "WeaponMainOption", "WeaponOffhandOption"]:
		if creator.get_node_or_null(forbidden_name) != null:
			_fail("C68_5_CREATOR=BLOCKED forbidden_control:%s" % forbidden_name)
			return

	var none_index := -1
	var guardian_index := -1
	for index in range(option.item_count):
		var item_id := String(option.get_item_metadata(index))
		if item_id == String(BACK_NONE):
			none_index = index
			if option.get_item_text(index) != "Sem acessório de costas":
				_fail("C68_5_CREATOR=BLOCKED none_label")
				return
		elif item_id == String(BACK_GUARDIAN):
			guardian_index = index
			if option.get_item_text(index) != "Painel Guardião":
				_fail("C68_5_CREATOR=BLOCKED guardian_label")
				return
	if none_index != 0 or guardian_index != 1:
		_fail("C68_5_CREATOR=BLOCKED option_order")
		return

	var failures := creator.set_hair_style(HAIR_TOPKNOT)
	failures.append_array(creator.set_uniform_set(UNIFORM_LIAN))
	failures.append_array(creator.set_armor_set(ARMOR_GUARD))
	if not failures.is_empty():
		_fail("C68_5_CREATOR=BLOCKED prior_pack_setup:%s" % ",".join(failures))
		return
	var profile := creator.current_profile()
	profile.set_module(&"weapon_back", WEAPON_BACK)
	failures = ModularFighterEquipmentRuntime.assemble_profile(profile, creator.current_assembler())
	if not failures.is_empty():
		_fail("C68_5_CREATOR=BLOCKED weapon_back_setup:%s" % ",".join(failures))
		return
	for _frame in range(4):
		await process_frame

	# Exercise the real public OptionButton path.
	option.select(guardian_index)
	option.item_selected.emit(guardian_index)
	for _frame in range(5):
		await process_frame
	if creator.current_back_accessory_id() != BACK_GUARDIAN:
		_fail("C68_5_CREATOR=BLOCKED ui_selection")
		return
	if profile.module_id(&"weapon_back") != WEAPON_BACK:
		_fail("C68_5_CREATOR=BLOCKED weapon_back_mutated")
		return
	if creator.current_hair_style_id() != HAIR_TOPKNOT or creator.current_uniform_set_id() != UNIFORM_LIAN or creator.current_armor_set_id() != ARMOR_GUARD:
		_fail("C68_5_CREATOR=BLOCKED cross_pack_regression")
		return

	var preview := creator.current_assembler()
	var weapon := preview.get_node_or_null("Module_weapon_back") as Sprite2D
	var back := preview.get_node_or_null("Module_back_accessory") as Sprite2D
	var hair_back := preview.get_node_or_null("Module_hair_back") as Sprite2D
	var head := preview.get_node_or_null("Module_head_accessory") as Sprite2D
	var shoulders := preview.get_node_or_null("Module_shoulders") as Sprite2D
	if weapon == null or weapon.z_index != 3 or back == null or back.z_index != 4 or hair_back == null or hair_back.z_index != 5:
		_fail("C68_5_CREATOR=BLOCKED preview_z_chain")
		return
	if head == null or head.z_index != 60 or shoulders == null or shoulders.z_index != 70 or preview.get_node_or_null("Module_torso_outer") == null:
		_fail("C68_5_CREATOR=BLOCKED preview_cross_pack")
		return

	# none clears only z4; z3 must survive.
	option.select(none_index)
	option.item_selected.emit(none_index)
	for _frame in range(4):
		await process_frame
	if creator.current_back_accessory_id() != BACK_NONE or preview.get_node_or_null("Module_back_accessory") != null:
		_fail("C68_5_CREATOR=BLOCKED none_clear")
		return
	if profile.module_id(&"weapon_back") != WEAPON_BACK or preview.get_node_or_null("Module_weapon_back") == null:
		_fail("C68_5_CREATOR=BLOCKED none_weapon_back_regression")
		return

	# Re-select and persist the exact composition.
	option.select(guardian_index)
	option.item_selected.emit(guardian_index)
	for _frame in range(4):
		await process_frame
	creator.set_display_name("C68 BACK ACCESSORY")
	creator.set_preset_id(String(TEST_PRESET))
	failures = creator.save_current_preset(TEST_PRESET)
	if not failures.is_empty() or FirstPlayableSession.creator_preset_id() != TEST_PRESET:
		_fail("C68_5_CREATOR=BLOCKED save_handoff")
		return

	failures = creator.set_back_accessory(BACK_NONE)
	if not failures.is_empty():
		_fail("C68_5_CREATOR=BLOCKED switch_none_before_load")
		return
	failures = creator.load_user_preset(TEST_PRESET)
	if not failures.is_empty():
		_fail("C68_5_CREATOR=BLOCKED load:%s" % ",".join(failures))
		return
	for _frame in range(8):
		await process_frame
	profile = creator.current_profile()
	if creator.current_back_accessory_id() != BACK_GUARDIAN or profile.module_id(&"weapon_back") != WEAPON_BACK:
		_fail("C68_5_CREATOR=BLOCKED preset_roundtrip")
		return
	if creator.current_hair_style_id() != HAIR_TOPKNOT or creator.current_uniform_set_id() != UNIFORM_LIAN or creator.current_armor_set_id() != ARMOR_GUARD:
		_fail("C68_5_CREATOR=BLOCKED preset_cross_pack_roundtrip")
		return

	var signature := creator.back_accessory_creator_signature()
	if bool(signature.get("weapon_back_creator_control", true)) or int((signature.get("production_options", []) as Array).size()) != 2:
		_fail("C68_5_CREATOR=BLOCKED public_signature")
		return
	var flow := creator.flow_signature()
	if not bool(flow.get("back_accessory_creator_control", false)) or bool(flow.get("weapon_back_creator_control", true)) or int(flow.get("back_accessory_count", 0)) != 2:
		_fail("C68_5_CREATOR=BLOCKED flow_signature")
		return

	creator.queue_free()
	await process_frame

	# Saved preset must reach the actual battle through the existing C68.4 presenter.
	var battle_packed := load(BATTLE_SCENE) as PackedScene
	var battle := battle_packed.instantiate() as FirstPlayableController if battle_packed != null else null
	if battle == null:
		_fail("C68_5_CREATOR=BLOCKED battle_instantiate")
		return
	get_root().add_child(battle)
	for _frame in range(40):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("C68_5_CREATOR=BLOCKED battle_player")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("C68_5_CREATOR=BLOCKED battle_presenter")
		return
	if presenter.active_back_accessory_id() != BACK_GUARDIAN or presenter.active_weapon_back_id() != WEAPON_BACK:
		_fail("C68_5_CREATOR=BLOCKED battle_back_weapon_state")
		return
	if presenter.active_hair_style_id() != HAIR_TOPKNOT or presenter.active_uniform_set_id() != UNIFORM_LIAN or presenter.active_armor_set_id() != ARMOR_GUARD:
		_fail("C68_5_CREATOR=BLOCKED battle_cross_pack_state")
		return
	var handoff_value = battle.player_one.get_meta("creator_battle_handoff", {})
	if not (handoff_value is Dictionary):
		_fail("C68_5_CREATOR=BLOCKED battle_handoff")
		return
	var handoff := handoff_value as Dictionary
	if String(handoff.get("back_accessory_id", "")) != String(BACK_GUARDIAN) or String(handoff.get("weapon_back_id", "")) != String(WEAPON_BACK):
		_fail("C68_5_CREATOR=BLOCKED battle_handoff_equipment")
		return
	var assembler := presenter.assembler()
	var weapon_battle := assembler.get_node_or_null("Module_weapon_back") as Sprite2D
	var back_battle := assembler.get_node_or_null("Module_back_accessory") as Sprite2D
	var hair_battle := assembler.get_node_or_null("Module_hair_back") as Sprite2D
	if weapon_battle == null or weapon_battle.z_index != 3 or back_battle == null or back_battle.z_index != 4 or hair_battle == null or hair_battle.z_index != 5:
		_fail("C68_5_CREATOR=BLOCKED battle_z_chain")
		return

	print("C68_5_BACK_CONTROL=PASS options=2 unit=back_accessory")
	print("C68_5_WEAPON_BACK_CONTROL=ABSENT preserved=sheath_lian_wu_blue")
	print("C68_5_LIVE_PREVIEW=PASS weapon_back=3 back=4 hair_back=5 armor_preserved=true uniform_preserved=true")
	print("C68_5_NONE_TRANSACTION=PASS back_cleared=true weapon_back_preserved=true")
	print("C68_5_PRESET_ROUNDTRIP=PASS schema=v2 back=back_01_guardian_panel weapon_back=sheath_lian_wu_blue")
	print("C68_5_BATTLE_HANDOFF=PASS back=back_01_guardian_panel weapon_back=sheath_lian_wu_blue")
	print("C68_5_BACK_ACCESSORY_CREATOR_CONTROL=PASS")
	print("SIGNATURE=Tehkné Solutions")

	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

# Tehkné Solutions
