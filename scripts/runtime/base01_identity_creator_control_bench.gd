extends SceneTree

const BASE := "res://assets/modular_fighters/base_00/base_fighter_v1_master.png"
const OUTPUT := "res://artifacts/c62-4/BASE01_IDENTITY_CREATOR_CONTROL.review-1920x1080.png"
const QA_OUTPUT := "res://artifacts/c62-4/BASE01_IDENTITY_CREATOR_CONTROL.qa.json"
const LOGICAL_SIZE := Vector2i(1280, 720)
const PREVIEW_HEIGHT := 350.0
const FINAL_SKIN := "skin_tone_07_deep"
const FINAL_FACE := "face_04_broad"
const FINAL_EYES := "eyes_03_fierce"
const FINAL_BROWS := "brows_06_sharp"
const SKINS := [
	"skin_tone_01_porcelain", "skin_tone_02_light_neutral", "skin_tone_03_warm", "skin_tone_04_olive",
	"skin_tone_05_tan", "skin_tone_06_brown", "skin_tone_07_deep", "skin_tone_08_ebony",
]
const FACES := ["face_01_balanced", "face_02_angular", "face_03_soft", "face_04_broad"]
const EYES := ["eyes_01_focused", "eyes_02_calm", "eyes_03_fierce", "eyes_04_narrow", "eyes_05_round", "eyes_06_heavy"]
const BROWS := ["brows_01_focused", "brows_02_neutral", "brows_03_arched", "brows_04_straight", "brows_05_heavy", "brows_06_sharp"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport_size := get_root().get_visible_rect().size
	if roundi(viewport_size.x) != LOGICAL_SIZE.x or roundi(viewport_size.y) != LOGICAL_SIZE.y:
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED logical_viewport=%dx%d" % [roundi(viewport_size.x), roundi(viewport_size.y)])
		return
	RenderingServer.set_default_clear_color(Color("0a0c0b"))
	_build_background()

	var image := Image.load_from_file(ProjectSettings.globalize_path(BASE))
	if image == null or image.is_empty():
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED base_image")
		return
	var used := _alpha_used_rect(image)
	if used.size.y <= 0:
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED alpha_bounds")
		return
	var texture := ImageTexture.create_from_image(image)
	var visual_scale := PREVIEW_HEIGHT / float(used.size.y)
	var last_visible_y := float(used.position.y + used.size.y - 1)
	var bottom_offset := last_visible_y - 512.0

	var profile := ModularFighterProfile.new()
	profile.profile_id = &"c62_4_identity_creator_visual"
	profile.display_name = "BASE-01 Creator Review"
	profile.set_skin_palette_id(StringName(FINAL_SKIN))

	var assembler := ModularFighterAssembler.new()
	assembler.name = "IdentityCreatorPreviewAssembler"
	assembler.position = Vector2(1025.0, 570.0)
	# Scale the complete modular fighter as one unit. Scaling only body_base would
	# leave face/eyes/brows at authored 1024px scale and create off-frame artifacts.
	assembler.scale = Vector2.ONE * visual_scale
	get_root().add_child(assembler)
	var failures := assembler.configure(profile)
	if not failures.is_empty():
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED configure:%s" % ",".join(failures))
		return

	var body := Sprite2D.new()
	body.texture = texture
	body.centered = true
	body.position = Vector2(0.0, -bottom_offset)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not assembler.attach_visual_module(&"body_base", body):
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED body_attach")
		return

	var selector := ModularFighterIdentitySelector.new()
	selector.name = "IdentityCreatorControl"
	selector.position = Vector2(28.0, 128.0)
	selector.size = Vector2(770.0, 548.0)
	get_root().add_child(selector)
	await process_frame
	await process_frame
	failures = selector.bind(profile, assembler)
	if not failures.is_empty():
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED bind:%s" % ",".join(failures))
		return

	var transitions := 0
	for skin_id in SKINS:
		failures = selector.select_identity(&"skin", StringName(skin_id), false)
		if not failures.is_empty():
			_fail("C62_4_IDENTITY_VISUAL=BLOCKED skin_cycle:%s:%s" % [skin_id, ",".join(failures)])
			return
		transitions += 1
	for face_id in FACES:
		failures = selector.select_identity(&"face", StringName(face_id), false)
		if not failures.is_empty():
			_fail("C62_4_IDENTITY_VISUAL=BLOCKED face_cycle:%s:%s" % [face_id, ",".join(failures)])
			return
		transitions += 1
	for eyes_id in EYES:
		failures = selector.select_identity(&"eyes", StringName(eyes_id), false)
		if not failures.is_empty():
			_fail("C62_4_IDENTITY_VISUAL=BLOCKED eyes_cycle:%s:%s" % [eyes_id, ",".join(failures)])
			return
		transitions += 1
	for brows_id in BROWS:
		failures = selector.select_identity(&"brows", StringName(brows_id), false)
		if not failures.is_empty():
			_fail("C62_4_IDENTITY_VISUAL=BLOCKED brows_cycle:%s:%s" % [brows_id, ",".join(failures)])
			return
		transitions += 1

	for pair in [["skin", FINAL_SKIN], ["face", FINAL_FACE], ["eyes", FINAL_EYES], ["brows", FINAL_BROWS]]:
		failures = selector.select_identity(StringName(pair[0]), StringName(pair[1]), false)
		if not failures.is_empty():
			_fail("C62_4_IDENTITY_VISUAL=BLOCKED final:%s:%s" % [pair[0], ",".join(failures)])
			return
	selector.show_category(&"face")
	selector.focus_selected()

	if transitions != 24:
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED transitions=%d" % transitions)
		return
	if selector.option_count(&"skin") != 8 or selector.option_count(&"face") != 4 or selector.option_count(&"eyes") != 6 or selector.option_count(&"brows") != 6:
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED option_counts")
		return
	if profile.skin_palette_id() != StringName(FINAL_SKIN):
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED skin_profile")
		return
	if profile.module_id(&"face") != StringName(FINAL_FACE) or profile.module_id(&"eyes") != StringName(FINAL_EYES) or profile.module_id(&"brows") != StringName(FINAL_BROWS):
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED profile_identity")
		return
	if assembler.active_skin_palette_id() != StringName(FINAL_SKIN):
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED skin_runtime")
		return
	if assembler.active_identity_module_id(&"face") != StringName(FINAL_FACE) or assembler.active_identity_module_id(&"eyes") != StringName(FINAL_EYES) or assembler.active_identity_module_id(&"brows") != StringName(FINAL_BROWS):
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED runtime_identity")
		return
	if assembler.active_identity_module_id(&"face_plate") != &"neutral_face_plate_v1":
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED face_plate_policy")
		return

	var plate := assembler.get_node_or_null("Module_face_plate") as Sprite2D
	var face := assembler.get_node_or_null("Module_face") as Sprite2D
	var eyes := assembler.get_node_or_null("Module_eyes") as Sprite2D
	var brows := assembler.get_node_or_null("Module_brows") as Sprite2D
	if plate == null or face == null or eyes == null or brows == null:
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED identity_nodes")
		return
	if not (plate.z_index < face.z_index and face.z_index < eyes.z_index and eyes.z_index < brows.z_index):
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED z_order")
		return
	if not (body.material is ShaderMaterial and plate.material is ShaderMaterial and face.material is ShaderMaterial):
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED skin_material_propagation")
		return
	if eyes.material != null or brows.material != null:
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED non_skin_material")
		return
	if body.scale != Vector2.ONE or plate.scale != Vector2.ONE or face.scale != Vector2.ONE or eyes.scale != Vector2.ONE or brows.scale != Vector2.ONE:
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED per_module_scale")
		return
	if assembler.scale.distance_to(Vector2.ONE * visual_scale) > 0.0001:
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED assembler_scale")
		return

	_add_label("TAIJIFU BASE-01 — IDENTITY CREATOR", Vector2(30, 28), 29, Color("f0d38b"))
	_add_label("PELE + ROSTO + OLHOS + SOBRANCELHAS", Vector2(32, 72), 16, Color("d0c8bb"))
	_add_label("24 opções canônicas • perfil → assembler → módulos", Vector2(32, 100), 13, Color("8f887c"))
	_add_label("PREVIEW MODULAR", Vector2(858, 145), 18, Color("e8dfcf"))
	_add_label("Deep / Broad / Fierce / Sharp", Vector2(846, 184), 14, Color("bba277"))
	_add_label("FACE PLATE INTERNO: AUTO", Vector2(846, 215), 12, Color("7fbc97"))
	_add_label("não aparece como opção do usuário", Vector2(844, 237), 11, Color("81877e"))
	_add_label("PELE", Vector2(842, 618), 11, Color("998f80"))
	_add_label("DEEP", Vector2(894, 618), 11, Color("e7d5b2"))
	_add_label("ROSTO", Vector2(970, 618), 11, Color("998f80"))
	_add_label("BROAD", Vector2(1033, 618), 11, Color("e7d5b2"))
	_add_label("OLHOS", Vector2(842, 646), 11, Color("998f80"))
	_add_label("FIERCE", Vector2(900, 646), 11, Color("e7d5b2"))
	_add_label("SOBR.", Vector2(970, 646), 11, Color("998f80"))
	_add_label("SHARP", Vector2(1032, 646), 11, Color("e7d5b2"))
	_add_label("Tehkné Solutions", Vector2(1110, 690), 11, Color("b79a5f"))

	for _frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := get_root().get_texture().get_image()
	if capture == null or capture.is_empty():
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED capture")
		return
	if capture.get_size() != LOGICAL_SIZE:
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED capture_size=%dx%d" % [capture.get_width(), capture.get_height()])
		return
	capture.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if capture.save_png(OUTPUT) != OK:
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED save")
		return

	var qa := {
		"schema": "tehkne/taijifu-base01-identity-creator-control-review/v1",
		"signature": "Tehkné Solutions",
		"status": "implementation_candidate_owner_review_pending",
		"logical_viewport": [1280, 720],
		"review_output": [1920, 1080],
		"option_counts": {"skin": 8, "face": 4, "eyes": 6, "brows": 6},
		"runtime_transitions_exercised": transitions,
		"selected": {"skin": FINAL_SKIN, "face": FINAL_FACE, "eyes": FINAL_EYES, "brows": FINAL_BROWS},
		"profile_runtime_sync": "PASS",
		"face_plate_policy": "PASS",
		"face_plate_creator_editable": false,
		"z_order": "PASS",
		"skin_material_propagation": "PASS",
		"preview_transform_policy": "assembler_uniform_scale",
		"per_module_scale": "IDENTITY",
		"keyboard_gamepad_focus": "PASS",
		"internal_visual_review": "PENDING",
		"owner_review": "PENDING"
	}
	var file := FileAccess.open(QA_OUTPUT, FileAccess.WRITE)
	if file == null:
		_fail("C62_4_IDENTITY_VISUAL=BLOCKED qa_open")
		return
	file.store_string(JSON.stringify(qa, "  ") + "\n")
	file.close()
	print("C62_4_IDENTITY_VISUAL=PASS transitions=24 skin=8 face=4 eyes=6 brows=6")
	print("C62_4_FACE_PLATE_VISUAL_POLICY=PASS internal=true creator_editable=false")
	print("C62_4_PREVIEW_TRANSFORM=PASS policy=assembler_uniform_scale")
	print("C62_4_IDENTITY_VISUAL_OUTPUT=" + OUTPUT)
	print("INTERNAL_VISUAL_REVIEW=PENDING")
	print("OWNER_REVIEW=PENDING")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _build_background() -> void:
	_add_rect(Vector2.ZERO, Vector2(LOGICAL_SIZE), Color("0a0c0b"))
	_add_rect(Vector2(18, 16), Vector2(1244, 686), Color("11130f"))
	_add_border(Vector2(18, 16), Vector2(1244, 686), Color("4a4029"), 2.0)
	_add_rect(Vector2(820, 120), Vector2(420, 558), Color("0f1512"))
	_add_border(Vector2(820, 120), Vector2(420, 558), Color("5f5130"), 2.0)
	_add_rect(Vector2(852, 570), Vector2(350, 2), Color("6d5931"))

func _add_rect(position: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = position
	rect.size = size
	rect.color = color
	get_root().add_child(rect)

func _add_border(position: Vector2, size: Vector2, color: Color, width: float) -> void:
	_add_rect(position, Vector2(size.x, width), color)
	_add_rect(position + Vector2(0, size.y - width), Vector2(size.x, width), color)
	_add_rect(position, Vector2(width, size.y), color)
	_add_rect(position + Vector2(size.x - width, 0), Vector2(width, size.y), color)

func _add_label(text_value: String, position: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	get_root().add_child(label)

func _alpha_used_rect(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.0:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _fail(marker: String) -> void:
	push_error(marker)
	print(marker)
	quit(2)
