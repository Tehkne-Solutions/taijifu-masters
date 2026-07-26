class_name ImpactDirector
extends Node2D

const CONNECT_INTERVAL := 0.35
const MAX_BURSTS := 18

@onready var camera: Camera2D = get_node("../Camera2D")

var _bursts: Array[Dictionary] = []
var _connect_timer := 0.0
var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_amplitude := 0.0
var _base_camera_offset := Vector2.ZERO
var _hitstop_token := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 80
	if is_instance_valid(camera):
		_base_camera_offset = camera.offset
	_connect_fighters()

func _process(delta: float) -> void:
	_connect_timer -= delta
	if _connect_timer <= 0.0:
		_connect_timer = CONNECT_INTERVAL
		_connect_fighters()

	_update_bursts(delta)
	_update_camera_shake(delta)
	queue_redraw()

func _connect_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		if not node.has_signal("impact_resolved"):
			continue
		var callback := Callable(self, "_on_impact_resolved")
		if not node.is_connected("impact_resolved", callback):
			node.connect("impact_resolved", callback)

func _on_impact_resolved(
	target: MasteredWeaponFighterController,
	attacker: FighterController,
	technique: TechniqueData,
	result_id: StringName,
	damage_applied: float,
	posture_applied: float,
	intensity: float,
	world_position: Vector2
) -> void:
	if not is_instance_valid(target) or not is_instance_valid(technique):
		return

	var path_id := StringName(technique.path)
	var text := _onomatopoeia(path_id, result_id)
	var color := _impact_color(path_id, result_id)
	var duration := 0.42 + intensity * 0.22
	_bursts.append({
		"position": world_position,
		"age": 0.0,
		"duration": duration,
		"text": text,
		"color": color,
		"path": path_id,
		"result": result_id,
		"intensity": intensity
	})
	while _bursts.size() > MAX_BURSTS:
		_bursts.pop_front()

	var shake_profile := _shake_profile(path_id, result_id, intensity)
	_start_shake(float(shake_profile[0]), float(shake_profile[1]))
	var hitstop_profile := _hitstop_profile(path_id, result_id, intensity)
	if float(hitstop_profile[0]) > 0.0:
		_apply_hitstop(float(hitstop_profile[0]), float(hitstop_profile[1]))

func _update_bursts(delta: float) -> void:
	for index in range(_bursts.size() - 1, -1, -1):
		_bursts[index]["age"] = float(_bursts[index]["age"]) + delta
		if float(_bursts[index]["age"]) >= float(_bursts[index]["duration"]):
			_bursts.remove_at(index)

func _update_camera_shake(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var ratio := 0.0
		if _shake_duration > 0.0:
			ratio = _shake_time / _shake_duration
		var amplitude := _shake_amplitude * ratio
		camera.offset = _base_camera_offset + Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude * 0.62, amplitude * 0.62)
		)
	else:
		camera.offset = camera.offset.lerp(_base_camera_offset, minf(1.0, delta * 18.0))

func _start_shake(duration: float, amplitude: float) -> void:
	if duration <= 0.0 or amplitude <= 0.0:
		return
	if duration >= _shake_time or amplitude >= _shake_amplitude:
		_shake_time = maxf(_shake_time, duration)
		_shake_duration = maxf(_shake_duration, duration)
		_shake_amplitude = maxf(_shake_amplitude, amplitude)

func _apply_hitstop(duration: float, time_scale: float) -> void:
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = minf(Engine.time_scale, time_scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for burst in _bursts:
		var age := float(burst["age"])
		var duration := float(burst["duration"])
		var progress := clampf(age / duration, 0.0, 1.0)
		var intensity := float(burst["intensity"])
		var position: Vector2 = burst["position"]
		var color: Color = burst["color"]
		var path_id: StringName = burst["path"]
		var result_id: StringName = burst["result"]
		var alpha := 1.0 - progress
		var scale := 0.72 + minf(progress * 2.4, 0.28) + intensity * 0.18
		var rise := Vector2(0.0, -progress * 22.0)
		var center := position + rise

		_draw_impact_lines(center, path_id, Color(color, alpha * 0.62), intensity, progress)
		draw_set_transform(center, 0.0, Vector2(scale, scale))
		var text := String(burst["text"])
		var font_size := int(22.0 + intensity * 18.0)
		var shadow_color := Color(0.02, 0.02, 0.035, alpha * 0.90)
		draw_string(font, Vector2(-font_size * 0.72 + 3.0, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, shadow_color)
		draw_string(font, Vector2(-font_size * 0.72, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color, alpha))
		if result_id == &"posture_break":
			draw_arc(Vector2.ZERO, 34.0 + progress * 22.0, 0.0, TAU, 20, Color(color, alpha * 0.72), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_impact_lines(
	center: Vector2,
	path_id: StringName,
	color: Color,
	intensity: float,
	progress: float
) -> void:
	var length := 28.0 + intensity * 42.0 + progress * 12.0
	match path_id:
		&"tai":
			for offset in [-16.0, 0.0, 16.0]:
				draw_line(center + Vector2(-length, offset), center + Vector2(-12.0, offset - 4.0), color, 2.5)
		&"ji":
			for index in range(7):
				var angle := TAU * float(index) / 7.0
				draw_line(center + Vector2.from_angle(angle) * 12.0, center + Vector2.from_angle(angle) * length, color, 3.2)
		&"fu":
			draw_arc(center, length * 0.55, -2.6, 1.8, 18, color, 3.0)
			draw_arc(center + Vector2(8.0, -6.0), length * 0.82, -0.8, 3.5, 22, Color(color, color.a * 0.72), 2.0)

func _onomatopoeia(path_id: StringName, result_id: StringName) -> String:
	match result_id:
		&"evaded":
			return "SWISH!"
		&"blocked":
			return "THOK!"
		&"parried":
			return "CLANG!"
		&"posture_break":
			return "KRAK!"
	match path_id:
		&"tai":
			return "VUSH!"
		&"ji":
			return "DOOM!"
		&"fu":
			return "FLUX!"
		_:
			return "WHAM!"

func _impact_color(path_id: StringName, result_id: StringName) -> Color:
	match result_id:
		&"parried":
			return Color(1.0, 0.92, 0.46)
		&"blocked":
			return Color(0.74, 0.80, 0.90)
		&"posture_break":
			return Color(1.0, 0.28, 0.18)
	return CombatVisualCatalog.path_color(path_id)

func _shake_profile(path_id: StringName, result_id: StringName, intensity: float) -> Array[float]:
	if result_id == &"evaded":
		return [0.0, 0.0]
	if result_id == &"parried":
		return [0.14, 7.0]
	if result_id == &"posture_break":
		return [0.24, 13.0]
	var duration := 0.08 + intensity * 0.10
	var amplitude := 2.0 + intensity * 6.0
	if path_id == &"ji":
		amplitude *= 1.32
	elif path_id == &"tai":
		duration *= 0.78
	return [duration, amplitude]

func _hitstop_profile(path_id: StringName, result_id: StringName, intensity: float) -> Array[float]:
	if result_id == &"evaded":
		return [0.0, 1.0]
	if result_id == &"parried":
		return [0.075, 0.08]
	if result_id == &"posture_break":
		return [0.105, 0.055]
	var duration := 0.022 + intensity * 0.038
	var scale := 0.18
	if path_id == &"ji":
		duration += 0.018
		scale = 0.10
	elif path_id == &"fu":
		duration += 0.008
		scale = 0.14
	if result_id == &"blocked":
		duration *= 0.72
	return [duration, scale]

func _exit_tree() -> void:
	_hitstop_token += 1
	Engine.time_scale = 1.0
	if is_instance_valid(camera):
		camera.offset = _base_camera_offset
