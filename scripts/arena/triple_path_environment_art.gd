class_name TriplePathEnvironmentArt
extends Node2D

@onready var arena: TriplePathArena = get_node("../Arena")

var _arena_id: StringName = &"triple_path"
var _rules: Dictionary = {}
var _elapsed := 0.0
var _round_active := false
var _score_snapshot: Dictionary = {}

func _ready() -> void:
	z_index = 1
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta * (1.0 if _round_active else 0.28)
	visible = _arena_id == &"triple_path"
	if visible:
		queue_redraw()

func configure(config: Dictionary, rules: Dictionary) -> void:
	_arena_id = StringName(config.get("arena_id", &"triple_path"))
	_rules = rules.duplicate(true)
	visible = _arena_id == &"triple_path"
	queue_redraw()

func set_round_active(active: bool) -> void:
	_round_active = active
	queue_redraw()

func set_score_snapshot(snapshot: Dictionary) -> void:
	_score_snapshot = snapshot.duplicate(true)
	queue_redraw()

func environment_signature() -> Dictionary:
	return {
		"arena_id": _arena_id,
		"moon": true,
		"ink_mountains": 3,
		"waterfalls": 3,
		"banners": 5,
		"route_glyphs": 3,
		"animated_clouds": true,
		"competitive_collision_changes": false
	}

func _draw() -> void:
	if _arena_id != &"triple_path":
		return
	_draw_sky_wash()
	_draw_ritual_moon()
	_draw_ink_mountains()
	_draw_cloud_bands()
	_draw_distant_dojo()
	_draw_waterfalls()
	_draw_banners()
	_draw_route_glyphs()
	_draw_lanterns()
	_draw_comic_ink()

func _draw_sky_wash() -> void:
	draw_rect(Rect2(-500, -180, 3800, 720), Color(0.035, 0.075, 0.115, 0.42))
	draw_rect(Rect2(-500, 360, 3800, 420), Color(0.075, 0.045, 0.095, 0.18))
	for index in range(7):
		var y := 40.0 + index * 72.0
		var alpha := 0.045 + index * 0.009
		draw_line(Vector2(-400, y), Vector2(3200, y + 34.0), Color(0.50, 0.72, 0.88, alpha), 28.0)

func _draw_ritual_moon() -> void:
	var center := Vector2(1480.0, 128.0)
	var pulse := sin(_elapsed * 0.72) * 5.0
	draw_circle(center, 104.0 + pulse, Color(0.78, 0.89, 0.96, 0.16))
	draw_circle(center, 78.0 + pulse * 0.4, Color(0.92, 0.92, 0.78, 0.34))
	draw_arc(center, 118.0 + pulse, -2.8, 0.35, 54, Color(0.48, 0.82, 0.96, 0.42), 4.0)
	draw_arc(center, 133.0 - pulse, 0.55, 3.6, 54, Color(0.72, 0.42, 0.92, 0.28), 3.0)
	for index in range(8):
		var angle := _elapsed * 0.12 + TAU * float(index) / 8.0
		var point := center + Vector2.from_angle(angle) * 148.0
		draw_circle(point, 3.0, Color(0.82, 0.94, 1.0, 0.48))

func _draw_ink_mountains() -> void:
	var far := PackedVector2Array([
		Vector2(-300, 520), Vector2(220, 245), Vector2(530, 480), Vector2(920, 185),
		Vector2(1320, 520), Vector2(1820, 205), Vector2(2200, 510), Vector2(2700, 220), Vector2(3200, 520)
	])
	draw_colored_polygon(far, Color(0.045, 0.075, 0.105, 0.72))
	var middle := PackedVector2Array([
		Vector2(-280, 600), Vector2(420, 360), Vector2(820, 590), Vector2(1260, 315),
		Vector2(1660, 590), Vector2(2200, 340), Vector2(2860, 600), Vector2(3240, 420)
	])
	draw_colored_polygon(middle, Color(0.065, 0.095, 0.125, 0.66))
	for segment in [[Vector2(210, 258), Vector2(520, 478)], [Vector2(910, 198), Vector2(1310, 510)], [Vector2(1810, 218), Vector2(2190, 500)], [Vector2(2690, 232), Vector2(3100, 510)]]:
		draw_line(segment[0], segment[1], Color(0.52, 0.72, 0.86, 0.15), 8.0)

func _draw_cloud_bands() -> void:
	for band in range(4):
		var speed := 9.0 + band * 5.0
		var base_x := fposmod(_elapsed * speed + band * 610.0, 3400.0) - 420.0
		var y := 230.0 + band * 92.0
		for cluster in range(4):
			var center := Vector2(base_x + cluster * 780.0, y + sin(_elapsed * 0.45 + cluster) * 14.0)
			var color := Color(0.62, 0.79, 0.88, 0.065 + band * 0.008)
			draw_circle(center, 54.0, color)
			draw_circle(center + Vector2(52, -14), 42.0, color)
			draw_circle(center + Vector2(98, 6), 48.0, color)
			draw_line(center - Vector2(44, -32), center + Vector2(146, 32), Color(color, color.a * 0.75), 22.0)

func _draw_distant_dojo() -> void:
	var bases := [Vector2(360, 470), Vector2(1460, 420), Vector2(2540, 455)]
	for index in range(bases.size()):
		var base: Vector2 = bases[index]
		var scale_factor := 0.80 if index != 1 else 1.05
		var ink := Color(0.025, 0.035, 0.050, 0.72)
		draw_rect(Rect2(base + Vector2(-38, -92) * scale_factor, Vector2(76, 92) * scale_factor), ink)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-105, -86) * scale_factor,
			base + Vector2(0, -138) * scale_factor,
			base + Vector2(105, -86) * scale_factor
		]), ink)
		draw_line(base + Vector2(-112, -84) * scale_factor, base + Vector2(112, -84) * scale_factor, Color(0.78, 0.36, 0.25, 0.34), 5.0)
		for pillar in [-26.0, 26.0]:
			draw_line(base + Vector2(pillar, -82) * scale_factor, base + Vector2(pillar, -4) * scale_factor, Color(0.40, 0.25, 0.20, 0.38), 6.0)

func _draw_waterfalls() -> void:
	var falls := [
		{"origin": Vector2(1060, 300), "height": 475.0, "width": 38.0},
		{"origin": Vector2(2050, 290), "height": 510.0, "width": 52.0},
		{"origin": Vector2(2650, 455), "height": 360.0, "width": 30.0}
	]
	for fall in falls:
		var origin: Vector2 = fall["origin"]
		var height := float(fall["height"])
		var width := float(fall["width"])
		for stripe in range(5):
			var offset := (float(stripe) - 2.0) * width * 0.18
			var wave := sin(_elapsed * 2.2 + stripe * 1.3) * 6.0
			draw_line(origin + Vector2(offset, 0), origin + Vector2(offset + wave, height), Color(0.38, 0.78, 0.94, 0.12 + stripe * 0.018), width * 0.16)
		draw_circle(origin + Vector2(0, height), width * 0.8 + sin(_elapsed * 3.0) * 4.0, Color(0.50, 0.84, 0.96, 0.10))

func _draw_banners() -> void:
	var anchors := [Vector2(310, 545), Vector2(770, 390), Vector2(1390, 480), Vector2(2180, 285), Vector2(2570, 465)]
	var route_colors := [Color(0.24, 0.66, 0.92, 0.52), Color(0.92, 0.38, 0.22, 0.52), Color(0.62, 0.35, 0.88, 0.52)]
	for index in range(anchors.size()):
		var anchor: Vector2 = anchors[index]
		var sway := sin(_elapsed * 1.4 + index * 0.8) * 13.0
		draw_line(anchor, anchor + Vector2(0, 98), Color(0.72, 0.60, 0.38, 0.55), 4.0)
		var color: Color = route_colors[index % route_colors.size()]
		draw_colored_polygon(PackedVector2Array([
			anchor + Vector2(4, 10), anchor + Vector2(58 + sway, 22),
			anchor + Vector2(46 + sway, 72), anchor + Vector2(5, 60)
		]), color)
		draw_line(anchor + Vector2(12, 28), anchor + Vector2(44 + sway, 40), color.lightened(0.28), 3.0)

func _draw_route_glyphs() -> void:
	var glyphs := [
		{"center": Vector2(720, 305), "color": Color(0.28, 0.72, 1.0, 0.32), "phase": 0.0},
		{"center": Vector2(1240, 690), "color": Color(1.0, 0.40, 0.22, 0.32), "phase": 2.0},
		{"center": Vector2(1950, 470), "color": Color(0.68, 0.38, 1.0, 0.32), "phase": 4.0}
	]
	for glyph in glyphs:
		var center: Vector2 = glyph["center"]
		var color: Color = glyph["color"]
		var phase := float(glyph["phase"])
		var radius := 27.0 + sin(_elapsed * 2.0 + phase) * 4.0
		draw_arc(center, radius, 0.0, TAU, 24, color, 3.0)
		draw_arc(center, radius + 10.0, _elapsed * 0.25 + phase, _elapsed * 0.25 + phase + 4.4, 18, Color(color, color.a * 0.65), 2.0)
		draw_line(center + Vector2(-12, 0), center + Vector2(12, 0), color.lightened(0.2), 3.0)
		draw_line(center + Vector2(0, -12), center + Vector2(0, 12), color.lightened(0.2), 3.0)

func _draw_lanterns() -> void:
	for index in range(18):
		var x := 90.0 + index * 158.0
		var y := 535.0 + sin(index * 1.7) * 44.0
		var flicker := 0.75 + sin(_elapsed * 5.0 + index) * 0.18
		draw_line(Vector2(x, y - 26), Vector2(x, y), Color(0.45, 0.34, 0.24, 0.45), 2.0)
		draw_circle(Vector2(x, y + 8), 9.0 + flicker * 2.0, Color(1.0, 0.56, 0.22, 0.10))
		draw_rect(Rect2(x - 5, y + 2, 10, 14), Color(1.0, 0.52, 0.20, 0.48 * flicker))

func _draw_comic_ink() -> void:
	var closure_stage := arena.closure_stage() if is_instance_valid(arena) else 0
	var intensity := 0.10 + closure_stage * 0.05
	if _round_active:
		intensity += 0.05
	for index in range(14):
		var y := 95.0 + index * 58.0
		var offset := sin(_elapsed * 1.8 + index) * 22.0
		draw_line(Vector2(-240 + offset, y), Vector2(120 + offset, y + 28), Color(0.82, 0.92, 1.0, intensity * 0.32), 3.0)
		draw_line(Vector2(3010 - offset, y + 12), Vector2(2700 - offset, y + 42), Color(1.0, 0.46, 0.24, intensity * 0.28), 3.0)
	if closure_stage > 0:
		var boundary_x := arena.camera_left_limit() - 420.0
		for index in range(10):
			var start := Vector2(boundary_x - 120 + index * 8, 120 + index * 78)
			draw_line(start, start + Vector2(160, 58), Color(1.0, 0.24, 0.10, 0.13 + closure_stage * 0.035), 5.0)
