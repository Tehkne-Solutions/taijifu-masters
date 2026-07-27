class_name SanctuaryEnvironmentArt
extends Node2D

var _arena_id: StringName = &"triple_ruins"
var _elapsed := 0.0
var _round_active := false
var _rules: Dictionary = {}

func _ready() -> void:
	z_index = 1
	visible = false

func _process(delta: float) -> void:
	_elapsed += delta * (1.0 if _round_active else 0.32)
	visible = _arena_id == &"silent_sanctuary"
	if visible:
		queue_redraw()

func configure(config: Dictionary, rules: Dictionary) -> void:
	_arena_id = StringName(config.get("arena_id", &"triple_ruins"))
	_rules = rules.duplicate(true)
	visible = _arena_id == &"silent_sanctuary"
	queue_redraw()

func set_round_active(active: bool) -> void:
	_round_active = active
	queue_redraw()

func set_score_snapshot(_snapshot: Dictionary) -> void:
	queue_redraw()

func environment_signature() -> Dictionary:
	return {
		"arena_id": &"silent_sanctuary",
		"current_gates": 4,
		"lotus_lanterns": 18,
		"water_ribbons": 4,
		"floating_islands": 5,
		"animated_koi": true,
		"competitive_collision_changes": false
	}

func _draw() -> void:
	if _arena_id != &"silent_sanctuary":
		return
	_draw_sky()
	_draw_current_gates()
	_draw_floating_islands()
	_draw_water_ribbons()
	_draw_cloud_terraces()
	_draw_koi_constellations()
	_draw_lotus_lanterns()
	_draw_sanctuary_ink()

func _draw_sky() -> void:
	draw_rect(Rect2(-500, -220, 3800, 1100), Color(0.018, 0.085, 0.105, 0.78))
	for index in range(9):
		var y := -60.0 + index * 104.0
		var color := Color(0.25, 0.82, 0.88, 0.025 + index * 0.005)
		draw_line(Vector2(-420, y), Vector2(3200, y + sin(_elapsed * 0.18 + index) * 44.0), color, 42.0)

func _draw_current_gates() -> void:
	var centers := [Vector2(420, 300), Vector2(1080, 190), Vector2(1800, 240), Vector2(2500, 330)]
	var colors := [Color(0.30, 0.84, 1.0, 0.28), Color(0.42, 0.95, 0.80, 0.25), Color(0.72, 0.56, 1.0, 0.24), Color(1.0, 0.72, 0.42, 0.22)]
	for index in range(centers.size()):
		var center: Vector2 = centers[index]
		var pulse := sin(_elapsed * 1.1 + index) * 8.0
		var color: Color = colors[index]
		draw_arc(center, 74.0 + pulse, -2.7, 2.7, 42, color, 7.0)
		draw_arc(center, 98.0 - pulse * 0.4, -1.8, 3.2, 42, Color(color, color.a * 0.55), 3.0)
		for rune in range(6):
			var angle := _elapsed * 0.18 + rune * TAU / 6.0
			draw_circle(center + Vector2.from_angle(angle) * 116.0, 3.5, Color(color, color.a * 1.2))

func _draw_floating_islands() -> void:
	var islands := [
		{"center": Vector2(260, 480), "scale": 0.72},
		{"center": Vector2(780, 390), "scale": 0.92},
		{"center": Vector2(1470, 455), "scale": 1.10},
		{"center": Vector2(2160, 370), "scale": 0.88},
		{"center": Vector2(2790, 500), "scale": 0.70}
	]
	for index in range(islands.size()):
		var island: Dictionary = islands[index]
		var center: Vector2 = island["center"]
		var scale_factor := float(island["scale"])
		var bob := sin(_elapsed * 0.42 + index * 1.4) * 12.0
		center.y += bob
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-120, 0) * scale_factor,
			center + Vector2(120, 0) * scale_factor,
			center + Vector2(70, 58) * scale_factor,
			center + Vector2(0, 110) * scale_factor,
			center + Vector2(-72, 58) * scale_factor
		]), Color(0.055, 0.13, 0.14, 0.70))
		draw_line(center + Vector2(-112, -2) * scale_factor, center + Vector2(112, -2) * scale_factor, Color(0.36, 0.86, 0.72, 0.30), 5.0)
		_draw_island_pavilion(center + Vector2(0, -8), scale_factor)

func _draw_island_pavilion(center: Vector2, scale_factor: float) -> void:
	var ink := Color(0.025, 0.055, 0.065, 0.82)
	draw_rect(Rect2(center + Vector2(-28, -68) * scale_factor, Vector2(56, 68) * scale_factor), ink)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-76, -62) * scale_factor,
		center + Vector2(0, -100) * scale_factor,
		center + Vector2(76, -62) * scale_factor
	]), ink)
	draw_line(center + Vector2(-82, -60) * scale_factor, center + Vector2(82, -60) * scale_factor, Color(0.38, 0.94, 0.86, 0.26), 4.0)

func _draw_water_ribbons() -> void:
	for band in range(4):
		var base_y := 245.0 + band * 118.0
		var points := PackedVector2Array()
		for sample in range(20):
			var x := -220.0 + sample * 180.0
			var y := base_y + sin(_elapsed * (0.65 + band * 0.08) + sample * 0.55 + band) * (22.0 + band * 3.0)
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.32, 0.84, 0.96, 0.10 + band * 0.018), 18.0 - band * 2.5, true)
		draw_polyline(points, Color(0.70, 1.0, 0.94, 0.10), 3.0, true)

func _draw_cloud_terraces() -> void:
	for terrace in range(5):
		var x := fposmod(_elapsed * (8.0 + terrace * 2.4) + terrace * 620.0, 3400.0) - 420.0
		var y := 120.0 + terrace * 110.0
		for cluster in range(4):
			var center := Vector2(x + cluster * 840.0, y)
			var color := Color(0.72, 0.94, 0.96, 0.045 + terrace * 0.004)
			draw_circle(center, 46.0, color)
			draw_circle(center + Vector2(48, -8), 37.0, color)
			draw_circle(center + Vector2(92, 8), 44.0, color)

func _draw_koi_constellations() -> void:
	for koi in range(9):
		var phase := _elapsed * (0.48 + koi * 0.01) + koi * 0.72
		var center := Vector2(220.0 + koi * 310.0 + sin(phase) * 34.0, 145.0 + cos(phase * 0.8) * 54.0)
		var direction := Vector2(cos(phase), sin(phase) * 0.4).normalized()
		draw_line(center - direction * 18.0, center + direction * 18.0, Color(0.64, 0.96, 1.0, 0.20), 6.0)
		draw_colored_polygon(PackedVector2Array([
			center - direction * 18.0,
			center - direction * 32.0 + direction.rotated(PI * 0.5) * 9.0,
			center - direction * 32.0 - direction.rotated(PI * 0.5) * 9.0
		]), Color(0.52, 0.90, 1.0, 0.14))

func _draw_lotus_lanterns() -> void:
	for index in range(18):
		var x := 120.0 + index * 164.0
		var y := 555.0 + sin(index * 1.8 + _elapsed * 0.7) * 42.0
		var pulse := 0.78 + sin(_elapsed * 3.8 + index) * 0.18
		draw_circle(Vector2(x, y), 16.0, Color(0.54, 1.0, 0.84, 0.065 * pulse))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 9, y), Vector2(x, y - 8), Vector2(x + 9, y), Vector2(x, y + 8)
		]), Color(0.48, 0.94, 0.78, 0.36 * pulse))

func _draw_sanctuary_ink() -> void:
	var intensity := 0.08 + (0.04 if _round_active else 0.0)
	for index in range(12):
		var x := 50.0 + index * 260.0
		var sway := sin(_elapsed * 1.2 + index) * 18.0
		draw_arc(Vector2(x + sway, 620.0), 48.0 + index % 3 * 12.0, -2.8, -0.3, 18, Color(0.62, 0.94, 1.0, intensity), 2.0)
