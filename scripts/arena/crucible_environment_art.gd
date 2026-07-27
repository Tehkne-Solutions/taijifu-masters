class_name CrucibleEnvironmentArt
extends Node2D

@onready var arena: TriplePathArena = get_node("../Arena")

var _arena_id: StringName = &"triple_ruins"
var _elapsed := 0.0
var _round_active := false
var _rules: Dictionary = {}

func _ready() -> void:
	z_index = 1
	visible = false

func _process(delta: float) -> void:
	_elapsed += delta * (1.0 if _round_active else 0.38)
	visible = _arena_id == &"ember_crucible"
	if visible:
		queue_redraw()

func configure(config: Dictionary, rules: Dictionary) -> void:
	_arena_id = StringName(config.get("arena_id", &"triple_ruins"))
	_rules = rules.duplicate(true)
	visible = _arena_id == &"ember_crucible"
	queue_redraw()

func set_round_active(active: bool) -> void:
	_round_active = active
	queue_redraw()

func set_score_snapshot(_snapshot: Dictionary) -> void:
	queue_redraw()

func environment_signature() -> Dictionary:
	return {
		"arena_id": &"ember_crucible",
		"lava_channels": 5,
		"forge_towers": 4,
		"ash_layers": 3,
		"ember_vents": 12,
		"animated_chains": true,
		"competitive_collision_changes": false
	}

func _draw() -> void:
	if _arena_id != &"ember_crucible":
		return
	_draw_ash_sky()
	_draw_black_ridges()
	_draw_forge_towers()
	_draw_lava_channels()
	_draw_hanging_chains()
	_draw_ember_vents()
	_draw_ash_storm()
	_draw_crucible_ink()

func _draw_ash_sky() -> void:
	draw_rect(Rect2(-500, -220, 3800, 1100), Color(0.10, 0.025, 0.018, 0.88))
	for layer in range(6):
		var y := -40.0 + layer * 132.0
		var color := Color(0.62, 0.12, 0.055, 0.025 + layer * 0.008)
		draw_line(Vector2(-400, y), Vector2(3200, y + 64.0), color, 56.0)

func _draw_black_ridges() -> void:
	var far := PackedVector2Array([
		Vector2(-300, 520), Vector2(180, 250), Vector2(460, 500), Vector2(880, 190),
		Vector2(1280, 520), Vector2(1760, 230), Vector2(2180, 520), Vector2(2700, 180), Vector2(3200, 520)
	])
	draw_colored_polygon(far, Color(0.035, 0.018, 0.022, 0.90))
	var near := PackedVector2Array([
		Vector2(-300, 650), Vector2(360, 380), Vector2(820, 640), Vector2(1260, 350),
		Vector2(1700, 650), Vector2(2250, 370), Vector2(2860, 650), Vector2(3240, 430)
	])
	draw_colored_polygon(near, Color(0.060, 0.022, 0.020, 0.86))
	for index in range(8):
		var x := 150.0 + index * 390.0
		draw_line(Vector2(x, 420), Vector2(x + 170, 610), Color(1.0, 0.28, 0.06, 0.10), 9.0)

func _draw_forge_towers() -> void:
	var towers := [Vector2(300, 520), Vector2(1020, 420), Vector2(2020, 450), Vector2(2780, 540)]
	for index in range(towers.size()):
		var base: Vector2 = towers[index]
		var height := 140.0 + index % 2 * 55.0
		var width := 70.0 + index % 3 * 10.0
		draw_rect(Rect2(base.x - width * 0.5, base.y - height, width, height), Color(0.028, 0.018, 0.021, 0.92))
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x - width * 0.72, base.y - height),
			Vector2(base.x, base.y - height - 45),
			Vector2(base.x + width * 0.72, base.y - height)
		]), Color(0.035, 0.018, 0.020, 0.94))
		var furnace_y := base.y - height * 0.45
		var glow := 0.7 + sin(_elapsed * 4.0 + index) * 0.22
		draw_circle(Vector2(base.x, furnace_y), 26.0, Color(1.0, 0.24, 0.04, 0.08 * glow))
		draw_rect(Rect2(base.x - 13, furnace_y - 20, 26, 40), Color(1.0, 0.22, 0.03, 0.40 * glow))

func _draw_lava_channels() -> void:
	for channel in range(5):
		var points := PackedVector2Array()
		var base_y := 520.0 + channel * 48.0
		for sample in range(22):
			var x := -260.0 + sample * 170.0
			var y := base_y + sin(sample * 0.52 + channel + _elapsed * (0.5 + channel * 0.04)) * 22.0
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.42, 0.04, 0.015, 0.58), 25.0 - channel * 2.0, true)
		draw_polyline(points, Color(1.0, 0.20, 0.02, 0.30), 9.0 - channel, true)
		draw_polyline(points, Color(1.0, 0.72, 0.14, 0.24), 2.5, true)

func _draw_hanging_chains() -> void:
	for chain in range(7):
		var anchor_x := 120.0 + chain * 450.0
		var length := 170.0 + chain % 3 * 48.0
		var sway := sin(_elapsed * 0.65 + chain) * 22.0
		var points := PackedVector2Array()
		for segment in range(10):
			var ratio := float(segment) / 9.0
			var x := anchor_x + sin(ratio * PI) * sway
			var y := -40.0 + ratio * length
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.22, 0.17, 0.16, 0.66), 7.0, true)
		for segment in range(1, 9, 2):
			draw_circle(points[segment], 7.0, Color(0.30, 0.20, 0.16, 0.52))

func _draw_ember_vents() -> void:
	var closure := arena.closure_stage() if is_instance_valid(arena) else 0
	var pressure := 1.0 + closure * 0.38 + (0.32 if _round_active else 0.0)
	for index in range(12):
		var x := 90.0 + index * 245.0
		var y := 560.0 + sin(index * 1.3) * 78.0
		var burst := maxf(0.0, sin(_elapsed * (2.4 + index * 0.03) + index * 0.9))
		for spark in range(4):
			var rise := (18.0 + spark * 17.0) * burst * pressure
			var offset := sin(_elapsed * 3.0 + spark + index) * 10.0
			draw_circle(Vector2(x + offset, y - rise), 2.5 + spark * 0.7, Color(1.0, 0.38 + spark * 0.08, 0.05, 0.22 + burst * 0.38))

func _draw_ash_storm() -> void:
	for layer in range(3):
		var speed := 24.0 + layer * 18.0
		for particle in range(26):
			var x := fposmod(_elapsed * speed + particle * 137.0 + layer * 310.0, 3400.0) - 300.0
			var y := 40.0 + fposmod(float(particle * 83 + layer * 47), 690.0)
			var length := 18.0 + layer * 8.0
			draw_line(Vector2(x, y), Vector2(x - length, y + 8.0), Color(0.72, 0.48, 0.36, 0.045 + layer * 0.018), 2.0 + layer)

func _draw_crucible_ink() -> void:
	var closure := arena.closure_stage() if is_instance_valid(arena) else 0
	var intensity := 0.08 + closure * 0.05 + (0.05 if _round_active else 0.0)
	for index in range(16):
		var y := 50.0 + index * 43.0
		var offset := sin(_elapsed * 1.8 + index) * 26.0
		draw_line(Vector2(-220 + offset, y), Vector2(160 + offset, y + 56), Color(1.0, 0.28, 0.05, intensity), 3.0)
		draw_line(Vector2(3140 - offset, y + 20), Vector2(2760 - offset, y + 72), Color(1.0, 0.56, 0.18, intensity * 0.78), 3.0)
