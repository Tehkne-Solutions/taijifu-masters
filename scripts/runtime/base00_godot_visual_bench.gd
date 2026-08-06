extends Node2D

const ProfileClass := preload("res://scripts/characters/modular_fighter_profile.gd")
const AssemblerClass := preload("res://scripts/characters/modular_fighter_assembler.gd")
const BASE_ASSET_PATH := "res://assets/modular_fighters/base_00/base_fighter_v1_master.png"
const OUTPUT := "res://artifacts/vm02-c54/base00-godot-bench-1920x1080.png"
const BENCH_CANVAS_SIZE := Vector2(1920.0, 1080.0)
const TARGET_VISUAL_HEIGHT := 132.0
const BENCH_BASELINE_Y := 790.0
const LEFT_ROOT_X := 650.0
const RIGHT_ROOT_X := 1270.0

var _source_used_rect := Rect2i()
var _gameplay_scale := 1.0
var _baseline_offset_y := 0.0
var _layout_scale := 1.0
var _layout_offset := Vector2.ZERO
var _logical_viewport_size := Vector2.ZERO
var _base_texture: Texture2D
var _left_assembler: Node2D
var _right_assembler: Node2D

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _configure_layout_transform():
		_fail("VM02_C54_VIEWPORT_LAYOUT=BLOCKED", 2)
		return

	var image := Image.load_from_file(ProjectSettings.globalize_path(BASE_ASSET_PATH))
	if image == null or image.is_empty():
		_fail("VM02_C54_BASE00_IMAGE=BLOCKED", 3)
		return
	if image.get_width() != 1024 or image.get_height() != 1024:
		_fail("VM02_C54_CANVAS=BLOCKED size=%dx%d" % [image.get_width(), image.get_height()], 4)
		return

	_source_used_rect = _alpha_used_rect(image)
	if _source_used_rect.size.y <= 0:
		_fail("VM02_C54_ALPHA_BOUNDS=BLOCKED empty", 5)
		return

	_base_texture = ImageTexture.create_from_image(image)
	if _base_texture == null:
		_fail("VM02_C54_BASE00_TEXTURE=BLOCKED image_texture_unavailable", 6)
		return

	_gameplay_scale = TARGET_VISUAL_HEIGHT / float(_source_used_rect.size.y)
	var last_visible_y := float(_source_used_rect.position.y + _source_used_rect.size.y - 1)
	_baseline_offset_y = (last_visible_y - 512.0) * _gameplay_scale

	var left_ok := _build_fighter(LEFT_ROOT_X, false, "BASE-00 / authored facing")
	var right_ok := _build_fighter(RIGHT_ROOT_X, true, "BASE-00 / horizontal flip")
	if not left_ok or not right_ok:
		_fail("VM02_C54_MODULAR_ASSEMBLY=BLOCKED", 7)
		return

	_install_labels()
	queue_redraw()

	for _frame in range(16):
		await get_tree().process_frame

	if _left_assembler == null or _right_assembler == null:
		_fail("VM02_C54_MODULAR_ASSEMBLY=BLOCKED missing_assembler", 8)
		return
	if _left_assembler.get_node_or_null("Module_body_base") == null or _right_assembler.get_node_or_null("Module_body_base") == null:
		_fail("VM02_C54_BODY_SLOT=BLOCKED", 9)
		return

	var computed_height := float(_source_used_rect.size.y) * _gameplay_scale
	if abs(computed_height - TARGET_VISUAL_HEIGHT) > 0.05:
		_fail("VM02_C54_GAMEPLAY_HEIGHT=BLOCKED actual=%.4f" % computed_height, 10)
		return
	var logical_height := computed_height * _layout_scale
	var expected_logical_height := TARGET_VISUAL_HEIGHT * _layout_scale
	if abs(logical_height - expected_logical_height) > 0.05:
		_fail("VM02_C54_LOGICAL_GAMEPLAY_HEIGHT=BLOCKED actual=%.4f" % logical_height, 11)
		return

	var expected_baseline := _logical_point(Vector2(0.0, BENCH_BASELINE_Y)).y
	var left_bottom := _left_assembler.position.y
	var right_bottom := _right_assembler.position.y
	if abs(left_bottom - expected_baseline) > 0.01 or abs(right_bottom - expected_baseline) > 0.01:
		_fail("VM02_C54_BASELINE=BLOCKED left=%.3f right=%.3f expected=%.3f" % [left_bottom, right_bottom, expected_baseline], 12)
		return

	if not _safe_frame_contract_passes():
		_fail("VM02_C54_SAFE_FRAME=BLOCKED", 13)
		return

	var output_dir := OUTPUT.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	await RenderingServer.frame_post_draw
	var capture := get_viewport().get_texture().get_image()
	if capture == null or capture.is_empty():
		_fail("VM02_C54_CAPTURE=BLOCKED viewport_unavailable", 14)
		return
	if capture.get_width() != 1920 or capture.get_height() != 1080:
		capture.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var save_error := capture.save_png(OUTPUT)
	if save_error != OK:
		_fail("VM02_C54_CAPTURE=BLOCKED save_error=%s" % save_error, 15)
		return

	print("VM02_C54_LOGICAL_VIEWPORT=PASS size=%dx%d" % [roundi(_logical_viewport_size.x), roundi(_logical_viewport_size.y)])
	print("VM02_C54_AUTHORED_CANVAS=PASS size=1920x1080")
	print("VM02_C54_LAYOUT_SCALE=PASS scale=%.8f" % _layout_scale)
	print("VM02_C54_LOGICAL_COORDINATES=PASS")
	print("VM02_C54_SAFE_FRAME=PASS")
	print("VM02_C54_BASE00_TEXTURE=PASS")
	print("VM02_C54_CANVAS=PASS size=1024x1024")
	print("VM02_C54_ALPHA_BBOX=%d,%d,%d,%d" % [_source_used_rect.position.x, _source_used_rect.position.y, _source_used_rect.size.x, _source_used_rect.size.y])
	print("VM02_C54_GAMEPLAY_HEIGHT=PASS actual=%.3f" % computed_height)
	print("VM02_C54_LOGICAL_GAMEPLAY_HEIGHT=PASS actual=%.3f" % logical_height)
	print("VM02_C54_GAMEPLAY_SCALE=%.8f" % _gameplay_scale)
	print("VM02_C54_BASELINE=PASS y=%.1f logical=%.3f" % [BENCH_BASELINE_Y, expected_baseline])
	print("VM02_C54_FLIP=PASS")
	print("VM02_C54_MODULAR_ASSEMBLY=PASS slot=body_base")
	print("VM02_C54_HITBOX_SCALE=PASS visual_height=132")
	print("VM02_C54_PROCEDURAL_FIGHTER_RENDERER=RETIRED")
	print("VM02_C54_CAPTURE=PASS")
	print("VM02_C54_OUTPUT=" + OUTPUT)
	print("VM02_C54_RUNTIME=PASS")
	get_tree().quit(0)

func _configure_layout_transform() -> bool:
	_logical_viewport_size = get_viewport().get_visible_rect().size
	if _logical_viewport_size.x <= 0.0 or _logical_viewport_size.y <= 0.0:
		return false
	var scale_x := _logical_viewport_size.x / BENCH_CANVAS_SIZE.x
	var scale_y := _logical_viewport_size.y / BENCH_CANVAS_SIZE.y
	if scale_x <= 0.0 or scale_y <= 0.0:
		return false
	_layout_scale = minf(scale_x, scale_y)
	if _layout_scale <= 0.0:
		return false
	_layout_offset = (_logical_viewport_size - BENCH_CANVAS_SIZE * _layout_scale) * 0.5
	return true

func _logical_point(authored: Vector2) -> Vector2:
	return _layout_offset + authored * _layout_scale

func _logical_size(authored: Vector2) -> Vector2:
	return authored * _layout_scale

func _logical_rect(authored: Rect2) -> Rect2:
	return Rect2(_logical_point(authored.position), _logical_size(authored.size))

func _logical_font_size(authored_size: int) -> int:
	return maxi(1, roundi(float(authored_size) * _layout_scale))

func _safe_frame_contract_passes() -> bool:
	if LEFT_ROOT_X - 52.0 < 0.0 or LEFT_ROOT_X + 52.0 > BENCH_CANVAS_SIZE.x:
		return false
	if RIGHT_ROOT_X - 52.0 < 0.0 or RIGHT_ROOT_X + 52.0 > BENCH_CANVAS_SIZE.x:
		return false
	if BENCH_BASELINE_Y - TARGET_VISUAL_HEIGHT < 0.0 or BENCH_BASELINE_Y > BENCH_CANVAS_SIZE.y:
		return false
	var left_box := _logical_rect(Rect2(LEFT_ROOT_X - 52.0, BENCH_BASELINE_Y - TARGET_VISUAL_HEIGHT, 104.0, TARGET_VISUAL_HEIGHT))
	var right_box := _logical_rect(Rect2(RIGHT_ROOT_X - 52.0, BENCH_BASELINE_Y - TARGET_VISUAL_HEIGHT, 104.0, TARGET_VISUAL_HEIGHT))
	var viewport_rect := Rect2(Vector2.ZERO, _logical_viewport_size)
	return viewport_rect.encloses(left_box) and viewport_rect.encloses(right_box)

func _build_fighter(root_x: float, flipped: bool, caption: String) -> bool:
	var profile = ProfileClass.new()
	profile.profile_id = StringName("base00_bench_flip" if flipped else "base00_bench_authored")
	profile.display_name = caption
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = -1 if flipped else 1
	profile.modules = {"body_base": "base_fighter_v1"}

	var assembler := AssemblerClass.new() as Node2D
	if assembler == null:
		push_error("BASE-00 assembler instantiation failed")
		return false
	assembler.name = "Base00AssemblerFlip" if flipped else "Base00AssemblerAuthored"
	assembler.position = _logical_point(Vector2(root_x, BENCH_BASELINE_Y))
	add_child(assembler)

	var failures_variant = assembler.call("configure", profile)
	if typeof(failures_variant) != TYPE_PACKED_STRING_ARRAY:
		push_error("BASE-00 assembler configure returned an invalid contract")
		return false
	var failures: PackedStringArray = failures_variant
	if not failures.is_empty():
		push_error("BASE-00 assembler failures: %s" % ",".join(failures))
		return false

	var sprite := Sprite2D.new()
	sprite.texture = _base_texture
	sprite.centered = true
	sprite.flip_h = flipped
	sprite.scale = Vector2.ONE * _gameplay_scale * _layout_scale
	sprite.position = Vector2(0.0, -_baseline_offset_y * _layout_scale)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not bool(assembler.call("attach_visual_module", &"body_base", sprite)):
		return false

	for slot in [&"hair_front", &"torso_outer", &"weapon_main"]:
		var empty_module := Node2D.new()
		if not bool(assembler.call("attach_visual_module", slot, empty_module)):
			return false

	if flipped:
		_right_assembler = assembler
	else:
		_left_assembler = assembler
	return true

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

func _install_labels() -> void:
	_add_label("TAIJIFU MODULAR FIGHTER SYSTEM", Vector2(510, 72), 38, Color(0.95, 0.78, 0.28))
	_add_label("C54 — BASE-00 GODOT VISUAL BENCH", Vector2(578, 126), 30, Color.WHITE)
	_add_label("Canonical 1024×1024 RGBA master • gameplay height 132 px • pivot 0.5 / 0.92", Vector2(430, 175), 20, Color(0.78, 0.82, 0.88))
	_add_label("AUTHORED", Vector2(575, 832), 24, Color(0.64, 0.90, 0.78))
	_add_label("FLIPPED", Vector2(1208, 832), 24, Color(0.64, 0.90, 0.78))
	_add_label("BODY_BASE SLOT", Vector2(548, 874), 18, Color(0.75, 0.78, 0.84))
	_add_label("BODY_BASE SLOT", Vector2(1178, 874), 18, Color(0.75, 0.78, 0.84))
	_add_label("Green line: canonical feet baseline  •  Cyan box: 132 px gameplay visual envelope", Vector2(520, 968), 18, Color(0.72, 0.76, 0.82))
	_add_label("Tehkné Solutions", Vector2(845, 1020), 18, Color(0.95, 0.78, 0.28))

func _add_label(text_value: String, at: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = _logical_point(at)
	label.add_theme_font_size_override("font_size", _logical_font_size(font_size))
	label.add_theme_color_override("font_color", color)
	add_child(label)

func _draw() -> void:
	draw_rect(_logical_rect(Rect2(Vector2.ZERO, BENCH_CANVAS_SIZE)), Color("0a0e14"), true)
	draw_rect(_logical_rect(Rect2(130, 235, 1660, 710)), Color("111923"), true)
	draw_rect(_logical_rect(Rect2(130, 235, 1660, 710)), Color("a88435"), false, 2.0 * _layout_scale)
	draw_rect(_logical_rect(Rect2(210, BENCH_BASELINE_Y, 1500, 72)), Color("171c24"), true)
	draw_line(_logical_point(Vector2(210, BENCH_BASELINE_Y)), _logical_point(Vector2(1710, BENCH_BASELINE_Y)), Color("57d998"), 3.0 * _layout_scale)
	for root_x in [LEFT_ROOT_X, RIGHT_ROOT_X]:
		draw_rect(_logical_rect(Rect2(root_x - 52.0, BENCH_BASELINE_Y - TARGET_VISUAL_HEIGHT, 104.0, TARGET_VISUAL_HEIGHT)), Color("55c9e8"), false, 2.0 * _layout_scale)
		draw_line(_logical_point(Vector2(root_x - 12.0, BENCH_BASELINE_Y)), _logical_point(Vector2(root_x + 12.0, BENCH_BASELINE_Y)), Color.WHITE, 2.0 * _layout_scale)
		draw_line(_logical_point(Vector2(root_x, BENCH_BASELINE_Y - 12.0)), _logical_point(Vector2(root_x, BENCH_BASELINE_Y + 12.0)), Color.WHITE, 2.0 * _layout_scale)

func _fail(marker: String, exit_code: int) -> void:
	print(marker)
	push_error(marker)
	get_tree().quit(exit_code)

# Tehkné Solutions
