class_name FirstPlayableArenaFinalLayer
extends Node2D

var _elapsed := 0.0

func _ready() -> void:
	z_index = 2
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()

func presentation_signature() -> Dictionary:
	return {
		"arena_id": &"ruins_of_the_triple_path",
		"art_direction": &"martial_fantasy_comic_manga_2_5d",
		"depth_layers": 4,
		"foreground_elements": 12,
		"animated_ambient_elements": 18,
		"collision_changes": false,
		"purple_tech_glow": false,
		"signature": "Tehkné Solutions"
	}

func _draw() -> void:
	_draw_depth_fog()
	_draw_hanging_banners()
	_draw_lanterns()
	_draw_foreground_rocks()
	_draw_reeds()
	_draw_ambient_leaves()
	_draw_vignette_edges()

func _draw_depth_fog() -> void:
	for layer in range(3):
		var y := 575.0 + layer * 92.0
		var alpha := 0.075 - layer * 0.016
		var offset := fposmod(_elapsed * (7.0 + layer * 3.0), 420.0)
		for segment in range(9):
			var x := -360.0 + segment * 420.0 + offset
			draw_circle(Vector2(x, y), 175.0 + layer * 26.0, Color(0.68, 0.78, 0.76, alpha))

func _draw_hanging_banners() -> void:
	var banners := [
		{"anchor": Vector2(520, 390), "route": Color(0.12, 0.42, 0.64, 0.88)},
		{"anchor": Vector2(1460, 330), "route": Color(0.66, 0.20, 0.12, 0.88)},
		{"anchor": Vector2(2380, 420), "route": Color(0.66, 0.46, 0.12, 0.88)}
	]
	for index in range(banners.size()):
		var item: Dictionary = banners[index]
		var anchor: Vector2 = item["anchor"]
		var color: Color = item["route"]
		var sway := sin(_elapsed * 1.15 + index * 0.8) * 7.0
		draw_line(anchor + Vector2(-4, -90), anchor + Vector2(-4, 12), Color(0.18, 0.14, 0.10, 0.92), 5.0)
		draw_colored_polygon(PackedVector2Array([
			anchor + Vector2(0, -78),
			anchor + Vector2(54 + sway, -66),
			anchor + Vector2(48 + sway, 4),
			anchor + Vector2(23 + sway * 0.45, -6),
			anchor + Vector2(0, 2)
		]), color)
		draw_line(anchor + Vector2(8, -58), anchor + Vector2(39 + sway, -48), Color(0.92, 0.82, 0.52, 0.58), 3.0)

func _draw_lanterns() -> void:
	var positions := [Vector2(345, 684), Vector2(835, 545), Vector2(1325, 530), Vector2(2025, 558), Vector2(2665, 690)]
	for index in range(positions.size()):
		var p: Vector2 = positions[index]
		var pulse := 0.76 + sin(_elapsed * 2.1 + index) * 0.10
		draw_line(p + Vector2(0, -45), p, Color(0.16, 0.12, 0.09, 0.95), 3.0)
		draw_rect(Rect2(p + Vector2(-10, -32), Vector2(20, 25)), Color(0.70, 0.24, 0.10, 0.92))
		draw_circle(p + Vector2(0, -20), 25.0, Color(1.0, 0.48, 0.16, 0.10 * pulse))
		draw_line(p + Vector2(-8, -25), p + Vector2(8, -25), Color(0.98, 0.76, 0.34, 0.76), 2.0)

func _draw_foreground_rocks() -> void:
	var rocks := [
		Rect2(-90, 792, 240, 150), Rect2(330, 845, 130, 95), Rect2(915, 835, 180, 110),
		Rect2(1530, 842, 145, 100), Rect2(2180, 825, 210, 125), Rect2(2820, 786, 240, 165)
	]
	for index in range(rocks.size()):
		var rect: Rect2 = rocks[index]
		var points := PackedVector2Array([
			Vector2(rect.position.x, rect.end.y),
			Vector2(rect.position.x + rect.size.x * 0.20, rect.position.y + rect.size.y * 0.30),
			Vector2(rect.position.x + rect.size.x * 0.48, rect.position.y),
			Vector2(rect.position.x + rect.size.x * 0.78, rect.position.y + rect.size.y * 0.24),
			Vector2(rect.end.x, rect.end.y)
		])
		draw_colored_polygon(points, Color(0.055, 0.060, 0.064, 0.96))
		draw_polyline(points, Color(0.20, 0.22, 0.20, 0.58), 3.0)

func _draw_reeds() -> void:
	for index in range(28):
		var side := -1.0 if index < 14 else 1.0
		var local_index := index if index < 14 else index - 14
		var x := 12.0 + local_index * 27.0 if side < 0.0 else 3000.0 - local_index * 27.0
		var base := Vector2(x, 862.0)
		var height := 48.0 + float((index * 17) % 46)
		var sway := sin(_elapsed * 1.4 + index * 0.37) * 8.0
		draw_line(base, base + Vector2(sway, -height), Color(0.16, 0.30, 0.20, 0.82), 3.0)
		draw_line(base + Vector2(sway * 0.45, -height * 0.58), base + Vector2(14.0 * side + sway, -height * 0.72), Color(0.24, 0.40, 0.24, 0.68), 2.0)

func _draw_ambient_leaves() -> void:
	for index in range(18):
		var travel := fposmod(_elapsed * (34.0 + index % 4 * 8.0) + index * 173.0, 3420.0)
		var x := 3180.0 - travel
		var y := 250.0 + float((index * 71) % 480) + sin(_elapsed * 1.5 + index) * 22.0
		var angle := _elapsed * 1.8 + index
		var direction := Vector2(cos(angle), sin(angle)) * 7.0
		draw_line(Vector2(x, y) - direction, Vector2(x, y) + direction, Color(0.34, 0.47, 0.27, 0.62), 3.0)

func _draw_vignette_edges() -> void:
	draw_rect(Rect2(-220, 0, 250, 960), Color(0.015, 0.018, 0.020, 0.42))
	draw_rect(Rect2(2970, 0, 250, 960), Color(0.015, 0.018, 0.020, 0.42))

# Tehkné Solutions
