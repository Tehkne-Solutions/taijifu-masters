class_name InputGhostVisual
extends Node2D

signal playback_finished

var frames: Array = []
var playing := false
var elapsed_ms := 0.0
var duration_ms := 0.0
var current_actions: Array[String] = []
var current_phase := 0
var current_weapon := "unarmed"
var _cursor := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 90
	modulate = Color(0.48, 0.92, 1.0, 0.72)
	visible = false
	queue_redraw()

func play(recording_frames: Array) -> bool:
	frames = recording_frames.duplicate(true)
	if frames.size() < 2:
		stop()
		return false
	elapsed_ms = 0.0
	_cursor = 0
	duration_ms = float((frames.back() as Dictionary).get("t", 0.0))
	playing = duration_ms > 0.0
	visible = playing
	if playing:
		_apply_frame(frames[0] as Dictionary)
	queue_redraw()
	return playing

func stop() -> void:
	var was_playing := playing
	playing = false
	visible = false
	elapsed_ms = 0.0
	_cursor = 0
	current_actions.clear()
	queue_redraw()
	if was_playing:
		playback_finished.emit()

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed_ms += delta * 1000.0
	if elapsed_ms >= duration_ms:
		_apply_frame(frames.back() as Dictionary)
		stop()
		return
	while _cursor + 1 < frames.size() and float((frames[_cursor + 1] as Dictionary).get("t", 0.0)) <= elapsed_ms:
		_cursor += 1
	var current := frames[_cursor] as Dictionary
	var following := frames[mini(_cursor + 1, frames.size() - 1)] as Dictionary
	var current_t := float(current.get("t", 0.0))
	var following_t := float(following.get("t", current_t))
	var ratio := 0.0 if following_t <= current_t else clampf((elapsed_ms - current_t) / (following_t - current_t), 0.0, 1.0)
	var current_position := _vector_from(current.get("position", [0.0, 0.0]))
	var following_position := _vector_from(following.get("position", current.get("position", [0.0, 0.0])))
	global_position = current_position.lerp(following_position, ratio)
	_apply_frame(current)
	queue_redraw()

func _apply_frame(frame: Dictionary) -> void:
	global_position = _vector_from(frame.get("position", [global_position.x, global_position.y]))
	var facing := float(frame.get("facing", 1.0))
	scale.x = -1.0 if facing < 0.0 else 1.0
	current_phase = int(frame.get("phase", 0))
	current_weapon = String(frame.get("weapon", "unarmed"))
	current_actions.clear()
	var inputs: Dictionary = frame.get("inputs", {})
	for action_id in inputs.keys():
		if float(inputs[action_id]) > 0.15:
			current_actions.append(String(action_id))

func _vector_from(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO

func _draw() -> void:
	if not visible:
		return
	var phase_color := Color(0.35, 0.86, 1.0, 0.72)
	match current_phase:
		1:
			phase_color = Color(1.0, 0.82, 0.30, 0.78)
		2:
			phase_color = Color(1.0, 0.38, 0.28, 0.84)
		3:
			phase_color = Color(0.65, 0.48, 1.0, 0.72)
	var ink := Color(0.04, 0.12, 0.22, 0.82)
	var aura := Color(phase_color.r, phase_color.g, phase_color.b, 0.18)
	draw_circle(Vector2(0.0, -38.0), 14.0, aura)
	draw_circle(Vector2(0.0, -38.0), 9.0, phase_color)
	draw_line(Vector2(0.0, -28.0), Vector2(0.0, 3.0), phase_color, 7.0, true)
	draw_line(Vector2(0.0, -19.0), Vector2(22.0, -9.0), phase_color, 5.0, true)
	draw_line(Vector2(0.0, -17.0), Vector2(-18.0, -5.0), phase_color, 5.0, true)
	draw_line(Vector2(0.0, 1.0), Vector2(15.0, 23.0), phase_color, 6.0, true)
	draw_line(Vector2(0.0, 1.0), Vector2(-13.0, 24.0), phase_color, 6.0, true)
	draw_line(Vector2(19.0, -10.0), Vector2(35.0, -16.0), ink, 3.0, true)
	if current_weapon != "" and current_weapon != "unarmed":
		draw_line(Vector2(28.0, -13.0), Vector2(50.0, -26.0), phase_color, 4.0, true)
	var action_count := mini(current_actions.size(), 6)
	for index in range(action_count):
		var x := -25.0 + float(index) * 10.0
		draw_rect(Rect2(x, 31.0, 7.0, 3.0), phase_color, true)
