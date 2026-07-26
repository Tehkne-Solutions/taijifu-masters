class_name FighterController
extends CharacterBody2D

signal defeated(fighter: FighterController)
signal combat_state_changed(fighter: FighterController)

@export_range(1, 2, 1) var player_index: int = 1
@export var build_preset: StringName = &"adaptive_staff"
@export var fighter_color: Color = Color(0.24, 0.68, 0.95)

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

const GRAVITY := 1450.0
const FALL_GRAVITY := 1850.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.15
const DODGE_DURATION := 0.18
const DODGE_COOLDOWN := 0.42
const ATTACK_DURATION := 0.11
const ATTACK_COOLDOWN := 0.30

var build: BuildProfile
var health: float
var posture: float
var stamina: float = 100.0
var facing: float = 1.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dodge_timer := 0.0
var _dodge_cooldown_timer := 0.0
var _attack_timer := 0.0
var _attack_cooldown_timer := 0.0
var _attack_targets: Array[Node] = []
var _is_blocking := false

func _ready() -> void:
	build = BuildProfile.prototype_preset(build_preset)
	health = build.max_health()
	posture = build.max_posture()
	attack_area.body_entered.connect(_on_attack_body_entered)
	attack_shape.disabled = true
	queue_redraw()

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_process_actions()
	_apply_movement(delta)
	_apply_gravity(delta)
	move_and_slide()
	_update_floor_state(delta)
	_update_attack_area()
	_regenerate_resources(delta)
	queue_redraw()

func _process_actions() -> void:
	_is_blocking = Input.is_action_pressed(_action("block")) and is_on_floor() and _attack_timer <= 0.0

	if Input.is_action_just_pressed(_action("jump")):
		_jump_buffer_timer = JUMP_BUFFER

	if Input.is_action_just_pressed(_action("dodge")):
		_try_dodge()

	if Input.is_action_just_pressed(_action("attack")):
		_try_light_attack()

	if Input.is_action_just_pressed(_action("push")):
		_try_push()

func _apply_movement(delta: float) -> void:
	if _dodge_timer > 0.0:
		velocity.x = facing * (build.movement_speed() + 190.0)
		return

	var direction := Input.get_axis(_action("left"), _action("right"))
	if absf(direction) > 0.01:
		facing = signf(direction)

	var speed_modifier := 0.42 if _is_blocking else 1.0
	var target_speed := direction * build.movement_speed() * speed_modifier
	var acceleration := 1900.0 if is_on_floor() else 760.0
	var deceleration := 2350.0 if is_on_floor() else 510.0
	var rate := acceleration if absf(target_speed) > absf(velocity.x) else deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)

	if _jump_buffer_timer > 0.0 and (is_on_floor() or _coyote_timer > 0.0):
		velocity.y = build.jump_velocity()
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	if Input.is_action_just_released(_action("jump")) and velocity.y < -170.0:
		velocity.y *= 0.52

	if Input.is_action_pressed(_action("down")) and velocity.y > 40.0:
		velocity.y += 36.0

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	velocity.y += (GRAVITY if velocity.y < 0.0 else FALL_GRAVITY) * delta
	velocity.y = minf(velocity.y, 980.0)

func _update_floor_state(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)

func _try_dodge() -> void:
	if _dodge_cooldown_timer > 0.0 or stamina < 18.0 or _is_blocking:
		return
	stamina -= 18.0
	_dodge_timer = DODGE_DURATION
	_dodge_cooldown_timer = DODGE_COOLDOWN
	combat_state_changed.emit(self)

func _try_light_attack() -> void:
	if _attack_cooldown_timer > 0.0 or _is_blocking or stamina < 7.0:
		return
	stamina -= 7.0
	_attack_timer = ATTACK_DURATION
	_attack_cooldown_timer = ATTACK_COOLDOWN
	_attack_targets.clear()
	attack_shape.disabled = false
	combat_state_changed.emit(self)

func _try_push() -> void:
	if _attack_cooldown_timer > 0.0 or stamina < 11.0:
		return
	stamina -= 11.0
	_attack_timer = ATTACK_DURATION * 0.85
	_attack_cooldown_timer = ATTACK_COOLDOWN * 1.15
	_attack_targets.clear()
	attack_shape.disabled = false
	combat_state_changed.emit(self)

func _update_attack_area() -> void:
	attack_area.position.x = 35.0 * facing
	if _attack_timer <= 0.0 and not attack_shape.disabled:
		attack_shape.set_deferred("disabled", true)

func _on_attack_body_entered(body: Node) -> void:
	if _attack_timer <= 0.0 or body == self or body in _attack_targets:
		return
	if body is FighterController:
		_attack_targets.append(body)
		var target := body as FighterController
		var impulse := Vector2(facing * build.knockback_power(), -105.0)
		target.receive_hit(build.light_damage(), 11.0 + build.ji_index() * 0.08, impulse, global_position)

func receive_hit(damage: float, posture_damage: float, impulse: Vector2, attacker_position: Vector2) -> void:
	if _dodge_timer > 0.06:
		return

	var damage_reduction := clampf(build.defense * 0.0035, 0.0, 0.34)
	var posture_reduction := clampf(build.control * 0.0025, 0.0, 0.28)

	if _is_blocking and signf(attacker_position.x - global_position.x) == facing:
		damage *= 0.28
		posture_damage *= 1.15
		impulse *= 0.42

	health = maxf(0.0, health - damage * (1.0 - damage_reduction))
	posture -= posture_damage * (1.0 - posture_reduction)

	if posture <= 0.0:
		posture = build.max_posture() * 0.32
		impulse *= 1.55

	velocity = impulse
	combat_state_changed.emit(self)

	if health <= 0.0:
		defeated.emit(self)

func reset_fighter(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	health = build.max_health()
	posture = build.max_posture()
	stamina = 100.0
	_attack_timer = 0.0
	_dodge_timer = 0.0
	queue_redraw()

func _regenerate_resources(delta: float) -> void:
	stamina = minf(100.0, stamina + (15.0 if not _is_blocking else 7.0) * delta)
	if not _is_blocking and _attack_timer <= 0.0:
		posture = minf(build.max_posture(), posture + 7.5 * delta)

func _update_timers(delta: float) -> void:
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)

func _action(suffix: String) -> StringName:
	return StringName("p%d_%s" % [player_index, suffix])

func _draw() -> void:
	var alpha := 0.45 if _dodge_timer > 0.0 else 1.0
	var body_color := Color(fighter_color, alpha)

	# Placeholder manga/comic modular: silhueta clara antes dos sprites finais.
	draw_circle(Vector2(0.0, -49.0), 13.0, body_color)
	draw_polygon(
		PackedVector2Array([Vector2(-13, -36), Vector2(13, -36), Vector2(17, 10), Vector2(-17, 10)]),
		PackedColorArray([body_color])
	)
	draw_line(Vector2(-8, 5), Vector2(-13, 34), body_color, 8.0)
	draw_line(Vector2(8, 5), Vector2(13, 34), body_color, 8.0)
	draw_line(Vector2(-12, -26), Vector2(-27 * facing, -4), body_color, 7.0)
	draw_line(Vector2(12, -26), Vector2(30 * facing, -14), body_color, 7.0)

	if _attack_timer > 0.0:
		draw_arc(Vector2(15 * facing, -18), 37.0, -0.9 if facing > 0 else 2.25, 0.9 if facing > 0 else 4.05, 14, Color(1.0, 0.88, 0.35, 0.9), 5.0)

	var health_ratio := health / build.max_health()
	var posture_ratio := posture / build.max_posture()
	draw_rect(Rect2(-30, -79, 60, 5), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -79, 60 * health_ratio, 5), Color(0.92, 0.24, 0.25, 0.95))
	draw_rect(Rect2(-30, -71, 60, 3), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -71, 60 * posture_ratio, 3), Color(0.95, 0.72, 0.22, 0.95))
