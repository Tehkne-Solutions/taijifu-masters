extends Node2D

## VM02-A4 visual review bench for Lian Wu Run 8.
## Tehkné Solutions

const LOGICAL_SIZE := Vector2i(1280, 720)
const OUTPUT_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://artifacts/vm02-a4/lian-wu-run8-bench-1920x1080.png"
const FRAME_DIR := "res://assets/pack_01_characters/lian_wu/frames/run"
const FRAME_COUNT := 8
const VISUAL_HEIGHT := 118.0
const ALPHA_THRESHOLD := 0.01

var _entries: Array[Dictionary] = []
var _capture_and_quit := false

func _ready() -> void:
	_capture_and_quit = OS.get_cmdline_user_args().has("--capture-and-quit")
	_build_background()
	_build_header()
	var positions := [
		Vector2(155, 310), Vector2(475, 310), Vector2(795, 310), Vector2(1115, 310),
		Vector2(155, 515), Vector2(475, 515), Vector2(795, 515), Vector2(1115, 515),
	]
	for zero_index in range(FRAME_COUNT):
		_add_frame(zero_index + 1, positions[zero_index])
	queue_redraw()
	if _capture_and_quit:
		call_deferred("_capture_after_frames")

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.065, 0.085, 1.0)
	bg.position = Vector2.ZERO
	bg.size = Vector2(LOGICAL_SIZE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -100
	add_child(bg)

func _build_header() -> void:
	var title := Label.new()
	title.text = "VM02-A4 — LIAN WU RUN 8 / GODOT VISUAL BENCH"
	title.position = Vector2(48, 24)
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Tehkné Solutions · articulated run cycle · forward drive / stride / flight / pivot review"
	subtitle.position = Vector2(50, 55)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.modulate = Color(0.72, 0.76, 0.82, 1.0)
	add_child(subtitle)

func _frame_path(frame_number: int) -> String:
	return "%s/char_lian_wu__run__f%02d.png" % [FRAME_DIR, frame_number]

func _load_png_texture(path: String) -> Texture2D:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.load_from_file(absolute_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _add_frame(frame_number: int, origin: Vector2) -> void:
	var path := _frame_path(frame_number)
	var texture := _load_png_texture(path)
	if texture == null:
		_entries.append({"index": frame_number, "origin": origin, "status": "missing_or_invalid_png"})
		return
	var bounds := _alpha_bounds(texture)
	if bounds.size == Vector2i.ZERO:
		_entries.append({"index": frame_number, "origin": origin, "status": "empty_alpha"})
		return
	var pivot := _pivot_from_bounds(bounds)
	var scale_factor := VISUAL_HEIGHT / maxf(1.0, float(bounds.size.y))
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = origin - pivot * scale_factor
	sprite.z_index = 4
	add_child(sprite)
	var label := Label.new()
	label.text = "F%02d" % frame_number
	label.position = origin + Vector2(-40, 58)
	label.size = Vector2(80, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	add_child(label)
	_entries.append({"index": frame_number, "origin": origin, "status": "loaded", "bounds": bounds, "pivot": pivot})

func _draw() -> void:
	draw_line(Vector2(45, 310), Vector2(1235, 310), Color(0.38, 0.72, 0.95, 0.45), 1.5)
	draw_line(Vector2(45, 515), Vector2(1235, 515), Color(0.38, 0.72, 0.95, 0.45), 1.5)
	for entry in _entries:
		var p: Vector2 = entry["origin"]
		draw_circle(p, 2.5, Color(1.0, 1.0, 1.0, 0.95))
		draw_rect(Rect2(p + Vector2(-16, -55), Vector2(32, 78)), Color(0.15, 0.92, 0.55, 0.55), false, 1.5)
		draw_line(p + Vector2(-24, 0), p + Vector2(24, 0), Color(1.0, 0.68, 0.20, 0.9), 1.5)

func _process(_delta: float) -> void:
	queue_redraw()

func _capture_after_frames() -> void:
	for _i in range(6):
		await get_tree().process_frame
	var report := _validate_entries()
	print("VM02_A4_RUN8_BENCH_RUNTIME=%s" % ("PASS" if report.failures.is_empty() else "BLOCKED"))
	for failure in report.failures:
		push_error(failure)
	if not report.failures.is_empty():
		get_tree().quit(2)
		return
	var absolute_dir := ProjectSettings.globalize_path("res://artifacts/vm02-a4")
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x, OUTPUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		print("VM02_A4_RUN8_BENCH_NORMALIZED=PASS")
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("failed to save run8 visual bench PNG: %s" % error)
		get_tree().quit(4)
		return
	print("VM02_A4_RUN8_BENCH_CAPTURE=PASS")
	print("VM02_A4_RUN8_BENCH_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)

func _validate_entries() -> Dictionary:
	var failures: Array[String] = []
	if _entries.size() != FRAME_COUNT:
		failures.append("bench must contain 8 frames")
	var baseline_y := -1.0
	for entry in _entries:
		if String(entry.get("status", "missing")) != "loaded":
			failures.append("frame %02d not loaded: %s" % [entry.get("index", -1), entry.get("status", "missing")])
			continue
		var pivot: Vector2 = entry["pivot"]
		if baseline_y < 0.0:
			baseline_y = pivot.y
		elif absf(pivot.y - baseline_y) > 0.01:
			failures.append("source baseline drift frame %02d: %.3f vs %.3f" % [entry["index"], pivot.y, baseline_y])
	return {"failures": failures}

func _alpha_bounds(texture: Texture2D) -> Rect2i:
	var image := texture.get_image()
	if image == null or image.is_empty(): return Rect2i()
	var min_x := image.get_width(); var min_y := image.get_height(); var max_x := -1; var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= ALPHA_THRESHOLD: continue
			min_x = mini(min_x, x); min_y = mini(min_y, y); max_x = maxi(max_x, x); max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y: return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _pivot_from_bounds(bounds: Rect2i) -> Vector2:
	return Vector2(float(bounds.position.x) + float(bounds.size.x - 1) * 0.5, float(bounds.position.y + bounds.size.y - 1))
