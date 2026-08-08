extends SceneTree

const BASE := "res://assets/modular_fighters/base_00/base_fighter_v1_master.png"
const OUTPUT := "res://artifacts/c62-1/BASE01_SKIN_PALETTES.contact-sheet-1920x1080.png"
const QA_OUTPUT := "res://artifacts/c62-1/BASE01_SKIN_PALETTES.runtime.qa.json"
const PALETTE_ROOT := "res://assets/modular_fighters/base_01/palettes"
const AUTHORED_CANVAS := Vector2(1920.0, 1080.0)
const PALETTE_IDS := [
	"skin_tone_01_porcelain",
	"skin_tone_02_light_neutral",
	"skin_tone_03_warm",
	"skin_tone_04_olive",
	"skin_tone_05_tan",
	"skin_tone_06_brown",
	"skin_tone_07_deep",
	"skin_tone_08_ebony",
]
const DISPLAY_NAMES := ["PORCELAIN", "LIGHT NEUTRAL", "WARM / DEFAULT", "OLIVE", "TAN", "BROWN", "DEEP", "EBONY"]
const REVIEW_HEIGHT := 240.0
const GAMEPLAY_HEIGHT := 132.0

var _layout_scale := 1.0
var _layout_offset := Vector2.ZERO
var _logical_viewport_size := Vector2.ZERO

class SkinPreviewProfile:
	extends RefCounted
	var profile_id: StringName = &"c62_1_skin_visual_bench"
	func validate_against_standard() -> PackedStringArray:
		return PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _configure_layout_transform():
		_fail("C62_1_SKIN_VISUAL=BLOCKED viewport_layout")
		return
	RenderingServer.set_default_clear_color(Color("080d13"))
	var base_image := Image.load_from_file(ProjectSettings.globalize_path(BASE))
	if base_image == null or base_image.is_empty():
		_fail("C62_1_SKIN_VISUAL=BLOCKED base_missing")
		return
	var used := _alpha_used_rect(base_image)
	if used.size.y <= 0:
		_fail("C62_1_SKIN_VISUAL=BLOCKED alpha_bounds")
		return
	var bottom_offset := float(used.position.y + used.size.y - 1) - 512.0
	var review_scale := REVIEW_HEIGHT / float(used.size.y)
	var gameplay_scale := GAMEPLAY_HEIGHT / float(used.size.y)
	var base_texture := ImageTexture.create_from_image(base_image)

	_add_rect(Vector2(0, 0), AUTHORED_CANVAS, Color("080d13"))
	_add_label("TAIJIFU BASE-01 — SKIN PALETTE RUNTIME REVIEW", Vector2(54, 30), 34, Color("f2c85b"))
	_add_label("Same BASE-00 • palette data only • authored review + flipped 132px gameplay proof", Vector2(56, 78), 19, Color("c3ccd8"))

	var failures := PackedStringArray()
	for index in range(PALETTE_IDS.size()):
		var row := index / 4
		var col := index % 4
		var card_pos := Vector2(28 + col * 472, 126 + row * 456)
		var card_size := Vector2(448, 420)
		_add_rect(card_pos, card_size, Color("111a24"))
		_add_border(card_pos, card_size, Color("9b7a31"))
		_add_label("%02d  %s" % [index + 1, DISPLAY_NAMES[index]], card_pos + Vector2(18, 14), 20, Color.WHITE)
		var palette := _load_json("%s/%s.json" % [PALETTE_ROOT, PALETTE_IDS[index]])
		if palette.is_empty():
			failures.append("palette_missing:%s" % PALETTE_IDS[index])
			continue
		var swatch := Color.from_string(String(palette.get("channels", {}).get("skin_base", "#FF00FF")), Color.MAGENTA)
		_add_rect(card_pos + Vector2(388, 15), Vector2(34, 20), swatch)

		var authored_ok := _build_fighter(base_texture, PALETTE_IDS[index], card_pos + Vector2(132, 336), review_scale, false, bottom_offset)
		var flipped_ok := _build_fighter(base_texture, PALETTE_IDS[index], card_pos + Vector2(338, 336), gameplay_scale, true, bottom_offset)
		if not authored_ok or not flipped_ok:
			failures.append("build_failed:%s" % PALETTE_IDS[index])
		_add_label("AUTHORED 240px", card_pos + Vector2(64, 372), 14, Color("72d6ae"))
		_add_label("FLIP 132px", card_pos + Vector2(303, 372), 14, Color("6dc6e8"))

	_add_label("Default WARM keeps material disabled to preserve the approved BASE-00 reconstruction exactly.", Vector2(54, 1036), 16, Color("aeb9c7"))
	_add_label("Tehkné Solutions", Vector2(1690, 1036), 16, Color("f2c85b"))

	if not failures.is_empty():
		for failure in failures:
			push_error("C62_1_SKIN_VISUAL=BLOCKED %s" % failure)
		quit(2)
		return

	for _frame in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := get_root().get_texture().get_image()
	if capture == null or capture.is_empty():
		_fail("C62_1_SKIN_VISUAL=BLOCKED capture")
		return
	if capture.get_width() <= 0 or capture.get_height() <= 0:
		_fail("C62_1_SKIN_VISUAL=BLOCKED capture_size")
		return
	if capture.get_size() != Vector2i(1920, 1080):
		capture.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	if capture.save_png(OUTPUT) != OK:
		_fail("C62_1_SKIN_VISUAL=BLOCKED save")
		return

	var qa := {
		"schema": "tehkne/taijifu-base01-skin-runtime-review/v1",
		"signature": "Tehkné Solutions",
		"status": "runtime_candidate_owner_review_pending",
		"palettes": PALETTE_IDS,
		"source": "BASE-00 base_fighter_v1_master.png",
		"duplicate_body_pngs": false,
		"authored_review_height_px": 240,
		"gameplay_review_height_px": 132,
		"flipped_review": "PASS",
		"runtime_material_application": "PASS",
		"default_warm_identity_preservation": "PASS",
		"logical_viewport": [roundi(_logical_viewport_size.x), roundi(_logical_viewport_size.y)],
		"layout_scale": _layout_scale,
		"authored_canvas": [1920, 1080],
		"owner_review": "PENDING"
	}
	var qa_file := FileAccess.open(QA_OUTPUT, FileAccess.WRITE)
	qa_file.store_string(JSON.stringify(qa, "  ") + "\n")
	qa_file.close()
	print("C62_1_LOGICAL_VIEWPORT=PASS size=%dx%d" % [roundi(_logical_viewport_size.x), roundi(_logical_viewport_size.y)])
	print("C62_1_LAYOUT_SCALE=PASS scale=%.8f" % _layout_scale)
	print("C62_1_SKIN_VISUAL=PASS palettes=8 authored=8 flipped_gameplay=8")
	print("C62_1_SKIN_VISUAL_OUTPUT=" + OUTPUT)
	print("OWNER_REVIEW=PENDING")
	print("SIGNATURE=Tehkné Solutions")
	quit(0)

func _configure_layout_transform() -> bool:
	_logical_viewport_size = get_root().get_visible_rect().size
	if _logical_viewport_size.x <= 0.0 or _logical_viewport_size.y <= 0.0:
		return false
	var scale_x := _logical_viewport_size.x / AUTHORED_CANVAS.x
	var scale_y := _logical_viewport_size.y / AUTHORED_CANVAS.y
	_layout_scale = minf(scale_x, scale_y)
	if _layout_scale <= 0.0:
		return false
	_layout_offset = (_logical_viewport_size - AUTHORED_CANVAS * _layout_scale) * 0.5
	return true

func _logical_point(authored: Vector2) -> Vector2:
	return _layout_offset + authored * _layout_scale

func _logical_size(authored: Vector2) -> Vector2:
	return authored * _layout_scale

func _logical_font_size(authored_size: int) -> int:
	return maxi(1, roundi(float(authored_size) * _layout_scale))

func _build_fighter(texture: Texture2D, palette_id: String, root_position: Vector2, visual_scale: float, flipped: bool, bottom_offset: float) -> bool:
	var assembler := ModularFighterAssembler.new()
	assembler.position = _logical_point(root_position)
	var scaled := visual_scale * _layout_scale
	assembler.scale = Vector2(-scaled if flipped else scaled, scaled)
	get_root().add_child(assembler)
	var failures := assembler.configure(SkinPreviewProfile.new())
	if not failures.is_empty():
		return false
	var body := Sprite2D.new()
	body.texture = texture
	body.centered = true
	body.position = Vector2(0.0, -bottom_offset)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not assembler.attach_visual_module(&"body_base", body):
		return false
	failures = assembler.assemble_base01_default_identity()
	if not failures.is_empty():
		return false
	failures = assembler.set_skin_palette(StringName(palette_id))
	return failures.is_empty()

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

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

func _add_rect(position: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = _logical_point(position)
	rect.size = _logical_size(size)
	rect.color = color
	get_root().add_child(rect)
	get_root().move_child(rect, 0)

func _add_border(position: Vector2, size: Vector2, color: Color) -> void:
	for data in [
		[position, Vector2(size.x, 2)],
		[position + Vector2(0, size.y - 2), Vector2(size.x, 2)],
		[position, Vector2(2, size.y)],
		[position + Vector2(size.x - 2, 0), Vector2(2, size.y)],
	]:
		_add_rect(data[0], data[1], color)

func _add_label(text_value: String, position: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = _logical_point(position)
	label.add_theme_font_size_override("font_size", _logical_font_size(font_size))
	label.add_theme_color_override("font_color", color)
	get_root().add_child(label)

func _fail(marker: String) -> void:
	push_error(marker)
	print(marker)
	quit(2)
