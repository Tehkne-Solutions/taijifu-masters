class_name LianWuBodyHookCombatController
extends "res://scripts/runtime/lian_wu_player_locomotion_controller.gd"

## VM02-C3 — player locomotion + ji_body_hook visual/runtime integration.
## Tehkné Solutions

signal attack_phase_changed(phase: String)
signal attack_hit_window_changed(enabled: bool)
signal body_hook_completed

const TECHNIQUE_ID := &"ji_body_hook"
const ATTACK_FRAME_COUNT := 6
const ATTACK_FRAME_DIR := "res://assets/pack_01_characters/lian_wu/frames/attacks/ji_body_hook"

var attack_phase := "idle"
var attack_phase_elapsed := 0.0
var attack_keypose := 0
var body_hook_count := 0
var active_keypose_observed := false

var _attack_textures: Array[Texture2D] = []
var _attack_bounds: Array[Rect2i] = []
var _technique
var _test_attack_edge := false

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

func _ready() -> void:
	super._ready()
	_load_attack_frames()
	_technique = TechniqueCatalog.get_technique(TECHNIQUE_ID)
	attack_area.monitoring = true
	attack_area.monitorable = true
	attack_shape.disabled = true
	print("VM02_C3_ATTACK_VISUAL_FRAMES=%d" % _attack_textures.size())

func set_test_attack_edge(value: bool) -> void:
	_test_attack_edge = value

func _physics_process(delta: float) -> void:
	if attack_phase == "idle":
		if _consume_attack_edge() and is_on_floor():
			_begin_body_hook()
		else:
			super._physics_process(delta)
			return

	if attack_phase == "idle":
		return

	attack_phase_elapsed += delta
	velocity.x = move_toward(velocity.x, 0.0, GROUND_DECEL * delta)
	if not is_on_floor():
		velocity.y += GRAVITY_DOWN * delta
	move_and_slide()
	_advance_attack_timeline()
	_update_attack_visual()

func _consume_attack_edge() -> bool:
	if _test_override:
		var value := _test_attack_edge
		_test_attack_edge = false
		return value
	return Input.is_action_just_pressed(&"p1_attack")

func _begin_body_hook() -> void:
	if _attack_textures.size() != ATTACK_FRAME_COUNT or _technique == null:
		return
	body_hook_count += 1
	attack_phase = "startup"
	attack_phase_elapsed = 0.0
	attack_keypose = 0
	active_keypose_observed = false
	velocity.x = 0.0
	_set_attack_hitbox(false)
	_configure_hitbox()
	attack_phase_changed.emit(attack_phase)
	print("VM02_C3_ATTACK_PHASE=startup")
	_update_attack_visual()

func _advance_attack_timeline() -> void:
	if attack_phase == "startup":
		var startup_duration: float = float(_technique.startup_seconds())
		var startup_ratio: float = clampf(attack_phase_elapsed / maxf(startup_duration, 0.0001), 0.0, 1.0)
		attack_keypose = mini(2, int(floor(startup_ratio * 3.0)))
		if attack_phase_elapsed >= startup_duration:
			attack_phase = "active"
			attack_phase_elapsed = 0.0
			attack_keypose = 3
			active_keypose_observed = true
			_set_attack_hitbox(true)
			attack_phase_changed.emit(attack_phase)
			print("VM02_C3_ATTACK_PHASE=active")
		return

	if attack_phase == "active":
		attack_keypose = 3
		active_keypose_observed = true
		if attack_phase_elapsed >= float(_technique.active_seconds()):
			attack_phase = "recovery"
			attack_phase_elapsed = 0.0
			attack_keypose = 4
			_set_attack_hitbox(false)
			attack_phase_changed.emit(attack_phase)
			print("VM02_C3_ATTACK_PHASE=recovery")
		return

	if attack_phase == "recovery":
		var recovery_duration: float = float(_technique.recovery_seconds())
		var recovery_ratio: float = clampf(attack_phase_elapsed / maxf(recovery_duration, 0.0001), 0.0, 1.0)
		attack_keypose = 4 if recovery_ratio < 0.5 else 5
		if attack_phase_elapsed >= recovery_duration:
			_end_body_hook()

func _end_body_hook() -> void:
	_set_attack_hitbox(false)
	attack_phase = "idle"
	attack_phase_elapsed = 0.0
	attack_keypose = 0
	attack_phase_changed.emit(attack_phase)
	print("VM02_C3_ATTACK_PHASE=idle")
	body_hook_completed.emit()
	_update_visual()

func _set_attack_hitbox(enabled: bool) -> void:
	attack_shape.set_deferred("disabled", not enabled)
	attack_hit_window_changed.emit(enabled)

func _configure_hitbox() -> void:
	var rectangle := attack_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = _technique.hitbox_size
	attack_area.position = Vector2(_technique.hitbox_offset.x * facing, _technique.hitbox_offset.y)

func _update_attack_visual() -> void:
	if _sprite == null or _attack_textures.size() != ATTACK_FRAME_COUNT:
		return
	var index: int = clampi(attack_keypose, 0, ATTACK_FRAME_COUNT - 1)
	_sprite.texture = _attack_textures[index]
	_sprite.flip_h = facing < 0.0
	var b: Rect2i = _attack_bounds[index]
	var pivot := Vector2(float(b.position.x) + float(b.size.x - 1) * 0.5, float(b.position.y + b.size.y - 1))
	if facing >= 0.0:
		_sprite.position = -pivot * _scale_factor
	else:
		var mirrored_pivot_x := float(_sprite.texture.get_width() - 1) - pivot.x
		_sprite.position = -Vector2(mirrored_pivot_x, pivot.y) * _scale_factor

func _attack_frame_path(frame_number: int) -> String:
	return "%s/char_lian_wu__ji_body_hook__f%02d.png" % [ATTACK_FRAME_DIR, frame_number]

func _load_attack_frames() -> void:
	_attack_textures.clear()
	_attack_bounds.clear()
	for frame_number in range(1, ATTACK_FRAME_COUNT + 1):
		var path := _attack_frame_path(frame_number)
		var texture := _load_png_texture(path)
		if texture == null:
			push_error("missing C3 attack frame %s" % path)
			continue
		var bounds := _alpha_bounds(texture)
		if bounds.size == Vector2i.ZERO:
			push_error("empty C3 attack frame %s" % path)
			continue
		_attack_textures.append(texture)
		_attack_bounds.append(bounds)
