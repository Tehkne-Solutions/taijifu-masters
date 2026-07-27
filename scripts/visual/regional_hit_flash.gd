class_name RegionalHitFlash
extends Node2D

const FLASH_DURATION := 0.24

var _fighter: MasteredWeaponFighterController
var _timer := 0.0
var _region_id: StringName = &"torso"
var _result_id: StringName = &"hit"
var _intensity := 0.0

func _ready() -> void:
	_fighter = get_parent() as MasteredWeaponFighterController
	z_index = 7
	if is_instance_valid(_fighter) and _fighter.has_signal("regional_hit_received"):
		_fighter.regional_hit_received.connect(_on_regional_hit_received)

func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer = maxf(0.0, _timer - delta)
	queue_redraw()

func preview_hit(region_id: StringName, result_id: StringName = &"hit", intensity: float = 0.8) -> void:
	_region_id = region_id
	_result_id = result_id
	_intensity = clampf(intensity, 0.1, 1.0)
	_timer = FLASH_DURATION
	queue_redraw()

func active_region_id() -> StringName:
	return _region_id

func is_flash_active() -> bool:
	return _timer > 0.0

func _on_regional_hit_received(
	_fighter_source: MasteredWeaponFighterController,
	region_id: StringName,
	result_id: StringName,
	intensity: float
) -> void:
	preview_hit(region_id, result_id, intensity)

func _draw() -> void:
	if _timer <= 0.0:
		return
	var life := clampf(_timer / FLASH_DURATION, 0.0, 1.0)
	var pulse := 1.0 + (1.0 - life) * 0.38
	var color := _result_color()
	color.a = life * (0.38 + _intensity * 0.52)
	match _region_id:
		&"head":
			_draw_head_flash(color, pulse)
		&"legs":
			_draw_legs_flash(color, pulse)
		_:
			_draw_torso_flash(color, pulse)

func _result_color() -> Color:
	match _result_id:
		&"blocked":
			return Color(1.0, 0.78, 0.28, 1.0)
		&"parried":
			return Color(0.42, 0.92, 1.0, 1.0)
		&"evaded":
			return Color(0.72, 0.80, 0.94, 1.0)
		&"posture_break":
			return Color(0.92, 0.58, 1.0, 1.0)
		_:
			return Color(1.0, 0.30, 0.24, 1.0)

func _draw_head_flash(color: Color, pulse: float) -> void:
	var center := Vector2(0.0, -49.0)
	draw_circle(center, 18.0 * pulse, Color(color, color.a * 0.22))
	draw_arc(center, 20.0 * pulse, 0.0, TAU, 20, color, 3.2)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var start := center + Vector2.from_angle(angle) * 20.0
		var finish := center + Vector2.from_angle(angle) * (27.0 + _intensity * 8.0) * pulse
		draw_line(start, finish, color, 2.0)

func _draw_torso_flash(color: Color, pulse: float) -> void:
	var center := Vector2(0.0, -17.0)
	var width := 27.0 * pulse
	var height := 34.0 * pulse
	var burst := PackedVector2Array([
		center + Vector2(-width, -6.0),
		center + Vector2(-12.0, -height),
		center + Vector2(0.0, -22.0),
		center + Vector2(14.0, -height + 4.0),
		center + Vector2(width, -4.0),
		center + Vector2(15.0, height),
		center + Vector2(0.0, 23.0),
		center + Vector2(-16.0, height - 2.0)
	])
	draw_colored_polygon(burst, Color(color, color.a * 0.25))
	draw_polyline(PackedVector2Array(Array(burst) + [burst[0]]), color, 2.8)

func _draw_legs_flash(color: Color, pulse: float) -> void:
	var center := Vector2(0.0, 20.0)
	draw_arc(center, 26.0 * pulse, 0.12, PI - 0.12, 18, color, 4.0)
	for index in range(4):
		var side := -1.0 if index % 2 == 0 else 1.0
		var x := side * (10.0 + float(index) * 5.0)
		draw_line(center + Vector2(x, 7.0), center + Vector2(x + side * 12.0, 18.0 + float(index) * 2.0), color, 2.4)
