class_name ArenaEntranceRuntime
extends Node

signal entrance_finished

const ENTRANCE_DURATION := 2.15
const MOVE_END := 0.58
const FACE_END := 0.78

var _active := false
var _elapsed := 0.0
var _player_one: FighterController
var _player_two: FighterController
var _p1_start := Vector2.ZERO
var _p2_start := Vector2.ZERO
var _p1_target := Vector2.ZERO
var _p2_target := Vector2.ZERO
var _canvas: CanvasLayer
var _shade: ColorRect
var _names: Label
var _versus: Label
var _command: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()

func play(player_one: FighterController, player_two: FighterController) -> void:
	if not is_instance_valid(player_one) or not is_instance_valid(player_two):
		entrance_finished.emit()
		return
	_player_one = player_one
	_player_two = player_two
	_p1_target = player_one.global_position
	_p2_target = player_two.global_position
	_p1_start = _p1_target + Vector2(-280.0, -42.0)
	_p2_start = _p2_target + Vector2(280.0, -42.0)
	_player_one.global_position = _p1_start
	_player_two.global_position = _p2_start
	_player_one.facing = 1.0
	_player_two.facing = -1.0
	_freeze_fighter(_player_one, true)
	_freeze_fighter(_player_two, true)
	_elapsed = 0.0
	_active = true
	_canvas.visible = true
	_refresh_overlay(0.0)

func is_active() -> bool:
	return _active

func entrance_progress() -> float:
	return clampf(_elapsed / ENTRANCE_DURATION, 0.0, 1.0)

func preview_progress(progress: float) -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		return
	_elapsed = clampf(progress, 0.0, 1.0) * ENTRANCE_DURATION
	_apply_progress(entrance_progress())

func skip_for_test() -> void:
	if _active:
		_finish_entrance()

func _process(delta: float) -> void:
	if not _active:
		return
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		_finish_entrance()
		return
	_elapsed += delta
	var progress := entrance_progress()
	_apply_progress(progress)
	if progress >= 1.0:
		_finish_entrance()

func _apply_progress(progress: float) -> void:
	var move_progress := clampf(progress / MOVE_END, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - move_progress, 3.0)
	_player_one.global_position = _p1_start.lerp(_p1_target, eased)
	_player_two.global_position = _p2_start.lerp(_p2_target, eased)
	var arrival_bob := sin(move_progress * PI) * 22.0
	_player_one.global_position.y -= arrival_bob
	_player_two.global_position.y -= arrival_bob
	_player_one.facing = 1.0
	_player_two.facing = -1.0
	_refresh_overlay(progress)

func _finish_entrance() -> void:
	if is_instance_valid(_player_one):
		_player_one.global_position = _p1_target
		_player_one.velocity = Vector2.ZERO
		_freeze_fighter(_player_one, false)
	if is_instance_valid(_player_two):
		_player_two.global_position = _p2_target
		_player_two.velocity = Vector2.ZERO
		_freeze_fighter(_player_two, false)
	_active = false
	_elapsed = ENTRANCE_DURATION
	_canvas.visible = false
	entrance_finished.emit()

func _freeze_fighter(fighter: FighterController, frozen: bool) -> void:
	fighter.set_physics_process(not frozen)
	fighter.velocity = Vector2.ZERO
	fighter.set_collision_layer_value(1, not frozen)
	fighter.set_collision_mask_value(1, not frozen)
	if is_instance_valid(fighter.attack_shape):
		fighter.attack_shape.set_deferred("disabled", true)

func _build_overlay() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 206
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.01, 0.015, 0.028, 0.38)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_shade)
	_names = Label.new()
	_names.offset_left = 80.0
	_names.offset_top = 96.0
	_names.offset_right = 1200.0
	_names.offset_bottom = 168.0
	_names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_names.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_names.add_theme_font_size_override("font_size", 28)
	_names.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	_canvas.add_child(_names)
	_versus = Label.new()
	_versus.offset_left = 510.0
	_versus.offset_top = 255.0
	_versus.offset_right = 770.0
	_versus.offset_bottom = 430.0
	_versus.text = "VS"
	_versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_versus.add_theme_font_size_override("font_size", 74)
	_versus.add_theme_color_override("font_color", Color(1.0, 0.76, 0.28))
	_canvas.add_child(_versus)
	_command = Label.new()
	_command.offset_left = 160.0
	_command.offset_top = 530.0
	_command.offset_right = 1120.0
	_command.offset_bottom = 635.0
	_command.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_command.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_command.add_theme_font_size_override("font_size", 34)
	_canvas.add_child(_command)
	_canvas.visible = false

func _refresh_overlay(progress: float) -> void:
	var p1_name := "P1"
	var p2_name := "P2"
	if is_instance_valid(_player_one) and is_instance_valid(_player_one.build):
		p1_name = _player_one.build.character_name.to_upper()
	if is_instance_valid(_player_two) and is_instance_valid(_player_two.build):
		p2_name = _player_two.build.character_name.to_upper()
	_names.text = "%s    •    %s" % [p1_name, p2_name]
	if progress < MOVE_END:
		_command.text = "ENTRADA DOS MESTRES"
		_command.add_theme_color_override("font_color", Color(0.62, 0.84, 1.0))
		_versus.modulate.a = clampf(progress / MOVE_END, 0.0, 1.0)
	elif progress < FACE_END:
		_command.text = "LEIAM O FLUXO"
		_command.add_theme_color_override("font_color", Color(0.86, 0.72, 1.0))
	elif progress < 0.90:
		_command.text = "3  •  2  •  1"
		_command.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
	else:
		_command.text = "LUTEM"
		_command.add_theme_color_override("font_color", Color(0.58, 1.0, 0.68))
		var pulse := 1.0 + sin(_elapsed * 24.0) * 0.06
		_command.scale = Vector2.ONE * pulse
		_command.pivot_offset = _command.size * 0.5
