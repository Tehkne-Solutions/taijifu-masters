extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_WAIT_FRAMES := 420
const EXPECTED_WEAPON_MAIN := &"katana_lian_wu"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_difficulty(&"apprentice")

	if not FirstPlayableSession.ensure_battle_visual_preset():
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED preset_materialization")
		return
	if not FirstPlayableSession.using_production_default_preset():
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED default_not_active")
		return

	var expected := FirstPlayableSession.production_default_visual_signature()
	if bool(expected.get("legacy_sparse_base01_default", true)):
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED sparse_default_regression")
		return
	var expected_stack = expected.get("profile_stack", [])
	if not (expected_stack is Array) or expected_stack != ["BASE-01", "BASE-02", "BASE-03", "BASE-04", "BASE-05"]:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED production_stack:%s" % str(expected_stack))
		return

	var profile_result := FirstPlayableSession.creator_profile_result()
	if not bool(profile_result.get("ok", false)):
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED profile_load")
		return
	var profile := profile_result.get("profile") as ModularFighterProfile
	if profile == null:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED profile_type")
		return
	if profile.combat_loadout_id != FirstPlayableSession.PRODUCTION_COMBAT_LOADOUT:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED combat_loadout:%s" % String(profile.combat_loadout_id))
		return
	if ModularFighterHairRuntime.profile_style_id(profile) != FirstPlayableSession.PRODUCTION_HAIR_STYLE:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED hair_profile")
		return
	if ModularFighterUniformRuntime.profile_set_id(profile) != FirstPlayableSession.PRODUCTION_UNIFORM_SET:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED uniform_profile")
		return
	if ModularFighterArmorRuntime.profile_armor_set_id(profile) != FirstPlayableSession.PRODUCTION_ARMOR_SET:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED armor_profile")
		return
	if ModularFighterArmorRuntime.profile_back_accessory_id(profile) != FirstPlayableSession.PRODUCTION_BACK_ACCESSORY:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED back_profile")
		return
	if ModularFighterEquipmentRuntime.profile_weapon_set_id(profile) != FirstPlayableSession.PRODUCTION_WEAPON_SET:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED weapon_set_profile")
		return
	if profile.module_id(&"weapon_back") != FirstPlayableSession.PRODUCTION_WEAPON_BACK:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED weapon_back_profile")
		return
	if profile.module_id(&"weapon_main") != EXPECTED_WEAPON_MAIN:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED weapon_main_profile:%s" % String(profile.module_id(&"weapon_main")))
		return

	var module_count := _nonempty_module_count(profile)
	if module_count < 16:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED profile_module_count:%d" % module_count)
		return

	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED battle_instantiate")
		return
	battle.countdown_step_seconds = 0.01
	battle.fight_command_seconds = 0.01
	battle.match_time_limit_seconds = 40.0
	root.add_child(battle)

	var presenter := await _wait_for_presenter(battle)
	if presenter == null:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED presenter_timeout", battle)
		return
	if not presenter.using_modular_assets():
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED modular_inactive", battle)
		return
	if presenter.active_hair_style_id() != FirstPlayableSession.PRODUCTION_HAIR_STYLE:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED active_hair", battle)
		return
	if presenter.active_uniform_set_id() != FirstPlayableSession.PRODUCTION_UNIFORM_SET:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED active_uniform", battle)
		return
	if presenter.active_armor_set_id() != FirstPlayableSession.PRODUCTION_ARMOR_SET:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED active_armor", battle)
		return
	if presenter.active_back_accessory_id() != FirstPlayableSession.PRODUCTION_BACK_ACCESSORY:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED active_back", battle)
		return
	if presenter.active_weapon_back_id() != FirstPlayableSession.PRODUCTION_WEAPON_BACK:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED active_weapon_back", battle)
		return
	if presenter.active_weapon_main_id() != EXPECTED_WEAPON_MAIN:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED active_weapon_main", battle)
		return

	var assembler := presenter.assembler()
	if assembler == null or not assembler.is_ready_for_render():
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED assembler", battle)
		return
	var missing_slots := PackedStringArray()
	for raw_slot in profile.modules.keys():
		var slot := String(raw_slot)
		var module_id := String(profile.modules.get(slot, ""))
		if module_id.is_empty():
			continue
		if assembler.get_node_or_null("Module_%s" % slot) == null:
			missing_slots.append(slot)
	if not missing_slots.is_empty():
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED runtime_slots_missing:%s" % ",".join(missing_slots), battle)
		return

	var lot01 := battle.player_one.get_node_or_null("FirstPlayableRealAssetPresenter") as FirstPlayableLot01Presenter
	var lot01_sprite := lot01.get_node_or_null("Lot01AnimatedSprite") as AnimatedSprite2D if lot01 != null else null
	if lot01 == null or lot01_sprite == null or lot01.visible:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED lot01_fallback_boundary", battle)
		return

	var pose_runtime := battle.get_node_or_null("FirstPlayableModularPoseRuntime") as FirstPlayableModularPoseRuntime
	if pose_runtime == null or not pose_runtime.authority_active():
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED skeletal_authority", battle)
		return
	var pose_signature := pose_runtime.pose_rig().runtime_signature()
	var mesh_count := int(pose_signature.get("mesh_layer_count", 0))
	var sprite_module_count := _sprite_module_count(assembler)
	if mesh_count != sprite_module_count or mesh_count < module_count + 1:
		_fail("P0_2_PRODUCTION_LIAN_GATE=BLOCKED mesh_parity meshes=%d sprites=%d profile=%d" % [
			mesh_count, sprite_module_count, module_count,
		], battle)
		return

	print("P0_2_PRODUCTION_LIAN_PROFILE=PASS modules=%d stack=BASE01-05" % module_count)
	print("P0_2_PRODUCTION_LIAN_COMPOSITION=PASS hair=%s uniform=%s armor=%s back=%s weapon_set=%s" % [
		String(presenter.active_hair_style_id()),
		String(presenter.active_uniform_set_id()),
		String(presenter.active_armor_set_id()),
		String(presenter.active_back_accessory_id()),
		String(ModularFighterEquipmentRuntime.profile_weapon_set_id(profile)),
	])
	print("P0_2_PRODUCTION_LIAN_COMBAT_OWNER=PASS loadout=%s visual_weapon=%s" % [
		String(profile.combat_loadout_id), String(presenter.active_weapon_main_id()),
	])
	print("P0_2_PRODUCTION_LIAN_FALLBACK=PASS lot01=preserved_hidden")
	print("P0_2_PRODUCTION_LIAN_MESH_PARITY=PASS sprites=%d meshes=%d" % [sprite_module_count, mesh_count])
	print("P0_2_PRODUCTION_LIAN_PRODUCT_GATE=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _wait_for_presenter(battle: FirstPlayableController) -> FirstPlayableModularFighterPresenter:
	for _frame in range(MAX_WAIT_FRAMES):
		if is_instance_valid(battle.player_one):
			var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
			if presenter != null and presenter.using_modular_assets():
				return presenter
		await process_frame
	return null

func _nonempty_module_count(profile: ModularFighterProfile) -> int:
	var count := 0
	for raw_slot in profile.modules.keys():
		if not String(profile.modules.get(raw_slot, "")).is_empty():
			count += 1
	return count

func _sprite_module_count(assembler: ModularFighterAssembler) -> int:
	var count := 0
	for child in assembler.get_children():
		if child is Sprite2D and String(child.name).begins_with("Module_"):
			count += 1
	return count

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(FirstPlayableSession.PRODUCTION_DEFAULT_PRESET_ID)

func _fail(message: String, battle: Node = null) -> void:
	Engine.time_scale = 1.0
	push_error(message)
	print(message)
	print("SIGNATURE=Tehkné Solutions")
	if is_instance_valid(battle):
		battle.queue_free()
	_cleanup()
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions