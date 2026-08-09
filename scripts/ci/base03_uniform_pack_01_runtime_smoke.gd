extends SceneTree

const TEST_PRESET := &"c67_uniform_pack_runtime_probe"
const UNIFORM_SET := &"uniform_01_lian_martial"
const HAIR_STYLE := &"hair_01_lian_topknot"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
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

	var sets := ModularFighterUniformRuntime.set_ids()
	if not sets.has("uniform_none") or not sets.has(String(UNIFORM_SET)):
		_fail("C67_1_RUNTIME=BLOCKED set_catalog")
		return

	var profile := ModularFighterProfile.new()
	profile.profile_id = TEST_PRESET
	profile.display_name = "C67 UNIFORM RUNTIME"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_skin_palette_id(&"skin_tone_03_warm")
	var failures := profile.set_base01_identity_module(&"face", &"face_01_balanced")
	failures.append_array(profile.set_base01_identity_module(&"eyes", &"eyes_01_focused"))
	failures.append_array(profile.set_base01_identity_module(&"brows", &"brows_01_focused"))
	failures.append_array(ModularFighterHairRuntime.set_profile_style(profile, HAIR_STYLE))
	failures.append_array(ModularFighterUniformRuntime.set_profile_set(profile, UNIFORM_SET))
	if not failures.is_empty():
		_fail("C67_1_RUNTIME=BLOCKED profile:%s" % ",".join(failures))
		return

	if ModularFighterUniformRuntime.profile_set_id(profile) != UNIFORM_SET:
		_fail("C67_1_RUNTIME=BLOCKED profile_set_roundtrip")
		return
	if not ModularFighterUniformRuntime.validate_profile_set(profile).is_empty():
		_fail("C67_1_RUNTIME=BLOCKED profile_set_validation")
		return
	for slot_name in EXPECTED_MODULES.keys():
		if String(profile.module_id(StringName(slot_name))) != String(EXPECTED_MODULES[slot_name]):
			_fail("C67_1_RUNTIME=BLOCKED profile_module:%s" % slot_name)
			return
	if profile.module_id(&"torso_inner") != &"" or profile.module_id(&"hands") != &"":
		_fail("C67_1_RUNTIME=BLOCKED intentionally_empty_slots")
		return

	# Invalid selection must not mutate an already valid atomic set.
	failures = ModularFighterUniformRuntime.set_profile_set(profile, &"uniform_missing_probe")
	if failures.is_empty() or ModularFighterUniformRuntime.profile_set_id(profile) != UNIFORM_SET:
		_fail("C67_1_RUNTIME=BLOCKED invalid_set_mutation")
		return

	# Direct partial edits are rejected by the pack boundary.
	profile.clear_module(&"feet")
	if ModularFighterUniformRuntime.validate_profile_set(profile).is_empty():
		_fail("C67_1_RUNTIME=BLOCKED partial_set_accepted")
		return
	failures = ModularFighterUniformRuntime.set_profile_set(profile, UNIFORM_SET)
	if not failures.is_empty():
		_fail("C67_1_RUNTIME=BLOCKED profile_restore")
		return

	var assembler := ModularFighterAssembler.new()
	get_root().add_child(assembler)
	failures = assembler.configure(profile)
	if not failures.is_empty():
		_fail("C67_1_RUNTIME=BLOCKED assembler_configure:%s" % ",".join(failures))
		return
	var base_texture := load("res://assets/modular_fighters/base_00/base_fighter_v1_master.png") as Texture2D
	if base_texture == null:
		_fail("C67_1_RUNTIME=BLOCKED base_texture")
		return
	var body := Sprite2D.new()
	body.texture = base_texture
	body.centered = true
	body.position = Vector2(
		base_texture.get_width() * (0.5 - 0.5),
		base_texture.get_height() * (0.5 - 0.92)
	)
	if not assembler.attach_visual_module(&"body_base", body):
		_fail("C67_1_RUNTIME=BLOCKED body_attach")
		return
	failures = assembler.assemble_base01_profile_identity()
	failures.append_array(ModularFighterHairRuntime.assemble_profile(profile, assembler))
	failures.append_array(ModularFighterUniformRuntime.assemble_profile(profile, assembler))
	if not failures.is_empty():
		_fail("C67_1_RUNTIME=BLOCKED assembler_uniform:%s" % ",".join(failures))
		return

	var signature := ModularFighterUniformRuntime.runtime_signature(profile, assembler)
	if String(signature.get("set_id", "")) != String(UNIFORM_SET):
		_fail("C67_1_RUNTIME=BLOCKED assembler_set")
		return
	var nodes = signature.get("nodes", {})
	for slot_name in EXPECTED_MODULES.keys():
		var node_info = nodes.get(slot_name, {}) if nodes is Dictionary else {}
		if not (node_info is Dictionary) or not bool(node_info.get("present", false)):
			_fail("C67_1_RUNTIME=BLOCKED assembler_node:%s" % slot_name)
			return
		if int(node_info.get("z", -1)) != int(EXPECTED_Z[slot_name]):
			_fail("C67_1_RUNTIME=BLOCKED assembler_z:%s" % slot_name)
			return
	for empty_slot in ["torso_inner", "hands"]:
		var empty_info = nodes.get(empty_slot, {}) if nodes is Dictionary else {}
		if empty_info is Dictionary and bool(empty_info.get("present", false)):
			_fail("C67_1_RUNTIME=BLOCKED empty_node:%s" % empty_slot)
			return
	assembler.queue_free()
	await process_frame

	# Persist through the existing v2 generic modules boundary and activate battle.
	failures = ModularFighterPresetStore.save_user_preset(profile, TEST_PRESET)
	if not failures.is_empty() or not FirstPlayableSession.set_creator_preset(TEST_PRESET):
		_fail("C67_1_RUNTIME=BLOCKED preset_handoff")
		return
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("C67_1_RUNTIME=BLOCKED battle")
		return
	get_root().add_child(battle)
	for _frame in range(28):
		await process_frame
	if not is_instance_valid(battle.player_one) or String(battle.player_one.build.character_id) != "lian_wu":
		_fail("C67_1_RUNTIME=BLOCKED combat_build")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("C67_1_RUNTIME=BLOCKED presenter")
		return
	if presenter.active_uniform_set_id() != UNIFORM_SET or presenter.active_hair_style_id() != HAIR_STYLE:
		_fail("C67_1_RUNTIME=BLOCKED battle_pack_state")
		return
	var battle_assembler := presenter.assembler()
	for slot_name in EXPECTED_MODULES.keys():
		var node := battle_assembler.get_node_or_null("Module_%s" % slot_name) as Sprite2D
		if node == null or node.z_index != int(EXPECTED_Z[slot_name]):
			_fail("C67_1_RUNTIME=BLOCKED battle_node:%s" % slot_name)
			return
	var handoff_value = battle.player_one.get_meta("creator_battle_handoff", {})
	if not (handoff_value is Dictionary) or String(handoff_value.get("uniform_set_id", "")) != String(UNIFORM_SET):
		_fail("C67_1_RUNTIME=BLOCKED battle_handoff")
		return

	print("C67_1_PROFILE_ATOMIC_SET=PASS set=uniform_01_lian_martial modules=5 empty=2")
	print("C67_1_ASSEMBLER=PASS torso_outer_z=65 arms_z=12 waist_z=14 legs_z=11 feet_z=12")
	print("C67_1_PRESET_ROUNDTRIP=PASS generic_modules=true hair=hair_01_lian_topknot")
	print("C67_1_BATTLE_RUNTIME=PASS set=uniform_01_lian_martial build=lian_wu")
	print("C67_1_CREATOR_CONTROL=BLOCKED stage=C67.2")
	print("C67_1_UNIFORM_PACK_RUNTIME=PASS")
	print("SIGNATURE=Tehkné Solutions")

	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

# Tehkné Solutions
