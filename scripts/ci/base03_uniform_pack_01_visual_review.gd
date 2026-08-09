extends SceneTree

const TEST_PRESET := &"c67_uniform_visual_review"
const UNIFORM_SET := &"uniform_01_lian_martial"
const HAIR_STYLE := &"hair_01_lian_topknot"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT := "res://artifacts/c67_1/C67_1_BASE03_LIAN_MARTIAL_UNIFORM.review-1920x1080.png"
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

	var profile := ModularFighterProfile.new()
	profile.profile_id = TEST_PRESET
	profile.display_name = "C67 LIAN UNIFORM REVIEW"
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_skin_palette_id(&"skin_tone_03_warm")
	var failures := profile.set_base01_identity_module(&"face", &"face_01_balanced")
	failures.append_array(profile.set_base01_identity_module(&"eyes", &"eyes_01_focused"))
	failures.append_array(profile.set_base01_identity_module(&"brows", &"brows_01_focused"))
	failures.append_array(ModularFighterHairRuntime.set_profile_style(profile, HAIR_STYLE))
	failures.append_array(ModularFighterUniformRuntime.set_profile_set(profile, UNIFORM_SET))
	if not failures.is_empty():
		_fail("C67_1_VISUAL=BLOCKED profile:%s" % ",".join(failures))
		return
	failures = ModularFighterPresetStore.save_user_preset(profile, TEST_PRESET)
	if not failures.is_empty() or not FirstPlayableSession.set_creator_preset(TEST_PRESET):
		_fail("C67_1_VISUAL=BLOCKED preset")
		return

	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("C67_1_VISUAL=BLOCKED battle")
		return
	get_root().add_child(battle)

	# Capture active fight after countdown, matching C65/C66 review discipline.
	await create_timer(4.0).timeout
	for _frame in range(12):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("C67_1_VISUAL=BLOCKED player_one")
		return
	var presenter := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if presenter == null or not presenter.using_modular_assets():
		_fail("C67_1_VISUAL=BLOCKED presenter")
		return
	if presenter.active_uniform_set_id() != UNIFORM_SET or presenter.active_hair_style_id() != HAIR_STYLE:
		_fail("C67_1_VISUAL=BLOCKED active_pack")
		return
	var assembler := presenter.assembler()
	for slot_name in EXPECTED_Z.keys():
		var node := assembler.get_node_or_null("Module_%s" % slot_name) as Sprite2D
		if node == null or node.z_index != int(EXPECTED_Z[slot_name]):
			_fail("C67_1_VISUAL=BLOCKED layer:%s" % slot_name)
			return
	if assembler.get_node_or_null("Module_torso_inner") != null or assembler.get_node_or_null("Module_hands") != null:
		_fail("C67_1_VISUAL=BLOCKED empty_slots")
		return

	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("C67_1_VISUAL=BLOCKED capture")
		return
	image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if image.save_png(OUTPUT) != OK:
		_fail("C67_1_VISUAL=BLOCKED save")
		return

	print("C67_1_VISUAL_REVIEW=PASS set=uniform_01_lian_martial hair=hair_01_lian_topknot")
	print("C67_1_VISUAL_LAYERING=PASS torso_outer=65 arms=12 waist=14 legs=11 feet=12")
	print("C67_1_VISUAL_PHASE=PASS active_fight=true")
	print("C67_1_VISUAL_OUTPUT=" + OUTPUT)
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

# Tehkné Solutions
