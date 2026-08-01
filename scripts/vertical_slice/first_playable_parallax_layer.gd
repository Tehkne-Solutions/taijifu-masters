class_name FirstPlayableParallaxLayer
extends Node2D

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")

enum LayerKind { FAR, MID, FOREGROUND }

var layer_kind := LayerKind.FAR
var follow_ratio := Vector2(0.82, 0.92)
var _camera: Camera2D
var _camera_origin := Vector2.ZERO
var _base_position := Vector2.ZERO

func configure(kind: LayerKind) -> FirstPlayableParallaxLayer:
	layer_kind = kind
	match kind:
		LayerKind.FAR:
			follow_ratio = Vector2(0.82, 0.94)
			z_index = -13
		LayerKind.MID:
			follow_ratio = Vector2(0.55, 0.82)
			z_index = -11
		LayerKind.FOREGROUND:
			follow_ratio = Vector2(0.10, 0.36)
			z_index = 2
	return self

func _ready() -> void:
	_base_position = position
	_camera = get_parent().get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(_camera):
		_camera_origin = _camera.global_position
	queue_redraw()

func _process(_delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	var delta_from_origin := _camera.global_position - _camera_origin
	position = _base_position + Vector2(
		delta_from_origin.x * follow_ratio.x,
		delta_from_origin.y * follow_ratio.y
	)

func presentation_signature() -> Dictionary:
	return {
		"layer": LayerKind.keys()[layer_kind].to_lower(),
		"follow_ratio_x": follow_ratio.x,
		"follow_ratio_y": follow_ratio.y,
		"collision_changes": false,
		"physics_changes": false,
		"visual_policy": POLICY.DIRECTION,
		"signature": "Tehkné Solutions"
	}

func _draw() -> void:
	match layer_kind:
		LayerKind.FAR:
			_draw_far()
		LayerKind.MID:
			_draw_mid()
		LayerKind.FOREGROUND:
			_draw_foreground()

func _draw_far() -> void:
	var silhouettes := PackedVector2Array([
		Vector2(-520, 610), Vector2(-120, 390), Vector2(250, 535), Vector2(620, 315),
		Vector2(1030, 555), Vector2(1450, 350), Vector2(1910, 570), Vector2(2380, 330),
		Vector2(2860, 560), Vector2(3420, 390), Vector2(3780, 610), Vector2(3780, 760), Vector2(-520, 760)
	])
	draw_colored_polygon(silhouettes, Color(0.020, 0.038, 0.048, 0.48))
	for x in [-180.0, 720.0, 1640.0, 2570.0, 3340.0]:
		draw_circle(Vector2(x, 420), 155.0, Color(POLICY.JADE, 0.025))

func _draw_mid() -> void:
	for x in [-120.0, 620.0, 1370.0, 2110.0, 2860.0, 3520.0]:
		var base := Vector2(x, 585)
		draw_line(base, base + Vector2(0, -155), Color(0.045, 0.065, 0.058, 0.72), 10.0)
		draw_line(base + Vector2(0, -118), base + Vector2(-54, -170), Color(0.050, 0.075, 0.064, 0.64), 7.0)
		draw_line(base + Vector2(0, -96), base + Vector2(62, -145), Color(0.050, 0.075, 0.064, 0.58), 6.0)
		draw_circle(base + Vector2(-58, -173), 31.0, Color(0.08, 0.12, 0.10, 0.34))
		draw_circle(base + Vector2(65, -148), 28.0, Color(0.08, 0.12, 0.10, 0.30))

func _draw_foreground() -> void:
	for x in [-260.0, 420.0, 1120.0, 1850.0, 2580.0, 3300.0, 3940.0]:
		var y := 738.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 125, y + 40), Vector2(x - 72, y - 16), Vector2(x - 8, y + 5),
			Vector2(x + 48, y - 34), Vector2(x + 126, y + 40)
		]), Color(0.018, 0.024, 0.022, 0.88))
		draw_line(Vector2(x - 104, y + 24), Vector2(x + 98, y + 24), Color(POLICY.GOLD, 0.10), 2.0)

# Tehkné Solutions
