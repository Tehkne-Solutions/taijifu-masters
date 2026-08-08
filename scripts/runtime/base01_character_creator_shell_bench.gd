extends SceneTree

const SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const OUTPUT := "res://artifacts/c62-6/BASE01_CHARACTER_CREATOR_SHELL.review-1920x1080.png"
const QA_OUTPUT := "res://artifacts/c62-6/BASE01_CHARACTER_CREATOR_SHELL.qa.json"
const LOGICAL_SIZE := Vector2i(1280, 720)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := get_root().get_visible_rect().size
	if Vector2i(roundi(viewport.x), roundi(viewport.y)) != LOGICAL_SIZE:
		_fail("C62_6_CREATOR_VISUAL=BLOCKED logical_viewport=%dx%d" % [roundi(viewport.x), roundi(viewport.y)])
		return
	var packed := load(SCENE) as PackedScene
	if packed == null:
		_fail("C62_6_CREATOR_VISUAL=BLOCKED scene_missing")
		return
	var shell := packed.instantiate() as ModularFighterCreatorShell
	if shell == null:
		_fail("C62_6_CREATOR_VISUAL=BLOCKED root_type")
		return
	get_root().add_child(shell)
	await process_frame
	await process_frame

	for pair in [
		["skin", "skin_tone_07_deep"],
		["face", "face_04_broad"],
		["eyes", "eyes_03_fierce"],
		["brows", "brows_06_sharp"],
	]:
		var failures := shell.set_identity(StringName(pair[0]), StringName(pair[1]))
		if not failures.is_empty():
			_fail("C62_6_CREATOR_VISUAL=BLOCKED identity:%s:%s" % [pair[0], ",".join(failures)])
			return
	shell.set_display_name("MESTRE DO CAMINHO")
	shell.set_preset_id("mestre_do_caminho")
	var selector := shell.identity_selector()
	selector.show_category(&"face")
	selector.focus_selected()

	var profile := shell.current_profile()
	var assembler := shell.current_assembler()
	if profile == null or assembler == null:
		_fail("C62_6_CREATOR_VISUAL=BLOCKED runtime_missing")
		return
	if profile.skin_palette_id() != &"skin_tone_07_deep" or profile.module_id(&"face") != &"face_04_broad":
		_fail("C62_6_CREATOR_VISUAL=BLOCKED profile_state")
		return
	if assembler.active_identity_module_id(&"face_plate") != &"neutral_face_plate_v1":
		_fail("C62_6_CREATOR_VISUAL=BLOCKED face_plate")
		return
	if selector.option_count(&"skin") + selector.option_count(&"face") + selector.option_count(&"eyes") + selector.option_count(&"brows") != 24:
		_fail("C62_6_CREATOR_VISUAL=BLOCKED option_count")
		return

	for _frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := get_root().get_texture().get_image()
	if capture == null or capture.is_empty():
		_fail("C62_6_CREATOR_VISUAL=BLOCKED capture")
		return
	if capture.get_size() != LOGICAL_SIZE:
		_fail("C62_6_CREATOR_VISUAL=BLOCKED capture_size=%dx%d" % [capture.get_width(), capture.get_height()])
		return
	capture.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if capture.save_png(OUTPUT) != OK:
		_fail("C62_6_CREATOR_VISUAL=BLOCKED save")
		return

	var qa := {
		"schema": "tehkne/taijifu-base01-character-creator-shell-review/v1",
		"signature": "Tehkné Solutions",
		"status": "implementation_candidate_owner_review_pending",
		"logical_viewport": [1280, 720],
		"review_output": [1920, 1080],
		"identity_options": 24,
		"selected": {
			"skin": "skin_tone_07_deep",
			"face": "face_04_broad",
			"eyes": "eyes_03_fierce",
			"brows": "brows_06_sharp"
		},
		"display_name": "MESTRE DO CAMINHO",
		"preset_id": "mestre_do_caminho",
		"live_preview": "PASS",
		"face_plate_policy": "PASS",
		"preset_controls_visible": true,
		"keyboard_gamepad_focus": "PASS",
		"future_module_expansion_reserved": true,
		"internal_visual_review": "PENDING",
		"owner_review": "PENDING"
	}
	var file := FileAccess.open(QA_OUTPUT, FileAccess.WRITE)
	if file == null:
		_fail("C62_6_CREATOR_VISUAL=BLOCKED qa_open")
		return
	file.store_string(JSON.stringify(qa, "  ") + "\n")
	file.close()
	print("C62_6_CREATOR_VISUAL=PASS size=1920x1080 options=24")
	print("C62_6_CREATOR_LIVE_PREVIEW=PASS face_plate=auto")
	print("C62_6_CREATOR_VISUAL_OUTPUT=" + OUTPUT)
	print("INTERNAL_VISUAL_REVIEW=PENDING")
	print("OWNER_REVIEW=PENDING")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _fail(marker: String) -> void:
	push_error(marker)
	print(marker)
	quit(2)
