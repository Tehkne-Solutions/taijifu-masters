extends Node2D

const WORLD_SIZE := Vector2(7680.0, 3240.0)
const CAMERA_MARGIN := Vector2(320.0, 220.0)
const MIN_ZOOM := 0.56
const EMERGENCY_ZOOM := 0.48
const MAX_ZOOM := 1.05
const PLAYER_COLORS := [
	Color("2f8cff"),
	Color("ff4a3d"),
	Color("ffc83d"),
	Color("45d47a")
]

@onready var camera: Camera2D = $Camera2D
@onready var fighters: Array[Node2D] = [
	$Fighters/P1,
	$Fighters/P2,
	$Fighters/P3,
	$Fighters/P4
]

var _elapsed := 0.0

func _ready() -> void:
	camera.position = WORLD_SIZE * 0.5
	camera.zoom = Vector2.ONE * 0.72
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	_animate_test_fighters()
	_update_group_camera(delta)
	queue_redraw()

func _animate_test_fighters() -> void:
	var center := WORLD_SIZE * 0.5
	var offsets := [
		Vector2(-760.0 + sin(_elapsed * 0.70) * 260.0, 260.0 + sin(_elapsed * 1.10) * 120.0),
		Vector2(-180.0 + sin(_elapsed * 0.83 + 1.0) * 320.0, -180.0 + cos(_elapsed * 0.91) * 180.0),
		Vector2(420.0 + cos(_elapsed * 0.62) * 360.0, 120.0 + sin(_elapsed * 0.78 + 2.0) * 220.0),
		Vector2(980.0 + sin(_elapsed * 0.55 + 3.0) * 280.0, -320.0 + cos(_elapsed * 0.66) * 160.0)
	]
	for index in fighters.size():
		fighters[index].position = center + offsets[index]

func _update_group_camera(delta: float) -> void:
	if fighters.is_empty():
		return
	var bounds := Rect2(fighters[0].global_position, Vector2.ZERO)
	for fighter in fighters:
		bounds = bounds.expand(fighter.global_position)
	bounds = bounds.grow_individual(CAMERA_MARGIN.x, CAMERA_MARGIN.y, CAMERA_MARGIN.x, CAMERA_MARGIN.y)
	var viewport_size := get_viewport_rect().size
	var zoom_x := viewport_size.x / maxf(bounds.size.x, 1.0)
	var zoom_y := viewport_size.y / maxf(bounds.size.y, 1.0)
	var desired_zoom := minf(zoom_x, zoom_y)
	var readable_zoom := clampf(desired_zoom, MIN_ZOOM, MAX_ZOOM)
	if desired_zoom < MIN_ZOOM:
		readable_zoom = maxf(desired_zoom, EMERGENCY_ZOOM)
	var target := bounds.get_center()
	target.x = clampf(target.x, viewport_size.x * 0.5 / readable_zoom, WORLD_SIZE.x - viewport_size.x * 0.5 / readable_zoom)
	target.y = clampf(target.y, viewport_size.y * 0.5 / readable_zoom, WORLD_SIZE.y - viewport_size.y * 0.5 / readable_zoom)
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-5.5 * delta))
	camera.zoom = camera.zoom.lerp(Vector2.ONE * readable_zoom, 1.0 - exp(-4.5 * delta))

func _draw() -> void:
	_draw_world_layers()
	_draw_platforms()
	for index in fighters.size():
		_draw_fighter_marker(fighters[index].position, index)

func _draw_world_layers() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("24364a"))
	for band in 8:
		var y := 180.0 + band * 360.0
		var shade := Color(0.10 + band * 0.008, 0.16 + band * 0.006, 0.20 + band * 0.004, 1.0)
		draw_rect(Rect2(0.0, y, WORLD_SIZE.x, 210.0), shade)
	for column in 5:
		var x := column * 1920.0
		draw_line(Vector2(x, 0.0), Vector2(x, WORLD_SIZE.y), Color(1.0, 0.74, 0.24, 0.22), 5.0)
	for row in 4:
		var y := row * 1080.0
		draw_line(Vector2(0.0, y), Vector2(WORLD_SIZE.x, y), Color(1.0, 0.74, 0.24, 0.18), 5.0)

func _draw_platforms() -> void:
	var platforms := [
		Rect2(2500.0, 2100.0, 2680.0, 150.0),
		Rect2(2920.0, 1580.0, 920.0, 110.0),
		Rect2(4100.0, 1370.0, 1060.0, 110.0),
		Rect2(3440.0, 920.0, 720.0, 90.0),
		Rect2(5300.0, 1840.0, 860.0, 120.0)
	]
	for platform in platforms:
		draw_rect(platform, Color("374936"))
		draw_line(platform.position, platform.position + Vector2(platform.size.x, 0.0), Color("90b36c"), 10.0)

func _draw_fighter_marker(position: Vector2, player_index: int) -> void:
	var color: Color = PLAYER_COLORS[player_index]
	var shadow_position := position + Vector2(0.0, 62.0)
	draw_ellipse(shadow_position, Vector2(42.0, 12.0), Color(0.0, 0.0, 0.0, 0.38))
	draw_circle(position, 58.0, Color(0.02, 0.025, 0.035, 0.92))
	draw_arc(position, 61.0, 0.0, TAU, 40, color, 6.0)
	draw_circle(position + Vector2(0.0, -18.0), 23.0, color.darkened(0.22))
	draw_rect(Rect2(position + Vector2(-22.0, 8.0), Vector2(44.0, 52.0)), color.darkened(0.38))
	draw_line(position + Vector2(-24.0, 14.0), position + Vector2(-46.0, 42.0), color, 10.0)
	draw_line(position + Vector2(24.0, 14.0), position + Vector2(46.0, 42.0), color, 10.0)
	draw_string(ThemeDB.fallback_font, position + Vector2(-15.0, -76.0), "P%d" % (player_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 32:
		var angle := TAU * float(index) / 32.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
