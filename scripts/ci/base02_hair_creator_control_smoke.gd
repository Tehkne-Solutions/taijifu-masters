extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const TEST_PRESET := &"c66_2_hair_creator_probe"
const STYLE_NONE := &"hair_none"
const STYLE_TOPKNOT := &"hair_01_lian_topknot"
const BACK_ID := &"hair_01_lian_topknot_back"
const FRONT_ID := &"hair_01_lian_topknot_front"

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

	if not ModularFighterHairRuntime.creator_exposure_enabled():
		_fail("C66_2_CREATOR=BLOCKED manifest_exposure_false")
		return
	var creator_styles := ModularFighterHairRuntime.creator_style_ids()
	if creator_styles != PackedStringArray(["hair_01_lian_topknot", "hair_none"]):
		_fail("C66_2_CREATOR=BLOCKED production_style_filter:%s" % str(creator_styles))
		return

	var packed := load(CREATOR_SCENE) as PackedScene
	var creator := packed.instantiate() as ModularFighterCreatorScene if packed != null else null
	if creator == null:
		_fail("C66_2_CREATOR=BLOCKED instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(6):
		await process_frame

	var option := creator.hair_style_option()
	if option == null or option.name != "HairStyleOption":
		_fail("C66_2_CREATOR=BLOCKED hair_option_missing")
		return
	if option.item_count != 2 or option.disabled:
		_fail("C66_2_CREATOR=BLOCKED hair_option_count")
		return
	if creator.current_hair_style_id() != STYLE_NONE:
		_fail("C66_2_CREATOR=BLOCKED default_not_none")
		return
	if creator.get_node_or_null("HairBackOption") != null or creator.get_node_or_null("HairFrontOption") != null:
		_fail("C66_2_CREATOR=BLOCKED direct_internal_slot_control")
		return

	var topknot_index := -1
	var none_index := -1
	for index in range(option.item_count):
		var style_id := String(option.get_item_metadata(index))
		if style_id == String(STYLE_TOPKNOT):
			topknot_index = index
			if option.get_item_text(index) != "Topknot Lian":
				_fail("C66_2_CREATOR=BLOCKED topknot_label")
				return
		elif style_id == String(STYLE_NONE):
			none_index = index
			if option.get_item_text(index) != "Sem cabelo":
				_fail("C66_2_CREATOR=BLOCKED none_label")
				return
	if topknot_index < 0 or none_index < 0:
		_fail("C66_2_CREATOR=BLOCKED option_metadata")
		return

	# Exercise the actual OptionButton signal path, not only the public helper.
	option.select(topknot_index)
	option.item_selected.emit(topknot_index)
	for _frame in range(3):
		await process_frame
	if creator.current_hair_style_id() != STYLE_TOPKNOT:
		_fail("C66_2_CREATOR=BLOCKED ui_selection")
		return
	var profile := creator.current_profile()
	if profile.module_id(&"hair_back") != BACK_ID or profile.module_id(&"hair_front") != FRONT_ID:
		_fail("C66_2_CREATOR=BLOCKED atomic_profile_pair")
		return
	var preview := creator.current_assembler()
	var back := preview.get_node_or_null("Module_hair_back") as Sprite2D
	var front := preview.get_node_or_null("Module_hair_front") as Sprite2D
	if back == null or front == null or back.z_index != 5 or front.z_index != 50:
		_fail("C66_2_CREATOR=BLOCKED live_preview_layers")
		return

	creator.set_display_name("C66 CREATOR HAIR")
	creator.set_preset_id(String(TEST_PRESET))
	var failures := creator.save_current_preset(TEST_PRESET)
	if not failures.is_empty():
		_fail("C66_2_CREATOR=BLOCKED save:%s" % ",".join(failures))
		return
	if FirstPlayableSession.creator_preset_id() != TEST_PRESET:
		_fail("C66_2_CREATOR=BLOCKED save_handoff")
		return

	# Prove the saved preset owns Hair and reload restores both slots + preview.
	failures = creator.set_hair_style(STYLE_NONE)
	if not failures.is_empty() or creator.current_hair_style_id() != STYLE_NONE:
		_fail("C66_2_CREATOR=BLOCKED switch_none")
		return
	if preview.get_node_or_null("Module_hair_back") != null or preview.get_node_or_null("Module_hair_front") != null:
		_fail("C66_2_CREATOR=BLOCKED none_preview_not_clear")
		return
	failures = creator.load_user_preset(TEST_PRESET)
	if not failures.is_empty():
		_fail("C66_2_CREATOR=BLOCKED load:%s" % ",".join(failures))
		return
	for _frame in range(3):
		await process_frame
	if creator.current_hair_style_id() != STYLE_TOPKNOT:
		_fail("C66_2_CREATOR=BLOCKED load_style_roundtrip")
		return
	profile = creator.current_profile()
	if profile.module_id(&"hair_back") != BACK_ID or profile.module_id(&"hair_front") != FRONT_ID:
		_fail("C66_2_CREATOR=BLOCKED load_pair_roundtrip")
		return
	preview = creator.current_assembler()
	back = preview.get_node_or_null("Module_hair_back") as Sprite2D
	front = preview.get_node_or_null("Module_hair_front") as Sprite2D
	if back == null or front == null:
		_fail("C66_2_CREATOR=BLOCKED load_preview_roundtrip")
		return

	var creator_signature := creator.hair_creator_signature()
	if bool(creator_signature.get("direct_slot_controls", true)):
		_fail("C66_2_CREATOR=BLOCKED signature_direct_slots")
		return
	if not bool(creator_signature.get("live_preview", false)) or not bool(creator_signature.get("preset_roundtrip", false)):
		_fail("C66_2_CREATOR=BLOCKED signature_flow")
		return
	var flow := creator.flow_signature()
	if not bool(flow.get("hair_creator_control", false)) or String(flow.get("hair_selection_unit", "")) != "hair_style":
		_fail("C66_2_CREATOR=BLOCKED flow_signature")
		return
	if int(flow.get("hair_style_count", 0)) != 2:
		_fail("C66_2_CREATOR=BLOCKED flow_style_count")
		return

	creator.queue_free()
	await process_frame

	# Saved/loaded Creator preset must activate the exact Hair style in battle.
	var battle_packed := load(BATTLE_SCENE) as PackedScene
	var battle := battle_packed.instantiate() as FirstPlayableController if battle_packed != null else null
	if battle == null:
		_fail("C66_2_CREATOR=BLOCKED battle_instantiate")
		return
	get_root().add_child(battle)
	for _frame in range(24):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("C66_2_CREATOR=BLOCKED battle_player")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("C66_2_CREATOR=BLOCKED battle_presenter")
		return
	if presenter.active_hair_style_id() != STYLE_TOPKNOT:
		_fail("C66_2_CREATOR=BLOCKED battle_hair_style")
		return
	var handoff = battle.player_one.get_meta("creator_battle_handoff", {})
	if not (handoff is Dictionary) or String(handoff.get("hair_style_id", "")) != String(STYLE_TOPKNOT):
		_fail("C66_2_CREATOR=BLOCKED battle_handoff_style")
		return

	print("C66_2_HAIR_CONTROL=PASS options=2 unit=hair_style")
	print("C66_2_DIRECT_SLOT_CONTROLS=ABSENT")
	print("C66_2_LIVE_PREVIEW=PASS back_z=5 front_z=50")
	print("C66_2_PRESET_ROUNDTRIP=PASS schema=v2")
	print("C66_2_BATTLE_HANDOFF=PASS style=hair_01_lian_topknot")
	print("C66_2_HAIR_CREATOR_CONTROL=PASS")
	print("SIGNATURE=Tehkné Solutions")

	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

# Tehkné Solutions
