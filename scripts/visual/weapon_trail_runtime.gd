class_name WeaponTrailRuntime
extends Node2D

const MAX_POINTS := 22
const MIN_SAMPLE_DISTANCE := 3.0

var _fighter: FighterController
var _overlay: FighterVisualOverlay
var _points: Array[Dictionary] = []
var _last_tip := Vector2.INF

func _ready() -> void:
	_fighter = get_parent() as FighterController
	_overlay = get_node_or_null("../VisualOverlay") as FighterVisualOverlay
	z_index = 4

func _process(delta: float) -> void:
	_age_points(delta)
	if not is_instance_valid(_fighter) or not is_instance_valid(_overlay):
		queue_redraw()
		return
	var context := _overlay.current_visual_context()
	var phase_id := StringName(context.get("phase_id", &"none"))
	var profile := _overlay.current_trail_profile()
	var enabled := bool(profile.get("enabled", false))
	if enabled and phase_id in [&"startup", &"active", &"recovery"]:
		_sample_tip(profile, phase_id)
	else:
		_last_tip = Vector2.INF
	queue_redraw()

func point_count() -> int:
	return _points.size()

func clear_trail() -> void:
	_points.clear()
	_last_tip = Vector2.INF
	queue_redraw()

func add_test_point(world_position: Vector2, duration: float = 0.2) -> void:
	_points.append({"position": world_position, "age": 0.0, "duration": duration, "width": 5.0, "opacity": 0.7, "color": Color.WHITE})
	queue_redraw()

func _sample_tip(profile: Dictionary, phase_id: StringName) -> void:
	var tip := _overlay.current_weapon_tip_global()
	if _last_tip != Vector2.INF and tip.distance_to(_last_tip) < MIN_SAMPLE_DISTANCE:
		return
	if _last_tip != Vector2.INF and tip.distance_to(_last_tip) > 180.0:
		_points.clear()
	var opacity := float(profile.get("opacity", 0.62))
	if phase_id == &"startup": opacity *= 0.42
	elif phase_id == &"recovery": opacity *= 0.56
	_points.append({
		"position": tip,
		"age": 0.0,
		"duration": maxf(0.06, float(profile.get("duration", 0.2))),
		"width": maxf(1.0, float(profile.get("width", 6.0))),
		"opacity": opacity,
		"color": _overlay.current_trail_color()
	})
	_last_tip = tip
	while _points.size() > MAX_POINTS:
		_points.pop_front()

func _age_points(delta: float) -> void:
	for index in range(_points.size() - 1, -1, -1):
		_points[index]["age"] = float(_points[index].get("age", 0.0)) + delta
		if float(_points[index]["age"]) >= float(_points[index].get("duration", 0.2)):
			_points.remove_at(index)

func _draw() -> void:
	if _points.size() < 2:
		return
	for index in range(1, _points.size()):
		var previous: Dictionary = _points[index - 1]
		var current: Dictionary = _points[index]
		var duration := maxf(0.01, float(current.get("duration", 0.2)))
		var life := clampf(1.0 - float(current.get("age", 0.0)) / duration, 0.0, 1.0)
		var color: Color = current.get("color", Color.WHITE)
		color.a = life * float(current.get("opacity", 0.62))
		var width := float(current.get("width", 6.0)) * (0.35 + life * 0.65)
		draw_line(
			to_local(previous.get("position", Vector2.ZERO)),
			to_local(current.get("position", Vector2.ZERO)),
			color,
			width,
			true
		)
