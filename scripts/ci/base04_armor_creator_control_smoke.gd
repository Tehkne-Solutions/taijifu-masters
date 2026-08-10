extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const TEST_PRESET := &"c68_2_armor_creator_probe"
const ARMOR_NONE := &"armor_none"
const ARMOR_GUARD := &"armor_01_taijifu_guard"
const HAIR_TOPKNOT := &"hair_01_lian_topknot"
const UNIFORM_LIAN := &"uniform_01_lian_martial"

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
	FirstPlayableSession.set_participant_code("TJFP-001")

	if not ModularFighterArmorRuntime.creator_exposure_enabled():
		_fail("C68_2_CREATOR=BLOCKED manifest_exposure_false")
		return
	if ModularFighterArmorRuntime.back_accessory_creator_exposure_enabled():
		_fail("C68_2_CREATOR=BLOCKED back_accessory_exposed")
		return
	var creator_sets := ModularFighterArmorRuntime.creator_armor_set_ids()
	if creator_sets != PackedStringArray(["armor_none", "armor_01_taijifu_guard"]):
		_fail("C68_2_CREATOR=BLOCKED production_set_filter:%s" % str(creator_sets))
		return

	var packed := load(CREATOR_SCENE) as PackedScene
	var creator := packed.instantiate() as ModularFighterCreatorScene if packed != null else null
	if creator == null:
		_fail("C68_2_CREATOR=BLOCKED instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(10):
		await process_frame

	var option := creator.armor_set_option()
	if option == null or option.name != "ArmorSetOption":
		_fail("C68_2_CREATOR=BLOCKED option_missing")
		return
	if option.item_count != 2 or option.disabled:
		_fail("C68_2_CREATOR=BLOCKED option_count")
		return
	if creator.current_armor_set_id() != ARMOR_NONE or creator.current_back_accessory_id() != &"back_none":
		_fail("C68_2_CREATOR=BLOCKED default_state")
		return
	for forbidden_name in ["HeadAccessoryOption", "ShouldersOption", "BackAccessoryOption"]:
		if creator.get_node_or_null(forbidden_name) != null:
			_fail("C68_2_CREATOR=BLOCKED direct_slot_control:%s" % forbidden_name)
			return

	var none_index := -1
	var guard_index := -1
	for index in range(option.item_count):
		var set_id := String(option.get_item_metadata(index))
		if set_id == String(ARMOR_NONE):
			none_index = index
			if option.get_item_text(index) != "Sem armadura externa":
				_fail("C68_2_CREATOR=BLOCKED none_label")
				return
		elif set_id == String(ARMOR_GUARD):
			guard_index = index
			if option.get_item_text(index) != "Guarda Marcial Taijifu":
				_fail("C68_2_CREATOR=BLOCKED guard_label")
				return
	if none_index != 0 or guard_index != 1:
		_fail("C68_2_CREATOR=BLOCKED option_order")
		return

	# Preserve all previously promoted public packs while selecting Armor.
	var failures := creator.set_hair_style(HAIR_TOPKNOT)
	failures.append_array(creator.set_uniform_set(UNIFORM_LIAN))
	if not failures.is_empty():
		_fail("C68_2_CREATOR=BLOCKED prior_pack_setup:%s" % ",".join(failures))
		return
	for _frame in range(4):
		await process_frame

	# Exercise the real public UI path instead of calling the runtime directly.
	option.select(guard_index)
	option.item_selected.emit(guard_index)
	for _frame in range(5):
		await process_frame
	if creator.current_armor_set_id() != ARMOR_GUARD:
		_fail("C68_2_CREATOR=BLOCKED ui_selection")
		return
	if creator.current_back_accessory_id() != &"back_none":
		_fail("C68_2_CREATOR=BLOCKED back_default_regression")
		return
	if creator.current_hair_style_id() != HAIR_TOPKNOT or creator.current_uniform_set_id() != UNIFORM_LIAN:
		_fail("C68_2_CREATOR=BLOCKED prior_pack_regression")
		return

	var profile := creator.current_profile()
	if not ModularFighterArmorRuntime.validate_profile(profile).is_empty():
		_fail("C68_2_CREATOR=BLOCKED atomic_profile")
		return
	if String(profile.module_id(&"head_accessory")) != "armor_01_taijifu_guard_head_accessory":
		_fail("C68_2_CREATOR=BLOCKED profile_head")
		return
	if String(profile.module_id(&"shoulders")) != "armor_01_taijifu_guard_shoulders":
		_fail("C68_2_CREATOR=BLOCKED profile_shoulders")
		return
	if profile.module_id(&"back_accessory") != &"":
		_fail("C68_2_CREATOR=BLOCKED profile_back")
		return

	var preview := creator.current_assembler()
	var head := preview.get_node_or_null("Module_head_accessory") as Sprite2D
	var shoulders := preview.get_node_or_null("Module_shoulders") as Sprite2D
	if head == null or head.z_index != 60:
		_fail("C68_2_CREATOR=BLOCKED preview_head")
		return
	if shoulders == null or shoulders.z_index != 70:
		_fail("C68_2_CREATOR=BLOCKED preview_shoulders")
		return
	if preview.get_node_or_null("Module_back_accessory") != null:
		_fail("C68_2_CREATOR=BLOCKED preview_back")
		return
	if preview.get_node_or_null("Module_hair_back") == null or preview.get_node_or_null("Module_hair_front") == null:
		_fail("C68_2_CREATOR=BLOCKED preview_hair")
		return
	if preview.get_node_or_null("Module_torso_outer") == null:
		_fail("C68_2_CREATOR=BLOCKED preview_uniform")
		return

	creator.set_display_name("C68 ARMOR CREATOR")
	creator.set_preset_id(String(TEST_PRESET))
	failures = creator.save_current_preset(TEST_PRESET)
	if not failures.is_empty() or FirstPlayableSession.creator_preset_id() != TEST_PRESET:
		_fail("C68_2_CREATOR=BLOCKED save_handoff")
		return

	# Prove none clears both armor modules only, then reload exact saved state.
	failures = creator.set_armor_set(ARMOR_NONE)
	if not failures.is_empty():
		_fail("C68_2_CREATOR=BLOCKED switch_none")
		return
	for _frame in range(3):
		await process_frame
	if preview.get_node_or_null("Module_head_accessory") != null or preview.get_node_or_null("Module_shoulders") != null:
		_fail("C68_2_CREATOR=BLOCKED none_preview")
		return
	if creator.current_hair_style_id() != HAIR_TOPKNOT or creator.current_uniform_set_id() != UNIFORM_LIAN:
		_fail("C68_2_CREATOR=BLOCKED none_prior_pack_regression")
		return

	failures = creator.load_user_preset(TEST_PRESET)
	if not failures.is_empty():
		_fail("C68_2_CREATOR=BLOCKED load:%s" % ",".join(failures))
		return
	for _frame in range(5):
		await process_frame
	if creator.current_armor_set_id() != ARMOR_GUARD or creator.current_back_accessory_id() != &"back_none":
		_fail("C68_2_CREATOR=BLOCKED load_armor_roundtrip")
		return
	if creator.current_hair_style_id() != HAIR_TOPKNOT or creator.current_uniform_set_id() != UNIFORM_LIAN:
		_fail("C68_2_CREATOR=BLOCKED load_cross_pack_roundtrip")
		return
	preview = creator.current_assembler()
	head = preview.get_node_or_null("Module_head_accessory") as Sprite2D
	shoulders = preview.get_node_or_null("Module_shoulders") as Sprite2D
	if head == null or head.z_index != 60 or shoulders == null or shoulders.z_index != 70:
		_fail("C68_2_CREATOR=BLOCKED load_preview")
		return

	var signature := creator.armor_creator_signature()
	if bool(signature.get("direct_slot_controls", true)) or bool(signature.get("cross_set_piece_mixing", true)):
		_fail("C68_2_CREATOR=BLOCKED public_contract")
		return
	if bool(signature.get("back_accessory_control_exposed", true)):
		_fail("C68_2_CREATOR=BLOCKED back_public_contract")
		return
	if not bool(signature.get("live_preview", false)) or not bool(signature.get("selection_transactional", false)) or not bool(signature.get("preset_roundtrip", false)):
		_fail("C68_2_CREATOR=BLOCKED signature_flow")
		return
	var flow := creator.flow_signature()
	if not bool(flow.get("armor_creator_control", false)) or String(flow.get("armor_selection_unit", "")) != "armor_set":
		_fail("C68_2_CREATOR=BLOCKED flow_signature")
		return
	if bool(flow.get("armor_direct_slot_controls", true)) or bool(flow.get("armor_cross_set_piece_mixing", true)):
		_fail("C68_2_CREATOR=BLOCKED flow_piece_controls")
		return
	if bool(flow.get("back_accessory_creator_control", true)) or int(flow.get("armor_set_count", 0)) != 2:
		_fail("C68_2_CREATOR=BLOCKED flow_catalog")
		return

	creator.queue_free()
	await process_frame

	# Saved Creator preset must reach battle with the exact cross-pack composition.
	var battle_packed := load(BATTLE_SCENE) as PackedScene
	var battle := battle_packed.instantiate() as FirstPlayableController if battle_packed != null else null
	if battle == null:
		_fail("C68_2_CREATOR=BLOCKED battle_instantiate")
		return
	get_root().add_child(battle)
	for _frame in range(32):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("C68_2_CREATOR=BLOCKED battle_player")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("C68_2_CREATOR=BLOCKED battle_presenter")
		return
	if presenter.active_hair_style_id() != HAIR_TOPKNOT or presenter.active_uniform_set_id() != UNIFORM_LIAN:
		_fail("C68_2_CREATOR=BLOCKED battle_prior_pack_state")
		return
	if presenter.active_armor_set_id() != ARMOR_GUARD or presenter.active_back_accessory_id() != &"back_none":
		_fail("C68_2_CREATOR=BLOCKED battle_armor_state")
		return
	var handoff = battle.player_one.get_meta("creator_battle_handoff", {})
	if not (handoff is Dictionary):
		_fail("C68_2_CREATOR=BLOCKED battle_handoff_missing")
		return
	if String(handoff.get("hair_style_id", "")) != String(HAIR_TOPKNOT) or String(handoff.get("uniform_set_id", "")) != String(UNIFORM_LIAN):
		_fail("C68_2_CREATOR=BLOCKED battle_handoff_prior_packs")
		return
	if String(handoff.get("armor_set_id", "")) != String(ARMOR_GUARD) or String(handoff.get("back_accessory_id", "")) != "back_none":
		_fail("C68_2_CREATOR=BLOCKED battle_handoff_armor")
		return

	print("C68_2_ARMOR_CONTROL=PASS options=2 unit=armor_set")
	print("C68_2_DIRECT_SLOT_CONTROLS=ABSENT armor_slots=2 back_control=false")
	print("C68_2_LIVE_PREVIEW=PASS head_z=60 shoulders_z=70 hair_preserved=true uniform_preserved=true")
	print("C68_2_PRESET_ROUNDTRIP=PASS schema=v2 atomic_set=true back=back_none")
	print("C68_2_BATTLE_HANDOFF=PASS armor=armor_01_taijifu_guard back=back_none hair=hair_01_lian_topknot uniform=uniform_01_lian_martial")
	print("C68_2_ARMOR_CREATOR_CONTROL=PASS")
	print("SIGNATURE=Tehkné Solutions")

	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

# Tehkné Solutions
