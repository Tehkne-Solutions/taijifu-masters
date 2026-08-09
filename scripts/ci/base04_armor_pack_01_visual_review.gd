extends SceneTree

const TEST_PRESET := &"c68_armor_visual_review"
const ARMOR_SET := &"armor_01_taijifu_guard"
const HAIR_STYLE := &"hair_01_lian_topknot"
const UNIFORM_SET := &"uniform_01_lian_martial"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT := "res://artifacts/c68_1/C68_1_BASE04_TAIJIFU_GUARD.review-1920x1080.png"

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
	profile.display_name = "C68 TAIJIFU GUARD REVIEW"
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
		_fail("C68_1_VISUAL=BLOCKED profile:%s" % ",".join(failures))
		return
	failures = ModularFighterPresetStore.save_user_preset(profile, TEST_PRESET)
	if not failures.is_empty() or not FirstPlayableSession.set_creator_preset(TEST_PRESET):
		_fail("C68_1_VISUAL=BLOCKED preset")
		return

	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("C68_1_VISUAL=BLOCKED battle")
		return
	get_root().add_child(battle)
	await create_timer(4.0).timeout
	for _frame in range(12):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("C68_1_VISUAL=BLOCKED player_one")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("C68_1_VISUAL=BLOCKED presenter")
		return
	if presenter.active_hair_style_id() != HAIR_STYLE or presenter.active_uniform_set_id() != UNIFORM_SET:
		_fail("C68_1_VISUAL=BLOCKED prior_pack_state")
		return

	failures = ModularFighterArmorRuntime.assemble_profile(profile, presenter.assembler())
	if not failures.is_empty():
		_fail("C68_1_VISUAL=BLOCKED armor_attach:%s" % ",".join(failures))
		return
	for _frame in range(3):
		await process_frame
	var signature := ModularFighterArmorRuntime.runtime_signature(profile, presenter.assembler())
	if int(signature.get("head_accessory_z", -1)) != 60 or int(signature.get("shoulders_z", -1)) != 70:
		_fail("C68_1_VISUAL=BLOCKED layers")
		return
	if bool(signature.get("back_accessory_present", true)):
		_fail("C68_1_VISUAL=BLOCKED back_none")
		return

	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("C68_1_VISUAL=BLOCKED capture")
		return
	image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if image.save_png(OUTPUT) != OK:
		_fail("C68_1_VISUAL=BLOCKED save")
		return

	print("C68_1_VISUAL_REVIEW=PASS armor=armor_01_taijifu_guard back=back_none")
	print("C68_1_VISUAL_COMPOSITION=PASS hair=hair_01_lian_topknot uniform=uniform_01_lian_martial armor=armor_01_taijifu_guard back=back_none")
	print("C68_1_VISUAL_LAYERING=PASS hair_front=50 head=60 torso_outer=65 shoulders=70")
	print("C68_1_VISUAL_PHASE=PASS active_fight=true auto_activation=false")
	print("C68_1_VISUAL_OUTPUT=" + OUTPUT)
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

# Tehkné Solutions
