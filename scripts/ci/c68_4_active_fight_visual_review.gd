extends SceneTree

const TEST_PRESET := &"c68_4_active_fight"
const HAIR_STYLE := &"hair_01_lian_topknot"
const UNIFORM_SET := &"uniform_01_lian_martial"
const ARMOR_SET := &"armor_01_taijifu_guard"
const BACK_ACCESSORY := &"back_01_guardian_panel"
const WEAPON_BACK := &"sheath_lian_wu_blue"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT := "res://artifacts/c68_4/C68_4_ACTIVE_FIGHT.review-1920x1080.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-C68-4")

	var profile := ModularFighterProfile.new()
	profile.profile_id = TEST_PRESET
	profile.display_name = "C68.4 ACTIVE FIGHT REVIEW"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_skin_palette_id(&"skin_tone_03_warm")
	var failures := profile.set_base01_identity_module(&"face", &"face_01_balanced")
	failures.append_array(profile.set_base01_identity_module(&"eyes", &"eyes_01_focused"))
	failures.append_array(profile.set_base01_identity_module(&"brows", &"brows_01_focused"))
	failures.append_array(ModularFighterHairRuntime.set_profile_style(profile, HAIR_STYLE))
	failures.append_array(ModularFighterUniformRuntime.set_profile_set(profile, UNIFORM_SET))
	failures.append_array(ModularFighterArmorRuntime.set_profile_armor_set(profile, ARMOR_SET))
	failures.append_array(ModularFighterArmorRuntime.set_profile_back_accessory(profile, BACK_ACCESSORY))
	profile.set_module(&"weapon_back", WEAPON_BACK)
	if not failures.is_empty():
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED profile:%s" % ",".join(failures))
		return

	failures = ModularFighterPresetStore.save_user_preset(profile, TEST_PRESET)
	if not failures.is_empty() or not FirstPlayableSession.set_creator_preset(TEST_PRESET):
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED preset")
		return

	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED battle")
		return
	get_root().add_child(battle)
	await create_timer(4.0).timeout
	for _frame in range(12):
		await process_frame

	if not is_instance_valid(battle.player_one):
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED player_one")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED presenter")
		return
	if presenter.active_hair_style_id() != HAIR_STYLE or presenter.active_uniform_set_id() != UNIFORM_SET:
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED prior_pack_state")
		return
	if presenter.active_armor_set_id() != ARMOR_SET or presenter.active_back_accessory_id() != BACK_ACCESSORY:
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED armor_back_state")
		return
	if presenter.active_weapon_back_id() != WEAPON_BACK:
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED weapon_back_state")
		return

	var assembler := presenter.assembler()
	var equipment_sig := ModularFighterEquipmentRuntime.runtime_signature(profile, assembler)
	var armor_sig := ModularFighterArmorRuntime.runtime_signature(profile, assembler)
	var hair_sig := ModularFighterHairRuntime.runtime_signature(profile, assembler)
	var weapon_node = equipment_sig.get("nodes", {}).get("weapon_back", {})
	if not bool(weapon_node.get("present", false)) or int(weapon_node.get("z", -1)) != 3:
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED weapon_back_runtime")
		return
	if not bool(armor_sig.get("back_accessory_present", false)) or int(armor_sig.get("back_accessory_z", -1)) != 4:
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED back_accessory_runtime")
		return
	if not bool(hair_sig.get("hair_back_present", false)) or int(hair_sig.get("hair_back_z", -1)) != 5:
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED hair_back_runtime")
		return

	var handoff_value = battle.player_one.get_meta("creator_battle_handoff", {})
	if not (handoff_value is Dictionary):
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED battle_handoff")
		return
	if String(handoff_value.get("weapon_back_id", "")) != String(WEAPON_BACK):
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED handoff_weapon_back")
		return
	if String(handoff_value.get("back_accessory_id", "")) != String(BACK_ACCESSORY):
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED handoff_back_accessory")
		return

	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED capture")
		return
	image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if image.save_png(OUTPUT) != OK:
		_fail("C68_4_ACTIVE_FIGHT=BLOCKED save")
		return

	print("C68_4_ACTIVE_FIGHT=PASS weapon_back=sheath_lian_wu_blue back=back_01_guardian_panel auto_activation=true handoff=true")
	print("C68_4_ACTIVE_LAYERING=PASS weapon_back=3 back_accessory=4 hair_back=5")
	print("C68_4_ACTIVE_COMPOSITION=PASS hair=hair_01_lian_topknot uniform=uniform_01_lian_martial armor=armor_01_taijifu_guard")
	print("C68_4_ACTIVE_OUTPUT=" + OUTPUT)
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
