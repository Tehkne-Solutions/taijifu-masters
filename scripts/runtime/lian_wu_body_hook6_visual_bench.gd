extends Node2D

## VM02-C2 — Lian Wu ji_body_hook 6-keypose visual bench.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://artifacts/vm02-c2/lian-wu-body-hook6-bench-1920x1080.png"
const FRAME_DIR := "res://assets/pack_01_characters/lian_wu/frames/attacks/ji_body_hook"
const LABELS := ["F01 GUARD", "F02 CHAMBER", "F03 TORQUE", "F04 IMPACT · ACTIVE", "F05 RECOIL", "F06 RECOVER"]

var _frames: Array[Texture2D] = []
var _bounds: Array[Rect2i] = []

func _ready() -> void:
	for index in range(1, 7):
		var path: String = "%s/char_lian_wu__ji_body_hook__f%02d.png" % [FRAME_DIR, index]
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			push_error("missing C2 frame: %s" % path)
			get_tree().quit(2)
			return
		var texture: Texture2D = ImageTexture.create_from_image(image)
		_frames.append(texture)
		_bounds.append(_alpha_bounds(image))
	queue_redraw()
	for _i in range(6):
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--capture-and-quit"):
		_capture_and_quit()

func _alpha_bounds(image: Image) -> Rect2i:
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a8 >= 3:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var sx: float = viewport_size.x / 1280.0
	var sy: float = viewport_size.y / 720.0
	var unit: float = minf(sx, sy)
	var margin_x: float = 48.0 * sx
	var title_y: float = 48.0 * sy
	var subtitle_y: float = 76.0 * sy
	var row_baselines: Array[float] = [350.0 * sy, 610.0 * sy]
	var column_centers: Array[float] = [210.0 * sx, 640.0 * sx, 1070.0 * sx]
	var visual_height: float = 150.0 * unit
	var title_font: int = maxi(18, int(round(24.0 * unit)))
	var subtitle_font: int = maxi(15, int(round(19.0 * unit)))
	var label_font: int = maxi(13, int(round(16.0 * unit)))

	draw_string(ThemeDB.fallback_font, Vector2(margin_x, title_y), "VM02-C2 — LIAN WU / JI_BODY_HOOK 6 KEYPOSES", HORIZONTAL_ALIGNMENT_LEFT, -1, title_font, Color(0.95, 0.96, 0.98))
	draw_string(ThemeDB.fallback_font, Vector2(margin_x + 2.0 * sx, subtitle_y), "Tehkné Solutions · guard → chamber → torque → impact → recoil → recover", HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_font, Color(0.65, 0.72, 0.82))

	for baseline_y: float in row_baselines:
		draw_line(Vector2(margin_x, baseline_y), Vector2(viewport_size.x - margin_x, baseline_y), Color(0.30, 0.65, 0.88, 0.75), maxf(1.0, 1.5 * unit))

	for i in range(_frames.size()):
		var bounds: Rect2i = _bounds[i]
		if bounds.size == Vector2i.ZERO:
			continue
		var row: int = i / 3
		var col: int = i % 3
		var center_x: float = column_centers[col]
		var baseline_y: float = row_baselines[row]
		var scale_factor: float = visual_height / float(bounds.size.y)
		var size: Vector2 = Vector2(bounds.size) * scale_factor
		var dest: Rect2 = Rect2(Vector2(center_x - size.x * 0.5, baseline_y - size.y), size)
		draw_texture_rect_region(_frames[i], dest, Rect2(bounds), Color.WHITE)
		var label_color: Color = Color(1.0, 0.72, 0.28) if i == 3 else Color(0.88, 0.90, 0.94)
		var label_width: float = 220.0 * sx
		var label_x: float = center_x - label_width * 0.5
		draw_string(ThemeDB.fallback_font, Vector2(label_x, baseline_y + 34.0 * sy), LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, label_width, label_font, label_color)

func _capture_and_quit() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c2"))
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_C2_BODY_HOOK6_BENCH_NORMALIZED=PASS")
	var err: Error = image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if err != OK:
		push_error("failed to save C2 bench")
		get_tree().quit(4)
		return
	print("VM02_C2_BODY_HOOK6_BENCH_CAPTURE=PASS")
	print("VM02_C2_BODY_HOOK6_BENCH_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)
