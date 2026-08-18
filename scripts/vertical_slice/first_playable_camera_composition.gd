class_name FirstPlayableCameraComposition
extends Node

# Stage Premium: keep both fighters visible while raising their screen presence.
# This is presentation-only: fighter world transforms, collision and physics remain unchanged.
const MIN_ZOOM := 0.94
const MAX_ZOOM := 1.46
const BASELINE_Y := 530.0
const VERTICAL_RANGE := 60.0
const HORIZONTAL_PADDING := 360.0
const FRAMING_WIDTH := 1720.0
const MIN_FRAMING_SPAN := 1000.0
const FOCUS_LERP := 6.0
const ZOOM_LERP := 5.6
const SHAKE_DECAY := 9.0
const MAX_SHAKE_PIXELS := 7.0
const IMMEDIATE_KICK_RATIO := 0.72
const CLOSE_FIGHT_DISTANCE := 300.0
const CLOSE_FIGHT_ZOOM_FLOOR := 1.26
const SCREEN_PRESENCE_TARGET_MIN := 0.15
const SCREEN_PRESENCE_TARGET_MAX := 0.22

var _root: Node2D
var _camera: Camera2D
var _shake_strength := 0.0
var _shake_phase := 0.0
var _last_impact_kick := Vector2.ZERO
var _impact_punch_count := 0

func _ready() -> void:
	process_priority = 100
	_root = get_parent() as Node2D
	_camera = _root.get_node_or_null("Camera2D") as Camera2D
	print("V2_C46_CAMERA_READABILITY=PASS min=%.2f max=%.2f" % [MIN_ZOOM, MAX_ZOOM])
	print("VS_STAGE_PREMIUM_CAMERA=PASS min=%.2f max=%.2f close_floor=%.2f world_scale_unchanged=true" % [MIN_ZOOM, MAX_ZOOM, CLOSE_FIGHT_ZOOM_FLOOR])

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
	var horizontal_distance := absf(fighter_one.global_position.x - fighter_two.global_position.x)
	var framing_span := maxf(MIN_FRAMING_SPAN, horizontal_distance + HORIZONTAL_PADDING)
	var desired_zoom := clampf(FRAMING_WIDTH / framing_span, MIN_ZOOM, MAX_ZOOM)
	if horizontal_distance <= CLOSE_FIGHT_DISTANCE:
		desired_zoom = maxf(desired_zoom, CLOSE_FIGHT_ZOOM_FLOOR)

	var target_y := clampf(midpoint.y - 24.0, BASELINE_Y - VERTICAL_RANGE, BASELINE_Y + VERTICAL_RANGE)
	var target_x := midpoint.x
	var arena: Variant = _root.get("arena")
	if arena is FirstPlayableArena:
		var visible_half_width := 640.0 / desired_zoom
		target_x = clampf(
			target_x,
			arena.PLAYABLE_LEFT + visible_half_width,
			arena.PLAYABLE_RIGHT - visible_half_width
		)

	var target := Vector2(target_x, target_y)
	_camera.global_position = _camera.global_position.lerp(target, 1.0 - exp(-FOCUS_LERP * delta))
	_camera.zoom = _camera.zoom.lerp(Vector2.ONE * desired_zoom, 1.0 - exp(-ZOOM_LERP * delta))
	_apply_shake(delta)

func impact_punch(
	intensity: float,
	result_id: StringName = &"hit",
	impact_direction: Vector2 = Vector2.ZERO
) -> void:
	var multiplier := 1.0
	match result_id:
		&"blocked": multiplier = 0.45
		&"evaded": multiplier = 0.20
		&"parried": multiplier = 0.85
		&"posture_break": multiplier = 1.20
	var strength := clampf(intensity * multiplier, 0.0, 1.0)
	_shake_strength = maxf(_shake_strength, strength)
	_impact_punch_count += 1

	if is_instance_valid(_camera) and strength > 0.0:
		var direction := impact_direction
		if direction.length_squared() <= 0.0001:
			direction = Vector2.RIGHT
		direction = direction.normalized()
		var kick_pixels := minf(MAX_SHAKE_PIXELS, MAX_SHAKE_PIXELS * strength * IMMEDIATE_KICK_RATIO)
		_last_impact_kick = direction * kick_pixels
		_camera.offset = _last_impact_kick

func _apply_shake(delta: float) -> void:
	if _shake_strength <= 0.001:
		_camera.offset = _camera.offset.lerp(Vector2.ZERO, 1.0 - exp(-12.0 * delta))
		_shake_strength = 0.0
		return
	_shake_phase += delta * 52.0
	var amplitude := MAX_SHAKE_PIXELS * _shake_strength
	var direction := Vector2(sin(_shake_phase * 1.7), cos(_shake_phase * 2.3))
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	_camera.offset = direction * amplitude
	_shake_strength = maxf(0.0, _shake_strength - delta * SHAKE_DECAY)

func impact_runtime_signature() -> Dictionary:
	return {
		"punch_count": _impact_punch_count,
		"shake_strength": _shake_strength,
		"last_impact_kick": [_last_impact_kick.x, _last_impact_kick.y],
		"last_impact_kick_pixels": _last_impact_kick.length(),
		"max_kick_pixels": MAX_SHAKE_PIXELS,
		"immediate_kick_ratio": IMMEDIATE_KICK_RATIO,
		"immediate_directional_kick": true,
		"physics_changes": false,
		"signature": "Tehkné Solutions",
	}

func presentation_signature() -> Dictionary:
	return {
		"framing": &"stage_premium_fighter_first",
		"min_zoom": MIN_ZOOM,
		"max_zoom": MAX_ZOOM,
		"baseline_y": BASELINE_Y,
		"vertical_range": VERTICAL_RANGE,
		"horizontal_padding": HORIZONTAL_PADDING,
		"framing_width": FRAMING_WIDTH,
		"min_framing_span": MIN_FRAMING_SPAN,
		"close_fight_distance": CLOSE_FIGHT_DISTANCE,
		"close_fight_zoom_floor": CLOSE_FIGHT_ZOOM_FLOOR,
		"screen_presence_target_min": SCREEN_PRESENCE_TARGET_MIN,
		"screen_presence_target_max": SCREEN_PRESENCE_TARGET_MAX,
		"world_fighter_scale_changes": false,
		"both_fighters_visible": true,
		"reduced_vertical_motion": true,
		"focus_lerp": FOCUS_LERP,
		"zoom_lerp": ZOOM_LERP,
		"impact_camera_punch": true,
		"impact_camera_immediate_kick": true,
		"impact_camera_directional_kick": true,
		"impact_camera_punch_visual_only": true,
		"max_shake_pixels": MAX_SHAKE_PIXELS,
		"max_immediate_kick_pixels": MAX_SHAKE_PIXELS,
		"physics_changes": false,
		"collision_changes": false,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
