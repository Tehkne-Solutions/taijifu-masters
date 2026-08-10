extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const TEST_PRESET := &"base05_4_weapon_set_creator_probe"
const WEAPON_NONE := &"weapon_none"
const WEAPON_KATANA := &"weapon_01_lian_serene_katana"
const WEAPON_MAIN := &"katana_lian_wu"
const WEAPON_BACK := &"sheath_lian_wu_blue"
const HAIR_TOPKNOT := &"hair_01_lian_topknot"
const UNIFORM_LIAN := &"uniform_01_lian_martial"
const ARMOR_GUARD := &"armor_01_taijifu_guard"
const BACK_GUARDIAN := &"back_01_guardian_panel"
const COMBAT_LOADOUT := &"combat_lian_wu_first_playable"
const OUTPUT := "res://artifacts/base05_4/BASE05_4_WEAPON_SET_CREATOR_CONTROL.review-1280x720.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-BASE05-4")

	if not ModularFighterEquipmentRuntime.weapon_set_creator_exposure_enabled():
		_fail("BASE05_4_CREATOR=BLOCKED manifest_exposure_false")
		return
	var creator_sets := ModularFighterEquipmentRuntime.creator_weapon_set_ids()
	if creator_sets != PackedStringArray(["weapon_none", "weapon_01_lian_serene_katana"]):
		_fail("BASE05_4_CREATOR=BLOCKED production_filter:%s" % str(creator_sets))
		return

	var packed := load(CREATOR_SCENE) as PackedScene
	var creator := packed.instantiate() as ModularFighterCreatorScene if packed != null else null
	if creator == null:
		_fail("BASE05_4_CREATOR=BLOCKED instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(12):
		await process_frame

	var option := creator.weapon_set_option()
	if option == null or option.name != "WeaponSetOption":
		_fail("BASE05_4_CREATOR=BLOCKED option_missing")
		return
	if option.item_count != 2 or option.disabled:
		_fail("BASE05_4_CREATOR=BLOCKED option_count")
		return
	if option.fit_to_longest_item or not option.clip_text:
		_fail("BASE05_4_CREATOR=BLOCKED option_bounds_policy")
		return
	for forbidden_name in ["WeaponMainOption", "WeaponOffhandOption", "WeaponBackOption"]:
		if creator.get_node_or_null(forbidden_name) != null:
			_fail("BASE05_4_CREATOR=BLOCKED forbidden_control:%s" % forbidden_name)
			return

	var none_index := -1
	var katana_index := -1
	for index in range(option.item_count):
		var item_id := String(option.get_item_metadata(index))
		if item_id == String(WEAPON_NONE):
			none_index = index
			if option.get_item_text(index) != "Sem arma visual principal":
				_fail("BASE05_4_CREATOR=BLOCKED none_label")
				return
		elif item_id == String(WEAPON_KATANA):
			katana_index = index
			if option.get_item_text(index) != "Katana Serena — Lian Wu":
				_fail("BASE05_4_CREATOR=BLOCKED katana_label")
				return
	if none_index != 0 or katana_index != 1:
		_fail("BASE05_4_CREATOR=BLOCKED option_order")
		return

	# Compose all previously promoted packs first; weapon_set must not mutate any
	# of them, weapon_back or combat metadata.
	var failures := creator.set_hair_style(HAIR_TOPKNOT)
	failures.append_array(creator.set_uniform_set(UNIFORM_LIAN))
	failures.append_array(creator.set_armor_set(ARMOR_GUARD))
	failures.append_array(creator.set_back_accessory(BACK_GUARDIAN))
	if not failures.is_empty():
		_fail("BASE05_4_CREATOR=BLOCKED prior_pack_setup:%s" % ",".join(failures))
		return
	var profile := creator.current_profile()
	profile.set_module(&"weapon_back", WEAPON_BACK)
	profile.combat_loadout_id = COMBAT_LOADOUT
	failures = ModularFighterEquipmentRuntime.assemble_profile(profile, creator.current_assembler())
	if not failures.is_empty():
		_fail("BASE05_4_CREATOR=BLOCKED weapon_back_setup:%s" % ",".join(failures))
		return
	for _frame in range(4):
		await process_frame

	# Exercise the real public OptionButton path.
	option.select(katana_index)
	option.item_selected.emit(katana_index)
	for _frame in range(6):
		await process_frame
	if creator.current_weapon_set_id() != WEAPON_KATANA:
		_fail("BASE05_4_CREATOR=BLOCKED ui_selection")
		return
	if profile.module_id(&"weapon_main") != WEAPON_MAIN or profile.module_id(&"weapon_offhand") != &"":
		_fail("BASE05_4_CREATOR=BLOCKED atomic_slot_state")
		return
	if profile.module_id(&"weapon_back") != WEAPON_BACK:
		_fail("BASE05_4_CREATOR=BLOCKED weapon_back_mutated")
		return
	if profile.combat_loadout_id != COMBAT_LOADOUT:
		_fail("BASE05_4_CREATOR=BLOCKED combat_loadout_mutated")
		return
	if creator.current_hair_style_id() != HAIR_TOPKNOT or creator.current_uniform_set_id() != UNIFORM_LIAN or creator.current_armor_set_id() != ARMOR_GUARD or creator.current_back_accessory_id() != BACK_GUARDIAN:
		_fail("BASE05_4_CREATOR=BLOCKED cross_pack_regression")
		return

	var preview := creator.current_assembler()
	var main_preview := preview.get_node_or_null("Module_weapon_main") as Sprite2D
	var back_preview := preview.get_node_or_null("Module_weapon_back") as Sprite2D
	var back_accessory := preview.get_node_or_null("Module_back_accessory") as Sprite2D
	var hair_back := preview.get_node_or_null("Module_hair_back") as Sprite2D
	if main_preview == null or main_preview.z_index != 80 or not main_preview.visible:
		_fail("BASE05_4_CREATOR=BLOCKED weapon_main_preview")
		return
	if back_preview == null or back_preview.z_index != 3 or back_accessory == null or back_accessory.z_index != 4 or hair_back == null or hair_back.z_index != 5:
		_fail("BASE05_4_CREATOR=BLOCKED preview_layer_chain")
		return
	if preview.get_node_or_null("Module_torso_outer") == null or preview.get_node_or_null("Module_shoulders") == null:
		_fail("BASE05_4_CREATOR=BLOCKED preview_prior_packs")
		return

	# Layout must fit all five public selectors in the reviewed top band and
	# remain above IdentitySelector at y=116.
	var layout := creator.reviewed_layout_signature()
	if bool(layout.get("controls_overlap", true)):
		_fail("BASE05_4_CREATOR=BLOCKED controls_overlap")
		return
	var expected_rects := {
		"ArmorSetOption": Rect2(Vector2(470, 38), Vector2(145, 42)),
		"BackAccessoryOption": Rect2(Vector2(625, 38), Vector2(145, 42)),
		"UniformSetOption": Rect2(Vector2(780, 38), Vector2(145, 42)),
		"HairStyleOption": Rect2(Vector2(935, 38), Vector2(145, 42)),
		"WeaponSetOption": Rect2(Vector2(1090, 38), Vector2(165, 42)),
	}
	var identity_rect := Rect2(Vector2(470, 116), Vector2(786, 544))
	for node_name in expected_rects:
		var control := creator.get_node_or_null(node_name) as OptionButton
		if control == null:
			_fail("BASE05_4_CREATOR=BLOCKED layout_control_missing:%s" % node_name)
			return
		var actual := Rect2(control.position, control.size)
		if actual != expected_rects[node_name]:
			_fail("BASE05_4_CREATOR=BLOCKED layout_contract:%s:%s" % [node_name, str(actual)])
			return
		if actual.intersects(identity_rect) or actual.end.y > 108.0 or actual.end.x > 1280.0:
			_fail("BASE05_4_CREATOR=BLOCKED layout_boundary:%s" % node_name)
			return

	var signature := creator.weapon_set_creator_signature()
	if String(signature.get("selection_unit", "")) != "weapon_set" or bool(signature.get("direct_slot_controls", true)):
		_fail("BASE05_4_CREATOR=BLOCKED public_signature")
		return
	if bool(signature.get("weapon_back_creator_control", true)) or bool(signature.get("combat_loadout_mutation", true)):
		_fail("BASE05_4_CREATOR=BLOCKED ownership_signature")
		return
	var flow := creator.flow_signature()
	if not bool(flow.get("weapon_set_creator_control", false)) or bool(flow.get("weapon_direct_slot_controls", true)) or bool(flow.get("weapon_combat_loadout_mutation", true)) or int(flow.get("weapon_set_count", 0)) != 2:
		_fail("BASE05_4_CREATOR=BLOCKED flow_signature")
		return

	# Capture the Creator with the selected katana visible in preview.
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("BASE05_4_CREATOR=BLOCKED capture")
		return
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if image.save_png(OUTPUT) != OK:
		_fail("BASE05_4_CREATOR=BLOCKED capture_save")
		return

	# weapon_none clears only the atomic BASE-05 slots.
	option.select(none_index)
	option.item_selected.emit(none_index)
	for _frame in range(5):
		await process_frame
	if creator.current_weapon_set_id() != WEAPON_NONE or profile.module_id(&"weapon_main") != &"" or profile.module_id(&"weapon_offhand") != &"":
		_fail("BASE05_4_CREATOR=BLOCKED none_transaction")
		return
	if preview.get_node_or_null("Module_weapon_main") != null:
		_fail("BASE05_4_CREATOR=BLOCKED none_visual_clear")
		return
	if profile.module_id(&"weapon_back") != WEAPON_BACK or preview.get_node_or_null("Module_weapon_back") == null:
		_fail("BASE05_4_CREATOR=BLOCKED none_weapon_back_regression")
		return
	if profile.combat_loadout_id != COMBAT_LOADOUT:
		_fail("BASE05_4_CREATOR=BLOCKED none_combat_regression")
		return

	# Re-select, persist and prove exact preset v2 roundtrip.
	option.select(katana_index)
	option.item_selected.emit(katana_index)
	for _frame in range(5):
		await process_frame
	creator.set_display_name("BASE05 WEAPON SET")
	creator.set_preset_id(String(TEST_PRESET))
	failures = creator.save_current_preset(TEST_PRESET)
	if not failures.is_empty() or FirstPlayableSession.creator_preset_id() != TEST_PRESET:
		_fail("BASE05_4_CREATOR=BLOCKED save_handoff")
		return
	failures = creator.set_weapon_set(WEAPON_NONE)
	if not failures.is_empty():
		_fail("BASE05_4_CREATOR=BLOCKED switch_none_before_load")
		return
	failures = creator.load_user_preset(TEST_PRESET)
	if not failures.is_empty():
		_fail("BASE05_4_CREATOR=BLOCKED load:%s" % ",".join(failures))
		return
	for _frame in range(10):
		await process_frame
	profile = creator.current_profile()
	if creator.current_weapon_set_id() != WEAPON_KATANA or profile.module_id(&"weapon_main") != WEAPON_MAIN or profile.module_id(&"weapon_back") != WEAPON_BACK:
		_fail("BASE05_4_CREATOR=BLOCKED preset_roundtrip_visual")
		return
	if profile.combat_loadout_id != COMBAT_LOADOUT:
		_fail("BASE05_4_CREATOR=BLOCKED preset_roundtrip_combat")
		return
	if creator.current_hair_style_id() != HAIR_TOPKNOT or creator.current_uniform_set_id() != UNIFORM_LIAN or creator.current_armor_set_id() != ARMOR_GUARD or creator.current_back_accessory_id() != BACK_GUARDIAN:
		_fail("BASE05_4_CREATOR=BLOCKED preset_roundtrip_cross_pack")
		return

	var creator_handoff := creator.battle_handoff_signature()
	if String(creator_handoff.get("weapon_set_id", "")) != String(WEAPON_KATANA) or String(creator_handoff.get("weapon_main_id", "")) != String(WEAPON_MAIN):
		_fail("BASE05_4_CREATOR=BLOCKED creator_handoff_weapon")
		return
	if String(creator_handoff.get("weapon_back_id", "")) != String(WEAPON_BACK) or String(creator_handoff.get("combat_loadout_id", "")) != String(COMBAT_LOADOUT):
		_fail("BASE05_4_CREATOR=BLOCKED creator_handoff_preservation")
		return
	if bool(creator_handoff.get("weapon_set_combat_loadout_mutation", true)):
		_fail("BASE05_4_CREATOR=BLOCKED creator_handoff_mutation")
		return

	creator.queue_free()
	await process_frame

	# Saved weapon_set must survive the actual First Playable. Combat remains the
	# existing serene_katana kit; visual selection cannot replace the combat owner.
	var battle_packed := load(BATTLE_SCENE) as PackedScene
	var battle := battle_packed.instantiate() as FirstPlayableController if battle_packed != null else null
	if battle == null:
		_fail("BASE05_4_CREATOR=BLOCKED battle_instantiate")
		return
	get_root().add_child(battle)
	for _frame in range(45):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("BASE05_4_CREATOR=BLOCKED battle_player")
		return
	var fighter := battle.player_one as FighterController
	var presenter := fighter.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("BASE05_4_CREATOR=BLOCKED battle_presenter")
		return
	if presenter.active_weapon_main_id() != WEAPON_MAIN or presenter.active_weapon_back_id() != WEAPON_BACK:
		_fail("BASE05_4_CREATOR=BLOCKED battle_weapon_state")
		return
	if fighter.build == null or fighter.build.weapon_id != &"serene_katana" or fighter.equipped_weapon_id != &"serene_katana":
		_fail("BASE05_4_CREATOR=BLOCKED battle_combat_owner")
		return
	var battle_assembler := presenter.assembler()
	var main_battle := battle_assembler.get_node_or_null("Module_weapon_main") as Sprite2D
	if main_battle == null or main_battle.z_index != 80 or main_battle.visible:
		_fail("BASE05_4_CREATOR=BLOCKED battle_neutral_policy")
		return

	var main_instance := main_battle.get_instance_id()
	fighter.velocity = Vector2.ZERO
	fighter._is_blocking = false
	fighter._dodge_timer = 0.0
	fighter._attack_phase = FighterController.AttackPhase.ACTIVE
	fighter._attack_phase_timer = 0.75
	for _frame in range(3):
		await process_frame
	if presenter.visual_state() != &"attack_light" or not main_battle.visible:
		_fail("BASE05_4_CREATOR=BLOCKED battle_attack_policy")
		return
	if battle_assembler.get_node_or_null("Module_weapon_main").get_instance_id() != main_instance:
		_fail("BASE05_4_CREATOR=BLOCKED battle_weapon_recreated")
		return

	var handoff_value = fighter.get_meta("creator_battle_handoff", {})
	if not (handoff_value is Dictionary):
		_fail("BASE05_4_CREATOR=BLOCKED battle_handoff")
		return
	var handoff := handoff_value as Dictionary
	if String(handoff.get("weapon_main_id", "")) != String(WEAPON_MAIN) or String(handoff.get("weapon_back_id", "")) != String(WEAPON_BACK):
		_fail("BASE05_4_CREATOR=BLOCKED battle_handoff_visual")
		return
	if String(handoff.get("weapon_combat_behavior_owner", "")) != "WeaponKitCatalog":
		_fail("BASE05_4_CREATOR=BLOCKED battle_handoff_owner")
		return

	print("BASE05_4_WEAPON_SET_CONTROL=PASS options=2 unit=weapon_set atomic=weapon_main+weapon_offhand")
	print("BASE05_4_DIRECT_SLOT_CONTROLS=ABSENT weapon_main=true weapon_offhand=true weapon_back=true")
	print("BASE05_4_LIVE_PREVIEW=PASS weapon_main=80 weapon_back=3 back=4 hair=5 prior_packs=true")
	print("BASE05_4_NONE_TRANSACTION=PASS main_cleared=true offhand_cleared=true weapon_back_preserved=true combat_preserved=true")
	print("BASE05_4_PRESET_ROUNDTRIP=PASS schema=v2 weapon_set=weapon_01_lian_serene_katana combat_loadout_preserved=true")
	print("BASE05_4_BATTLE_HANDOFF=PASS weapon_main=katana_lian_wu combat=serene_katana neutral=false attack=true")
	print("BASE05_4_LAYOUT=PASS controls=5 overlap=false identity_overlap=false viewport=1280x720")
	print("BASE05_4_VISUAL_OUTPUT=" + OUTPUT)
	print("BASE05_4_WEAPON_SET_CREATOR_CONTROL=PASS")
	print("SIGNATURE=Tehkné Solutions")

	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	print(message)
	_cleanup()
	FirstPlayableSession.reset()
	quit(2)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

# Tehkné Solutions
