extends SceneTree

const MENU_SCENE := "res://scenes/vertical_slice/first_playable_menu.tscn"
const OUTPUT := "res://artifacts/c62-7/BASE01_CREATOR_MENU_ENTRY.review-1920x1080.png"
const QA_OUTPUT := "res://artifacts/c62-7/BASE01_CREATOR_MENU_ENTRY.qa.json"
const LOGICAL_SIZE := Vector2i(1280, 720)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := get_root().get_visible_rect().size
	if Vector2i(roundi(viewport.x), roundi(viewport.y)) != LOGICAL_SIZE:
		_fail("C62_7_MENU_VISUAL=BLOCKED logical_viewport=%dx%d" % [roundi(viewport.x), roundi(viewport.y)])
		return
	var packed := load(MENU_SCENE) as PackedScene
	if packed == null:
		_fail("C62_7_MENU_VISUAL=BLOCKED menu_scene")
		return
	var menu := packed.instantiate() as FirstPlayableMenuController
	if menu == null:
		_fail("C62_7_MENU_VISUAL=BLOCKED menu_root")
		return
	get_root().add_child(menu)
	await process_frame
	await process_frame

	var signature := menu.flow_signature()
	if menu.play_button == null or menu.play_button.disabled:
		_fail("C62_7_MENU_VISUAL=BLOCKED play")
		return
	if menu.creator_button == null or menu.creator_button.disabled:
		_fail("C62_7_MENU_VISUAL=BLOCKED creator")
		return
	if menu.creator_button.text != "CRIAR LUTADOR":
		_fail("C62_7_MENU_VISUAL=BLOCKED creator_label")
		return
	if StringName(signature.get("main_action", &"")) != &"play_vs_ai":
		_fail("C62_7_MENU_VISUAL=BLOCKED main_action")
		return
	if String(signature.get("creator_entry_role", "")) != "secondary_non_blocking":
		_fail("C62_7_MENU_VISUAL=BLOCKED creator_role")
		return
	if not bool(signature.get("quick_game_path_unchanged", false)):
		_fail("C62_7_MENU_VISUAL=BLOCKED quick_game")
		return
	menu.creator_button.grab_focus()
	await process_frame
	if get_root().gui_get_focus_owner() != menu.creator_button:
		_fail("C62_7_MENU_VISUAL=BLOCKED creator_focus")
		return

	for _frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := get_root().get_texture().get_image()
	if capture == null or capture.is_empty():
		_fail("C62_7_MENU_VISUAL=BLOCKED capture")
		return
	if capture.get_size() != LOGICAL_SIZE:
		_fail("C62_7_MENU_VISUAL=BLOCKED capture_size=%dx%d" % [capture.get_width(), capture.get_height()])
		return
	capture.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if capture.save_png(OUTPUT) != OK:
		_fail("C62_7_MENU_VISUAL=BLOCKED save")
		return

	var qa := {
		"schema": "tehkne/taijifu-base01-creator-menu-entry-review/v1",
		"signature": "Tehkné Solutions",
		"status": "implementation_candidate_owner_review_pending",
		"logical_viewport": [1280, 720],
		"review_output": [1920, 1080],
		"main_action": "play_vs_ai",
		"play_primary": true,
		"creator_entry": "CRIAR LUTADOR",
		"creator_role": "secondary_non_blocking",
		"creator_focus_review": "PASS",
		"quick_game_path_unchanged": "PASS",
		"participant_form_absent": menu.get_node_or_null("Content/Participant") == null,
		"legacy_prototype_absent": menu.get_node_or_null("Content/Actions/PrototypeButton") == null,
		"keyboard_shortcut": "C",
		"internal_visual_review": "PENDING",
		"owner_review": "PENDING"
	}
	var file := FileAccess.open(QA_OUTPUT, FileAccess.WRITE)
	if file == null:
		_fail("C62_7_MENU_VISUAL=BLOCKED qa_open")
		return
	file.store_string(JSON.stringify(qa, "  ") + "\n")
	file.close()
	print("C62_7_MENU_VISUAL=PASS size=1920x1080")
	print("C62_7_CREATOR_ENTRY_VISUAL=PASS focus=creator role=secondary_non_blocking")
	print("C62_7_QUICK_GAME_VISUAL=PASS play_primary=true")
	print("C62_7_MENU_VISUAL_OUTPUT=" + OUTPUT)
	print("INTERNAL_VISUAL_REVIEW=PENDING")
	print("OWNER_REVIEW=PENDING")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _fail(marker: String) -> void:
	push_error(marker)
	print(marker)
	quit(2)
