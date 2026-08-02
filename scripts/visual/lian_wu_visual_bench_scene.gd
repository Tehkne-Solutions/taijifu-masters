extends Node2D

## VM01-A4 real visual bench for Lian Wu Character Lock.
## Tehkné Solutions

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const BENCH_SCRIPT := preload("res://scripts/visual/lian_wu_character_lock_bench.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT_PATH := "res://artifacts/vm01-a4/lian-wu-character-lock-bench-1920x1080.png"

var _bench_entries: Array[Dictionary] = []
var _capture_and_quit := false

func _ready() -> void:
	get_viewport().size = VIEWPORT_SIZE
	_capture_and_quit = OS.get_cmdline_user_args().has("--capture-and-quit")
	_build_background()
	_build_header()
	_add_fighter(Vector2(330, 420), false, 1.0, 96.0, "NEUTRAL / RIGHT / 1.00x")
	_add_fighter(Vector2(810, 420), false, -1.0, 72.0, "NEUTRAL / FLIP / 0.75x")
	_add_fighter(Vector2(1290, 420), true, 1.0, 96.0, "STANCE / RIGHT / 1.00x")
	_add_fighter(Vector2(1710, 420), true, -1.0, 130.0, "STANCE / FLIP / 1.35x")
	queue_redraw()
	if _capture_and_quit:
		call_deferred("_capture_after_frames")

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.065, 0.085, 1.0)
	bg.position = Vector2.ZERO
	bg.size = Vector2(VIEWPORT_SIZE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -100
	add_child(bg)

func _build_header() -> void:
	var title := Label.new()
	title.text = "VM01-A4 — LIAN WU CHARACTER LOCK / GODOT VISUAL BENCH"
	title.position = Vector2(72, 38)
	title.add_theme_font_size_override("font_size", 30)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Tehkné Solutions · 1920×1080 · real FighterController · procedural presenter hidden"
	subtitle.position = Vector2(74, 80)
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.modulate = Color(0.72, 0.76, 0.82, 1.0)
	add_child(subtitle)

func _add_fighter(world_position: Vector2, stance: bool, facing: float, visual_height: float, label_text: String) -> void:
	var fighter := FIGHTER_SCENE.instantiate()
	fighter.position = world_position
	fighter.set("facing", facing)
	add_child(fighter)
	_hide_procedural_visuals(fighter)

	var bench := BENCH_SCRIPT.new()
	bench.set("show_combat_stance", stance)
	bench.set("fighter_visual_height", visual_height)
	fighter.add_child(bench)

	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-30, -5), Vector2(30, -5), Vector2(38, 0), Vector2(30, 5), Vector2(-30, 5), Vector2(-38, 0)
	])
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.position = Vector2(0, 2)
	shadow.z_index = 1
	fighter.add_child(shadow)
	fighter.move_child(shadow, 0)

	var label := Label.new()
	label.text = label_text
	label.position = world_position + Vector2(-145, 170)
	label.size = Vector2(290, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)

	_bench_entries.append({
		"fighter": fighter,
		"bench": bench,
		"position": world_position,
		"label": label_text,
		"visual_height": visual_height,
		"facing": facing,
		"stance": stance
	})

func _hide_procedural_visuals(fighter: Node) -> void:
	for child_name in ["SpritePresenter", "WeaponTrail", "VisualOverlay", "CosmeticSockets", "ExpressionOverlay", "RegionalHitFlash"]:
		var child := fighter.get_node_or_null(child_name)
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		if child != null:
			child.process_mode = Node.PROCESS_MODE_DISABLED

func _draw() -> void:
	# Global ground/contact line.
	draw_line(Vector2(60, 422), Vector2(1860, 422), Color(0.38, 0.72, 0.95, 0.45), 2.0)
	for entry in _bench_entries:
		var p: Vector2 = entry["position"]
		# Fighter capsule: radius 16, height 78, local position (0,-16).
		draw_arc(p + Vector2(0, -16), 16.0, 0.0, TAU, 32, Color(0.15, 0.92, 0.55, 0.85), 2.0)
		draw_rect(Rect2(p + Vector2(-16, -55), Vector2(32, 78)), Color(0.15, 0.92, 0.55, 0.22), false, 2.0)
		# Regional hurtbox references from fighter.tscn.
		draw_arc(p + Vector2(0, -49), 15.0, 0.0, TAU, 28, Color(1.0, 0.42, 0.30, 0.75), 1.5)
		draw_rect(Rect2(p + Vector2(-17, -38.5), Vector2(34, 43)), Color(1.0, 0.70, 0.20, 0.70), false, 1.5)
		draw_rect(Rect2(p + Vector2(-15, 4.5), Vector2(30, 31)), Color(0.68, 0.48, 1.0, 0.70), false, 1.5)
		draw_circle(p, 3.0, Color(1.0, 1.0, 1.0, 0.95))

	# Legend.
	draw_rect(Rect2(70, 680, 1780, 320), Color(0.08, 0.095, 0.12, 0.95), true)
	draw_line(Vector2(90, 735), Vector2(1830, 735), Color(1, 1, 1, 0.12), 1.0)

func _process(_delta: float) -> void:
	queue_redraw()

func _capture_after_frames() -> void:
	for _i in range(4):
		await get_tree().process_frame
	var report := _validate_entries()
	print("VM01_A4_VISUAL_BENCH_RUNTIME=%s" % ("PASS" if report.failures.is_empty() else "BLOCKED"))
	for failure in report.failures:
		push_error(failure)
	if not report.failures.is_empty():
		get_tree().quit(2)
		return
	var absolute_dir := ProjectSettings.globalize_path("res://artifacts/vm01-a4")
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != VIEWPORT_SIZE:
		push_error("capture size mismatch: %s" % image.get_size())
		get_tree().quit(3)
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("failed to save visual bench PNG: %s" % error)
		get_tree().quit(4)
		return
	print("VM01_A4_VISUAL_BENCH_CAPTURE=PASS")
	print("VM01_A4_VISUAL_BENCH_OUTPUT=%s" % OUTPUT_PATH)
	get_tree().quit(0)

func _validate_entries() -> Dictionary:
	var failures: Array[String] = []
	if get_viewport().size != VIEWPORT_SIZE:
		failures.append("viewport must be 1920x1080")
	if _bench_entries.size() != 4:
		failures.append("bench must contain 4 comparison states")
	for entry in _bench_entries:
		var bench = entry["bench"]
		var report: Dictionary = bench.bench_report()
		if String(report.get("status", "blocked")) != "pass":
			failures.append("bench state failed: %s -> %s" % [entry["label"], report.get("failures", [])])
	return {"failures": failures}
