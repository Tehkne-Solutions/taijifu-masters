class_name FirstPlayableCameraComposition
extends Node

const MIN_ZOOM := 0.76
const MAX_ZOOM := 1.02
const BASELINE_Y := 470.0
const VERTICAL_RANGE := 105.0
const FOCUS_LERP := 7.0
const ZOOM_LERP := 6.0

var _root: Node2D
var _camera: Camera2D

func _ready() -> void:
	process_priority = 100
	_root = get_parent() as Node2D
	_camera = _root.get_node_or_null("Camera2D") as Camera2D

func _process(delta: float) -> void:
	if not is_instance_valid(_root) or not is_instance_valid(_camera):
		return
	var p1: Variant = _root.get("player_one")
	var p2: Variant = _root.get("player_two")
	if not p1 is FighterController or not p2 is FighterController:
		return
	var fighter_one := p1 as FighterController
	var fighter_two := p2 as FighterController
	if not is_instance_valid(fighter_one) or not is_instance_valid(fighter_two):
		return

	var midpoint := (fighter_one.global_position + fighter_two.global_position) * 0.5
	var target_y := clampf(midpoint.y - 52.0, BASELINE_Y - VERTICAL_RANGE, BASELINE_Y + VERTICAL_RANGE)
	var arena: Variant = _root.get("arena")
	var target_x := midpoint.x
	if arena is FirstPlayableArena:
		target_x = clampf(target_x, arena.camera_left_limit() + 90.0, TriplePathArena.WORLD_WIDTH - 510.0)
	var target := Vector2(target_x, target_y)
	_camera.global_position = _camera.global_position.lerp(target, 1.0 - exp(-FOCUS_LERP * delta))

	var horizontal_distance := absf(fighter_one.global_position.x - fighter_two.global_position.x)
	var desired_zoom := clampf(1060.0 / maxf(820.0, horizontal_distance + 330.0), MIN_ZOOM, MAX_ZOOM)
	_camera.zoom = _camera.zoom.lerp(Vector2.ONE * desired_zoom, 1.0 - exp(-ZOOM_LERP * delta))

func presentation_signature() -> Dictionary:
	return {
		"framing": &"fighter_first",
		"min_zoom": MIN_ZOOM,
		"max_zoom": MAX_ZOOM,
		"vertical_range": VERTICAL_RANGE,
		"focus_lerp": FOCUS_LERP,
		"zoom_lerp": ZOOM_LERP,
		"physics_changes": false,
		"collision_changes": false,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
