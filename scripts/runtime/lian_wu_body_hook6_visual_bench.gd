extends Node2D

## VM02-C2 — Lian Wu ji_body_hook 6-keypose visual bench.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://artifacts/vm02-c2/lian-wu-body-hook6-bench-1920x1080.png"
const FRAME_DIR := "res://assets/pack_01_characters/lian_wu/frames/attacks/ji_body_hook"
const LABELS := ["F01 GUARD", "F02 CHAMBER", "F03 TORQUE", "F04 IMPACT · ACTIVE", "F05 RECOIL", "F06 RECOVER"]
const POSITIONS := [
	Vector2(240, 440), Vector2(720, 440), Vector2(1200, 440),
	Vector2(240, 810), Vector2(720, 810), Vector2(1200, 810)
]
const VISUAL_HEIGHT := 185.0

var _frames: Array[Texture2D] = []
var _bounds: Array[Rect2i] = []

func _ready() -> void:
	for index in range(1, 7):
		var path: String = "%s/char_lian_wu__ji_body_hook__f%02d.png" % [FRAME_DIR, index]
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			push_error("missing C2 frame: %s" % path)
			get_tree().quit(2)
			return
		_frames.append(texture)
		_bounds.append(_alpha_bounds(texture.get_image()))
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
	draw_string(ThemeDB.fallback_font, Vector2(70, 72), "VM02-C2 — LIAN WU / JI_BODY_HOOK 6 KEYPOSES", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.95,0.96,0.98))
	draw_string(ThemeDB.fallback_font, Vector2(72, 108), "Tehkné Solutions · guard → chamber → torque → impact → recoil → recover", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.65,0.72,0.82))
	for row_y: float in [520.0, 890.0]:
		draw_line(Vector2(70, row_y), Vector2(1850, row_y), Color(0.30,0.65,0.88,0.75), 2.0)
	for i in range(_frames.size()):
		var bounds: Rect2i = _bounds[i]
		if bounds.size == Vector2i.ZERO:
			continue
		var scale_factor: float = VISUAL_HEIGHT / float(bounds.size.y)
		var size: Vector2 = Vector2(bounds.size) * scale_factor
		var baseline_y: float = 520.0 if i < 3 else 890.0
		var slot_position: Vector2 = POSITIONS[i] as Vector2
		var center_x: float = slot_position.x + 100.0
		var dest: Rect2 = Rect2(Vector2(center_x - size.x * 0.5, baseline_y - size.y), size)
		draw_texture_rect_region(_frames[i], dest, Rect2(bounds), Color.WHITE)
		var label_color: Color = Color(1.0,0.72,0.28) if i == 3 else Color(0.88,0.90,0.94)
		draw_string(ThemeDB.fallback_font, Vector2(center_x - 92, baseline_y + 48), LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, label_color)

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
