extends SceneTree

const TEST_PRESET := &"c66_hair_pack_runtime_probe"
const STYLE := &"hair_01_lian_topknot"
const BACK_ID := &"hair_01_lian_topknot_back"
const FRONT_ID := &"hair_01_lian_topknot_front"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"

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

	var styles := ModularFighterHairRuntime.style_ids()
	if not styles.has("hair_none") or not styles.has(String(STYLE)):
		_fail("C66_1_RUNTIME=BLOCKED style_catalog")
		return

	var profile := ModularFighterProfile.new()
	profile.profile_id = TEST_PRESET
	profile.display_name = "C66 HAIR RUNTIME"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_skin_palette_id(&"skin_tone_03_warm")

	# FirstPlayableSession intentionally accepts only canonical v2 Creator battle
	# presets with explicit BASE-01 identity slots. The assembler may visually
	# fall back to defaults, but persistence/session handoff must not. Serialize
	# the approved default identity here so this fixture exercises the same
	# contract as a real Creator-produced preset.
	var failures := profile.set_base01_identity_module(&"face", &"face_01_balanced")
	failures.append_array(profile.set_base01_identity_module(&"eyes", &"eyes_01_focused"))
	failures.append_array(profile.set_base01_identity_module(&"brows", &"brows_01_focused"))
	if not failures.is_empty():
		_fail("C66_1_RUNTIME=BLOCKED base01_identity:%s" % ",".join(failures))
		return

	failures = ModularFighterHairRuntime.set_profile_style(profile, STYLE)
	if not failures.is_empty():
		_fail("C66_1_RUNTIME=BLOCKED profile_style:%s" % ",".join(failures))
		return
	if profile.module_id(&"hair_back") != BACK_ID or profile.module_id(&"hair_front") != FRONT_ID:
		_fail("C66_1_RUNTIME=BLOCKED atomic_profile_pair")
		return
	if ModularFighterHairRuntime.profile_style_id(profile) != STYLE:
		_fail("C66_1_RUNTIME=BLOCKED profile_style_roundtrip")
		return
	if not ModularFighterHairRuntime.validate_profile_pair(profile).is_empty():
		_fail("C66_1_RUNTIME=BLOCKED profile_pair_validation")
		return

	# Invalid selection must not mutate the already valid atomic pair.
	failures = ModularFighterHairRuntime.set_profile_style(profile, &"hair_missing_probe")
	if failures.is_empty():
		_fail("C66_1_RUNTIME=BLOCKED invalid_style_accepted")
		return
	if profile.module_id(&"hair_back") != BACK_ID or profile.module_id(&"hair_front") != FRONT_ID:
		_fail("C66_1_RUNTIME=BLOCKED invalid_style_mutated_pair")
		return

	# Cross-style/incomplete direct edits are detected fail-closed by the pack boundary.
	profile.clear_module(&"hair_front")
	if ModularFighterHairRuntime.validate_profile_pair(profile).is_empty():
		_fail("C66_1_RUNTIME=BLOCKED incomplete_pair_accepted")
		return
	failures = ModularFighterHairRuntime.set_profile_style(profile, STYLE)
	if not failures.is_empty():
		_fail("C66_1_RUNTIME=BLOCKED profile_restore")
		return

	# Direct assembler proof before the scene transition.
	var assembler := ModularFighterAssembler.new()
	get_root().add_child(assembler)
	failures = assembler.configure(profile)
	if not failures.is_empty():
		_fail("C66_1_RUNTIME=BLOCKED assembler_configure:%s" % ",".join(failures))
		return
	var base_texture := load("res://assets/modular_fighters/base_00/base_fighter_v1_master.png") as Texture2D
	if base_texture == null:
		_fail("C66_1_RUNTIME=BLOCKED base_texture")
		return
	var body := Sprite2D.new()
	body.texture = base_texture
	body.centered = true
	body.position = Vector2(
		base_texture.get_width() * (0.5 - 0.5),
		base_texture.get_height() * (0.5 - 0.92)
	)
	if not assembler.attach_visual_module(&"body_base", body):
		_fail("C66_1_RUNTIME=BLOCKED body_attach")
		return
	failures = assembler.assemble_base01_profile_identity()
	failures.append_array(ModularFighterHairRuntime.assemble_profile(profile, assembler))
	if not failures.is_empty():
		_fail("C66_1_RUNTIME=BLOCKED assembler_hair:%s" % ",".join(failures))
		return
	var hair_signature := ModularFighterHairRuntime.runtime_signature(profile, assembler)
	if not bool(hair_signature.get("hair_back_present", false)) or not bool(hair_signature.get("hair_front_present", false)):
		_fail("C66_1_RUNTIME=BLOCKED assembler_hair_nodes")
		return
	if int(hair_signature.get("hair_back_z", -1)) != 5 or int(hair_signature.get("hair_front_z", -1)) != 50:
		_fail("C66_1_RUNTIME=BLOCKED assembler_hair_z")
		return
	if not ModularFighterLayerPolicy.hair_order_is_valid():
		_fail("C66_1_RUNTIME=BLOCKED layer_policy")
		return
	assembler.queue_free()
	await process_frame

	# Persist through the same canonical v2 boundary used by the Creator and activate the real battle.
	failures = ModularFighterPresetStore.save_user_preset(profile, TEST_PRESET)
	if not failures.is_empty():
		_fail("C66_1_RUNTIME=BLOCKED preset_save:%s" % ",".join(failures))
		return
	if not FirstPlayableSession.set_creator_preset(TEST_PRESET):
		_fail("C66_1_RUNTIME=BLOCKED session_select")
		return

	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("C66_1_RUNTIME=BLOCKED battle_instantiate")
		return
	get_root().add_child(battle)
	for _frame in range(24):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("C66_1_RUNTIME=BLOCKED player_one")
		return
	if String(battle.player_one.build.character_id) != "lian_wu":
		_fail("C66_1_RUNTIME=BLOCKED combat_build_changed")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("C66_1_RUNTIME=BLOCKED modular_presenter")
		return
	if presenter.active_hair_style_id() != STYLE:
		_fail("C66_1_RUNTIME=BLOCKED battle_style")
		return
	var battle_assembler := presenter.assembler()
	var back := battle_assembler.get_node_or_null("Module_hair_back") as Sprite2D
	var front := battle_assembler.get_node_or_null("Module_hair_front") as Sprite2D
	if back == null or front == null:
		_fail("C66_1_RUNTIME=BLOCKED battle_hair_nodes")
		return
	if back.z_index != 5 or front.z_index != 50:
		_fail("C66_1_RUNTIME=BLOCKED battle_hair_z")
		return
	var handoff_value = battle.player_one.get_meta("creator_battle_handoff", {})
	if not (handoff_value is Dictionary) or String(handoff_value.get("hair_style_id", "")) != String(STYLE):
		_fail("C66_1_RUNTIME=BLOCKED battle_handoff")
		return

	print("C66_1_PROFILE_ATOMIC_STYLE=PASS style=hair_01_lian_topknot")
	print("C66_1_ASSEMBLER=PASS back_z=5 front_z=50")
	print("C66_1_PRESET_ROUNDTRIP=PASS generic_modules=true canonical_base01_identity=true")
	print("C66_1_BATTLE_RUNTIME=PASS style=hair_01_lian_topknot build=lian_wu")
	print("C66_1_CREATOR_CONTROL=BLOCKED stage=C66.2")
	print("C66_1_HAIR_PACK_RUNTIME=PASS")
	print("SIGNATURE=Tehkné Solutions")

	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

# Tehkné Solutions
