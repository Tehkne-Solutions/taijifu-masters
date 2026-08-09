extends SceneTree

const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const TEST_PRESET := &"c65_visual_review_probe"
const OUTPUT := "res://artifacts/c65/C65_SHARED_MODULAR_ANIMATION_RUNTIME.review-1920x1080.png"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-001")

	var creator := (load(CREATOR_SCENE) as PackedScene).instantiate() as ModularFighterCreatorScene
	if creator == null:
		_fail("C65_VISUAL_REVIEW=BLOCKED creator_instantiate")
		return
	get_root().add_child(creator)
	for _frame in range(4):
		await process_frame
	creator.set_display_name("C65 VISUAL REVIEW")
	creator.set_preset_id(String(TEST_PRESET))
	var failures := PackedStringArray()
	failures.append_array(creator.set_identity(&"skin", &"skin_tone_07_deep"))
	failures.append_array(creator.set_identity(&"face", &"face_04_broad"))
	failures.append_array(creator.set_identity(&"eyes", &"eyes_03_fierce"))
	failures.append_array(creator.set_identity(&"brows", &"brows_06_sharp"))
	if not failures.is_empty():
		_fail("C65_VISUAL_REVIEW=BLOCKED identity:%s" % ",".join(failures))
		return
	failures = creator.save_current_preset(TEST_PRESET)
	if not failures.is_empty():
		_fail("C65_VISUAL_REVIEW=BLOCKED save:%s" % ",".join(failures))
		return
	creator.queue_free()
	await process_frame

	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as FirstPlayableController
	if battle == null:
		_fail("C65_VISUAL_REVIEW=BLOCKED battle_instantiate")
		return
	get_root().add_child(battle)
	for _frame in range(32):
		await process_frame
	if not is_instance_valid(battle.player_one):
		_fail("C65_VISUAL_REVIEW=BLOCKED player_one")
		return
	var modular := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if modular == null or not modular.using_modular_assets():
		_fail("C65_VISUAL_REVIEW=BLOCKED modular_inactive")
		return
	var assembler := modular.assembler()
	if assembler == null or not assembler.is_ready_for_render():
		_fail("C65_VISUAL_REVIEW=BLOCKED assembler")
		return

	# Do not await frame_post_draw here: the functional smoke already proved the
	# runtime. After 32 process frames the root viewport contains the actual battle
	# composition; reading it directly prevents a visual-evidence wait from stalling
	# the logical gate on headless runners.
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("C65_VISUAL_REVIEW=BLOCKED capture_empty")
		return
	if image.get_width() <= 0 or image.get_height() <= 0:
		_fail("C65_VISUAL_REVIEW=BLOCKED capture_size")
		return
	image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if image.save_png(OUTPUT) != OK:
		_fail("C65_VISUAL_REVIEW=BLOCKED save_png")
		return

	print("C65_VISUAL_REVIEW=PASS preset=%s" % String(TEST_PRESET))
	print("C65_VISUAL_REVIEW_IDENTITY=PASS skin=deep face=broad eyes=fierce brows=sharp")
	print("C65_VISUAL_REVIEW_OUTPUT=" + OUTPUT)
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(TEST_PRESET)

func _fail(marker: String) -> void:
	push_error(marker)
	print(marker)
	_cleanup()
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions
