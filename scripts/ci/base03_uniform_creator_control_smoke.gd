extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const TEST_PRESET := &"c67_2_uniform_creator_probe"
const SET_NONE := &"uniform_none"
const SET_LIAN := &"uniform_01_lian_martial"
const HAIR_TOPKNOT := &"hair_01_lian_topknot"
const EXPECTED_MODULES := {
	"torso_outer": "uniform_01_lian_martial_torso_outer",
	"arms": "uniform_01_lian_martial_arms",
	"waist": "uniform_01_lian_martial_waist",
	"legs": "uniform_01_lian_martial_legs",
	"feet": "uniform_01_lian_martial_feet",
}
const EXPECTED_Z := {
	"torso_outer": 65,
	"arms": 12,
	"waist": 14,
	"legs": 11,
	"feet": 12,
}

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

	if not ModularFighterUniformRuntime.creator_exposure_enabled():
		_fail("C67_2_CREATOR=BLOCKED manifest_exposure_false")
		return
	var creator_sets := ModularFighterUniformRuntime.creator_set_ids()
	if creator_sets != PackedStringArray(["uniform_none", "uniform_01_lian_martial"]):
		_fail("C67_2_CREATOR=BLOCKED production_set_filter:%s" % str(creator_sets))
		return

	var packed := load(CREATOR_SCENE) as PackedScene
	var creator := packed.instantiate() as ModularFighterCreatorScene if packed != null else null
	if creator == null:
		_fail("C67_2_CREATOR=BLOCKED instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(8):
		await process_frame

	var option := creator.uniform_set_option()
	if option == null or option.name != "UniformSetOption":
		_fail("C67_2_CREATOR=BLOCKED option_missing")
		return
	if option.item_count != 2 or option.disabled:
		_fail("C67_2_CREATOR=BLOCKED option_count")
		return
	if creator.current_uniform_set_id() != SET_NONE:
		_fail("C67_2_CREATOR=BLOCKED default_not_none")
		return
	for forbidden_name in ["TorsoInnerOption", "TorsoOuterOption", "ArmsOption", "HandsOption", "WaistOption", "LegsOption", "FeetOption"]:
		if creator.get_node_or_null(forbidden_name) != null:
			_fail("C67_2_CREATOR=BLOCKED direct_slot_control:%s" % forbidden_name)
			return

	var none_index := -1
	var lian_index := -1
	for index in range(option.item_count):
		var set_id := String(option.get_item_metadata(index))
		if set_id == String(SET_NONE):
			none_index = index
			if option.get_item_text(index) != "Sem uniforme externo":
				_fail("C67_2_CREATOR=BLOCKED none_label")
				return
		elif set_id == String(SET_LIAN):
			lian_index = index
			if option.get_item_text(index) != "Traje Marcial Lian":
				_fail("C67_2_CREATOR=BLOCKED lian_label")
				return
	if none_index != 0 or lian_index != 1:
		_fail("C67_2_CREATOR=BLOCKED option_order")
		return

	# Keep the previously approved Hair control active while selecting Uniform.
	var failures := creator.set_hair_style(HAIR_TOPKNOT)
	if not failures.is_empty():
		_fail("C67_2_CREATOR=BLOCKED hair_setup:%s" % ",".join(failures))
		return
	for _frame in range(3):
		await process_frame

	# Exercise the actual public OptionButton path.
	option.select(lian_index)
	option.item_selected.emit(lian_index)
	for _frame in range(4):
		await process_frame
	if creator.current_uniform_set_id() != SET_LIAN:
		_fail("C67_2_CREATOR=BLOCKED ui_selection")
		return
	if creator.current_hair_style_id() != HAIR_TOPKNOT:
		_fail("C67_2_CREATOR=BLOCKED hair_regression")
		return

	var profile := creator.current_profile()
	if ModularFighterUniformRuntime.validate_profile_set(profile).size() > 0:
		_fail("C67_2_CREATOR=BLOCKED atomic_profile")
		return
	for slot_name in EXPECTED_MODULES.keys():
		if String(profile.module_id(StringName(slot_name))) != String(EXPECTED_MODULES[slot_name]):
			_fail("C67_2_CREATOR=BLOCKED profile_module:%s" % slot_name)
			return
	if profile.module_id(&"torso_inner") != &"" or profile.module_id(&"hands") != &"":
		_fail("C67_2_CREATOR=BLOCKED null_slots")
		return

	var preview := creator.current_assembler()
	for slot_name in EXPECTED_Z.keys():
		var node := preview.get_node_or_null("Module_%s" % slot_name) as Sprite2D
		if node == null or node.z_index != int(EXPECTED_Z[slot_name]):
			_fail("C67_2_CREATOR=BLOCKED live_preview:%s" % slot_name)
			return
	if preview.get_node_or_null("Module_hair_back") == null or preview.get_node_or_null("Module_hair_front") == null:
		_fail("C67_2_CREATOR=BLOCKED live_preview_hair")
		return

	creator.set_display_name("C67 UNIFORM CREATOR")
	creator.set_preset_id(String(TEST_PRESET))
	failures = creator.save_current_preset(TEST_PRESET)
	if not failures.is_empty() or FirstPlayableSession.creator_preset_id() != TEST_PRESET:
		_fail("C67_2_CREATOR=BLOCKED save_handoff")
		return

	# Switch to none, prove preview clears the five garment nodes without touching Hair,
	# then reload the saved preset and require the complete set to return atomically.
	failures = creator.set_uniform_set(SET_NONE)
	if not failures.is_empty():
		_fail("C67_2_CREATOR=BLOCKED switch_none")
		return
	for _frame in range(3):
		await process_frame
	for slot_name in EXPECTED_MODULES.keys():
		if preview.get_node_or_null("Module_%s" % slot_name) != null:
			_fail("C67_2_CREATOR=BLOCKED none_preview:%s" % slot_name)
			return
	if creator.current_hair_style_id() != HAIR_TOPKNOT:
		_fail("C67_2_CREATOR=BLOCKED none_hair_regression")
		return

	failures = creator.load_user_preset(TEST_PRESET)
	if not failures.is_empty():
		_fail("C67_2_CREATOR=BLOCKED load:%s" % ",".join(failures))
		return
	for _frame in range(4):
		await process_frame
	if creator.current_uniform_set_id() != SET_LIAN or creator.current_hair_style_id() != HAIR_TOPKNOT:
		_fail("C67_2_CREATOR=BLOCKED load_roundtrip")
		return
	profile = creator.current_profile()
	if ModularFighterUniformRuntime.profile_set_id(profile) != SET_LIAN:
		_fail("C67_2_CREATOR=BLOCKED load_atomic_set")
		return
	preview = creator.current_assembler()
	for slot_name in EXPECTED_Z.keys():
		var node := preview.get_node_or_null("Module_%s" % slot_name) as Sprite2D
		if node == null or node.z_index != int(EXPECTED_Z[slot_name]):
			_fail("C67_2_CREATOR=BLOCKED load_preview:%s" % slot_name)
			return

	var signature := creator.uniform_creator_signature()
	if bool(signature.get("direct_slot_controls", true)) or bool(signature.get("cross_set_piece_mixing", true)):
		_fail("C67_2_CREATOR=BLOCKED public_contract")
		return
	if not bool(signature.get("live_preview", false)) or not bool(signature.get("selection_transactional", false)) or not bool(signature.get("preset_roundtrip", false)):
		_fail("C67_2_CREATOR=BLOCKED signature_flow")
		return
	var flow := creator.flow_signature()
	if not bool(flow.get("uniform_creator_control", false)) or String(flow.get("uniform_selection_unit", "")) != "uniform_set":
		_fail("C67_2_CREATOR=BLOCKED flow_signature")
		return
	if bool(flow.get("uniform_direct_slot_controls", true)) or bool(flow.get("uniform_cross_set_piece_mixing", true)):
		_fail("C67_2_CREATOR=BLOCKED flow_piece_controls")
		return
	if int(flow.get("uniform_set_count", 0)) != 2:
		_fail("C67_2_CREATOR=BLOCKED flow_set_count")
		return

	creator.queue_free()
	await process_frame

	# Saved/loaded Creator preset must reach battle with Hair + exact Uniform set.
	var battle_packed := load(BATTLE_SCENE) as PackedScene
	var battle := battle_packed.instantiate() as FirstPlayableController if battle_packed != null else null
	if battle == null:
		_fail("C67_2_CREATOR=BLOCKED battle_instantiate")
		return
	get_root().add_child(battle)
	for _frame in range(28):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("C67_2_CREATOR=BLOCKED battle_player")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("C67_2_CREATOR=BLOCKED battle_presenter")
		return
	if presenter.active_uniform_set_id() != SET_LIAN or presenter.active_hair_style_id() != HAIR_TOPKNOT:
		_fail("C67_2_CREATOR=BLOCKED battle_pack_state")
		return
	var handoff = battle.player_one.get_meta("creator_battle_handoff", {})
	if not (handoff is Dictionary) or String(handoff.get("uniform_set_id", "")) != String(SET_LIAN) or String(handoff.get("hair_style_id", "")) != String(HAIR_TOPKNOT):
		_fail("C67_2_CREATOR=BLOCKED battle_handoff")
		return

	print("C67_2_UNIFORM_CONTROL=PASS options=2 unit=uniform_set")
	print("C67_2_DIRECT_SLOT_CONTROLS=ABSENT slots=7")
	print("C67_2_LIVE_PREVIEW=PASS modules=5 hair_preserved=true")
	print("C67_2_PRESET_ROUNDTRIP=PASS schema=v2 atomic_set=true")
	print("C67_2_BATTLE_HANDOFF=PASS set=uniform_01_lian_martial hair=hair_01_lian_topknot")
	print("C67_2_UNIFORM_CREATOR_CONTROL=PASS")
	print("SIGNATURE=Tehkné Solutions")

	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

# Tehkné Solutions
