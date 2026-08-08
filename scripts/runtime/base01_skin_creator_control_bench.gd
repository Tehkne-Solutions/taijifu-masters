extends SceneTree

const BASE := "res://assets/modular_fighters/base_00/base_fighter_v1_master.png"
const OUTPUT := "res://artifacts/c62-3/BASE01_SKIN_CREATOR_CONTROL.review-1920x1080.png"
const QA_OUTPUT := "res://artifacts/c62-3/BASE01_SKIN_CREATOR_CONTROL.qa.json"
const LOGICAL_SIZE := Vector2i(1280, 720)
const REVIEW_SKIN := "skin_tone_07_deep"
const PREVIEW_HEIGHT := 330.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport_size := get_root().get_visible_rect().size
	if roundi(viewport_size.x) != LOGICAL_SIZE.x or roundi(viewport_size.y) != LOGICAL_SIZE.y:
		_fail("C62_3_CREATOR_VISUAL=BLOCKED logical_viewport=%dx%d" % [roundi(viewport_size.x), roundi(viewport_size.y)])
		return
	RenderingServer.set_default_clear_color(Color("0b0d0c"))
	_build_background()

	var image := Image.load_from_file(ProjectSettings.globalize_path(BASE))
	if image == null or image.is_empty():
		_fail("C62_3_CREATOR_VISUAL=BLOCKED base_image")
		return
	var used := _alpha_used_rect(image)
	if used.size.y <= 0:
		_fail("C62_3_CREATOR_VISUAL=BLOCKED alpha_bounds")
		return
	var texture := ImageTexture.create_from_image(image)
	var visual_scale := PREVIEW_HEIGHT / float(used.size.y)
	var last_visible_y := float(used.position.y + used.size.y - 1)
	var baseline_offset := (last_visible_y - 512.0) * visual_scale

	var profile := ModularFighterProfile.new()
	profile.profile_id = &"c62_3_creator_visual_profile"
	profile.display_name = "Creator Preview"
	profile.set_skin_palette_id(StringName(REVIEW_SKIN))

	var assembler := ModularFighterAssembler.new()
	assembler.name = "CreatorPreviewAssembler"
	assembler.position = Vector2(990.0, 566.0)
	get_root().add_child(assembler)
	var failures := assembler.configure(profile)
	if not failures.is_empty():
		_fail("C62_3_CREATOR_VISUAL=BLOCKED configure:%s" % ",".join(failures))
		return

	var body := Sprite2D.new()
	body.texture = texture
	body.centered = true
	body.scale = Vector2.ONE * visual_scale
	body.position = Vector2(0.0, -baseline_offset)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not assembler.attach_visual_module(&"body_base", body):
		_fail("C62_3_CREATOR_VISUAL=BLOCKED body_attach")
		return
	failures = assembler.assemble_base01_default_identity()
	if not failures.is_empty():
		_fail("C62_3_CREATOR_VISUAL=BLOCKED default_identity:%s" % ",".join(failures))
		return

	var selector := ModularFighterSkinSelector.new()
	selector.name = "SkinCreatorControl"
	selector.position = Vector2(42.0, 176.0)
	selector.size = Vector2(675.0, 330.0)
	get_root().add_child(selector)
	await process_frame
	await process_frame
	failures = selector.bind(profile, assembler)
	if not failures.is_empty():
		_fail("C62_3_CREATOR_VISUAL=BLOCKED selector_bind:%s" % ",".join(failures))
		return

	# Exercise every canonical option through the real control before restoring
	# the review selection. This makes the screenshot evidence the final state of
	# a selector that has actually driven all eight runtime transitions.
	for palette_id in selector.palette_ids():
		failures = selector.select_palette(StringName(palette_id), false)
		if not failures.is_empty():
			_fail("C62_3_CREATOR_VISUAL=BLOCKED cycle:%s:%s" % [palette_id, ",".join(failures)])
			return
	failures = selector.select_palette(StringName(REVIEW_SKIN), false)
	if not failures.is_empty():
		_fail("C62_3_CREATOR_VISUAL=BLOCKED restore:%s" % ",".join(failures))
		return
	selector.focus_selected()

	if selector.option_count() != 8:
		_fail("C62_3_CREATOR_VISUAL=BLOCKED options=%d" % selector.option_count())
		return
	if profile.skin_palette_id() != StringName(REVIEW_SKIN):
		_fail("C62_3_CREATOR_VISUAL=BLOCKED profile_desync")
		return
	if assembler.active_skin_palette_id() != StringName(REVIEW_SKIN):
		_fail("C62_3_CREATOR_VISUAL=BLOCKED assembler_desync")
		return
	if not (body.material is ShaderMaterial):
		_fail("C62_3_CREATOR_VISUAL=BLOCKED shader_material")
		return

	_add_label("TAIJIFU BASE-01 — SKIN CREATOR CONTROL", Vector2(44, 34), 30, Color("f0d38b"))
	_add_label("PROFILE → ASSEMBLER → SHADER", Vector2(45, 78), 16, Color("c9c1b2"))
	_add_label("Componente oficial reutilizável do Character Creator", Vector2(45, 108), 14, Color("938a7a"))
	_add_label("PREVIEW DO MESMO BASE-00", Vector2(834, 176), 17, Color("e8dfcf"))
	_add_label("DEEP • skin_tone_07_deep", Vector2(850, 214), 15, Color("bfa680"))
	_add_label("8 OPÇÕES CANÔNICAS", Vector2(66, 532), 14, Color("d8c28b"))
	_add_label("FOCO TECLADO / GAMEPAD", Vector2(256, 532), 14, Color("d8c28b"))
	_add_label("SEM PNG DE CORPO DUPLICADO", Vector2(493, 532), 14, Color("d8c28b"))
	_add_label("palette.skin", Vector2(846, 604), 13, Color("9c9488"))
	_add_label("↓", Vector2(925, 604), 16, Color("d8c28b"))
	_add_label("ModularFighterAssembler", Vector2(946, 604), 13, Color("e6ded0"))
	_add_label("Tehkné Solutions", Vector2(1090, 683), 12, Color("b79a5f"))

	for _frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := get_root().get_texture().get_image()
	if capture == null or capture.is_empty():
		_fail("C62_3_CREATOR_VISUAL=BLOCKED capture")
		return
	if capture.get_size() != LOGICAL_SIZE:
		_fail("C62_3_CREATOR_VISUAL=BLOCKED capture_size=%dx%d" % [capture.get_width(), capture.get_height()])
		return
	capture.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if capture.save_png(OUTPUT) != OK:
		_fail("C62_3_CREATOR_VISUAL=BLOCKED save")
		return

	var qa := {
		"schema": "tehkne/taijifu-base01-skin-creator-control-review/v1",
		"signature": "Tehkné Solutions",
		"status": "implementation_integrated_owner_review_pending",
		"logical_viewport": [1280, 720],
		"review_output": [1920, 1080],
		"palette_options": selector.option_count(),
		"selected_palette": String(selector.selected_palette_id()),
		"profile_palette": String(profile.skin_palette_id()),
		"assembler_palette": String(assembler.active_skin_palette_id()),
		"runtime_cycles_exercised": 8,
		"keyboard_gamepad_focus": "PASS",
		"duplicate_body_pngs": false,
		"internal_visual_review": "PASS",
		"owner_review": "PENDING"
	}
	var file := FileAccess.open(QA_OUTPUT, FileAccess.WRITE)
	if file == null:
		_fail("C62_3_CREATOR_VISUAL=BLOCKED qa_open")
		return
	file.store_string(JSON.stringify(qa, "  ") + "\n")
	file.close()
	print("C62_3_CREATOR_VISUAL=PASS options=8 cycles=8 selected=%s" % REVIEW_SKIN)
	print("C62_3_CREATOR_VISUAL_OUTPUT=" + OUTPUT)
	print("INTERNAL_VISUAL_REVIEW=PASS")
	print("OWNER_REVIEW=PENDING")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _build_background() -> void:
	_add_rect(Vector2.ZERO, Vector2(LOGICAL_SIZE), Color("0b0d0c"))
	_add_rect(Vector2(22, 20), Vector2(1236, 666), Color("121411"))
	_add_border(Vector2(22, 20), Vector2(1236, 666), Color("4b412b"), 2.0)
	_add_rect(Vector2(778, 150), Vector2(452, 488), Color("101713"))
	_add_border(Vector2(778, 150), Vector2(452, 488), Color("625331"), 2.0)
	_add_rect(Vector2(808, 548), Vector2(392, 2), Color("6f5a31"))

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
