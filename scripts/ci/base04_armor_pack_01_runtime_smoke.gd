extends SceneTree

const TEST_PRESET := &"c68_armor_pack_runtime_probe"
const ARMOR_SET := &"armor_01_taijifu_guard"
const HAIR_STYLE := &"hair_01_lian_topknot"
const UNIFORM_SET := &"uniform_01_lian_martial"
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

	var profile := ModularFighterProfile.new()
	profile.profile_id = TEST_PRESET
	profile.display_name = "C68 ARMOR RUNTIME"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_skin_palette_id(&"skin_tone_03_warm")
	var failures := profile.set_base01_identity_module(&"face", &"face_01_balanced")
	failures.append_array(profile.set_base01_identity_module(&"eyes", &"eyes_01_focused"))
	failures.append_array(profile.set_base01_identity_module(&"brows", &"brows_01_focused"))
	failures.append_array(ModularFighterHairRuntime.set_profile_style(profile, HAIR_STYLE))
	failures.append_array(ModularFighterUniformRuntime.set_profile_set(profile, UNIFORM_SET))
	failures.append_array(ModularFighterArmorRuntime.set_profile_armor_set(profile, ARMOR_SET))
	failures.append_array(ModularFighterArmorRuntime.set_profile_back_accessory(profile, &"back_none"))
	if not failures.is_empty():
		_fail("C68_1_RUNTIME=BLOCKED profile:%s" % ",".join(failures))
		return

	if ModularFighterArmorRuntime.profile_armor_set_id(profile) != ARMOR_SET:
		_fail("C68_1_RUNTIME=BLOCKED armor_roundtrip")
		return
	if String(profile.module_id(&"head_accessory")) != "armor_01_taijifu_guard_head_accessory":
		_fail("C68_1_RUNTIME=BLOCKED head_module")
		return
	if String(profile.module_id(&"shoulders")) != "armor_01_taijifu_guard_shoulders":
		_fail("C68_1_RUNTIME=BLOCKED shoulders_module")
		return

	failures = ModularFighterArmorRuntime.set_profile_armor_set(profile, &"armor_missing_probe")
	if failures.is_empty() or ModularFighterArmorRuntime.profile_armor_set_id(profile) != ARMOR_SET:
		_fail("C68_1_RUNTIME=BLOCKED fail_closed")
		return
	profile.clear_module(&"shoulders")
	if not ModularFighterArmorRuntime.validate_profile(profile).has("armor_profile_not_atomic_set"):
		_fail("C68_1_RUNTIME=BLOCKED partial_set_accepted")
		return
	failures = ModularFighterArmorRuntime.set_profile_armor_set(profile, ARMOR_SET)
	if not failures.is_empty():
		_fail("C68_1_RUNTIME=BLOCKED restore")
		return

	failures = ModularFighterPresetStore.save_user_preset(profile, TEST_PRESET)
	if not failures.is_empty() or not FirstPlayableSession.set_creator_preset(TEST_PRESET):
		_fail("C68_1_RUNTIME=BLOCKED preset")
		return
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("C68_1_RUNTIME=BLOCKED battle")
		return
	get_root().add_child(battle)
	for _frame in range(32):
		await process_frame
	var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter if is_instance_valid(battle.player_one) else null
	if presenter == null or not presenter.using_modular_assets():
		_fail("C68_1_RUNTIME=BLOCKED presenter")
		return
	if presenter.active_hair_style_id() != HAIR_STYLE or presenter.active_uniform_set_id() != UNIFORM_SET:
		_fail("C68_1_RUNTIME=BLOCKED prior_pack_regression")
		return

	# C68.1 candidate compatibility: attach to the real active-fight assembler
	# without promoting automatic battle activation yet.
	failures = ModularFighterArmorRuntime.assemble_profile(profile, presenter.assembler())
	if not failures.is_empty():
		_fail("C68_1_RUNTIME=BLOCKED battle_compat:%s" % ",".join(failures))
		return
	var signature := ModularFighterArmorRuntime.runtime_signature(profile, presenter.assembler())
	if not bool(signature.get("head_accessory_present", false)) or int(signature.get("head_accessory_z", -1)) != 60:
		_fail("C68_1_RUNTIME=BLOCKED head_attach")
		return
	if not bool(signature.get("shoulders_present", false)) or int(signature.get("shoulders_z", -1)) != 70:
		_fail("C68_1_RUNTIME=BLOCKED shoulders_attach")
		return
	if bool(signature.get("back_accessory_present", true)):
		_fail("C68_1_RUNTIME=BLOCKED back_none")
		return

	print("C68_1_ARMOR_SET=PASS set=armor_01_taijifu_guard head=true shoulders=true atomic=true")
	print("C68_1_BACK_ACCESSORY=PASS id=back_none deferred=true")
	print("C68_1_BATTLE_COMPAT=PASS active_fight_assembler=true auto_activation=false")
	print("C68_1_ARMOR_PACK_RUNTIME=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

# Tehkné Solutions
