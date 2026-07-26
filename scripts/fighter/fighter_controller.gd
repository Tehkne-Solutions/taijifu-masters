class_name FighterController
extends CharacterBody2D

signal defeated(fighter: FighterController)
signal combat_state_changed(fighter: FighterController)
signal parry_performed(fighter: FighterController)
signal posture_broken(fighter: FighterController, region_id: StringName)
signal weapon_disarmed(fighter: FighterController, weapon_id: StringName)
signal loot_collected(fighter: FighterController, loot_type: StringName, item_id: StringName)
signal grab_started(attacker: FighterController, target: FighterController)
signal grab_finished(attacker: FighterController, target: FighterController)

enum AttackPhase {
	NONE,
	STARTUP,
	ACTIVE,
	RECOVERY
}

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
const PARRY_WINDOW := 0.09
const WALL_SLIDE_SPEED := 118.0
const WALL_JUMP_HORIZONTAL := 335.0
const WALL_JUMP_VERTICAL := -475.0
const DISARM_THRESHOLD := 100.0
const DISARM_DECAY_PER_SECOND := 7.0

var build: BuildProfile
var health: float
var posture: float
var stamina: float = 100.0
var facing: float = 1.0
var equipped_weapon_id: StringName = &"unarmed"
var borrowed_technique_id: StringName = &""
var disarm_pressure: float = 0.0
var last_hit_region: StringName = &"torso"

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dodge_timer := 0.0
var _dodge_cooldown_timer := 0.0
var _parry_timer := 0.0
var _air_recovery_available := true
var _attack_phase: AttackPhase = AttackPhase.NONE
var _attack_phase_timer := 0.0
var _current_technique: TechniqueData
var _last_technique_id: StringName = &""
var _attack_targets: Array[Node] = []
var _is_blocking := false
var _posture_echo_dropped := false
var _grabbed_target: FighterController
var _grabbed_by: FighterController
var _grab_timer := 0.0

func _ready() -> void:
	build = BuildProfile.prototype_preset(build_preset)
	health = build.max_health()
	posture = build.max_posture()
	equipped_weapon_id = build.weapon_id
	attack_area.area_entered.connect(_on_attack_area_entered)
	attack_shape.disabled = true
	queue_redraw()

func _physics_process(delta: float) -> void:
	_update_timers(delta)

	if is_instance_valid(_grabbed_by):
		_follow_grabber()
		queue_redraw()
		return

	_process_actions()
	_apply_movement(delta)
	_apply_gravity(delta)
	move_and_slide()
	_update_floor_and_wall_state(delta)
	_update_attack_area()
	_update_grabbed_target_position()
	_regenerate_resources(delta)
	queue_redraw()

func _process_actions() -> void:
	if is_instance_valid(_grabbed_target):
		_is_blocking = false
		return

	var can_guard := is_on_floor() and _attack_phase == AttackPhase.NONE and _dodge_timer <= 0.0
	_is_blocking = Input.is_action_pressed(_action("block")) and can_guard

	if Input.is_action_just_pressed(_action("block")) and can_guard:
		_parry_timer = PARRY_WINDOW

	if Input.is_action_just_pressed(_action("jump")):
		if is_on_wall_only() and not is_on_floor():
			_perform_wall_jump()
		else:
			_jump_buffer_timer = JUMP_BUFFER

	if Input.is_action_just_pressed(_action("dodge")):
		_try_dodge()

	if Input.is_action_just_pressed(_action("attack")):
		_try_contextual_attack()

	if Input.is_action_just_pressed(_action("push")):
		_begin_technique(&"ji_shove")

	if Input.is_action_just_pressed(_action("grab")):
		_begin_technique(&"ji_clinch_grab")

	if Input.is_action_just_pressed(_action("echo")):
		_try_borrowed_technique()

func _apply_movement(delta: float) -> void:
	if _dodge_timer > 0.0:
		velocity.x = facing * (build.movement_speed() + 190.0)
		return

	var direction := Input.get_axis(_action("left"), _action("right"))
	var can_turn := _attack_phase == AttackPhase.NONE or (
		_attack_phase == AttackPhase.STARTUP
		and is_instance_valid(_current_technique)
		and _current_technique.can_turn_during_startup
	)
	if absf(direction) > 0.01 and can_turn:
		facing = signf(direction)

	var movement_lock := 1.0
	match _attack_phase:
		AttackPhase.STARTUP:
			movement_lock = 0.48
		AttackPhase.ACTIVE:
			movement_lock = 0.28
		AttackPhase.RECOVERY:
			movement_lock = 0.62

	if is_instance_valid(_grabbed_target):
		movement_lock = 0.20

	var speed_modifier := 0.42 if _is_blocking else movement_lock
	var target_speed := direction * build.movement_speed() * speed_modifier
	var acceleration := 1900.0 if is_on_floor() else 760.0
	var deceleration := 2350.0 if is_on_floor() else 510.0
	var rate := acceleration if absf(target_speed) > absf(velocity.x) else deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)

	if _jump_buffer_timer > 0.0 and (is_on_floor() or _coyote_timer > 0.0) and _attack_phase == AttackPhase.NONE:
		velocity.y = build.jump_velocity()
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	if Input.is_action_just_released(_action("jump")) and velocity.y < -170.0:
		velocity.y *= 0.52

	if Input.is_action_pressed(_action("down")) and velocity.y > 40.0:
		velocity.y += 36.0

	if is_on_wall_only() and velocity.y > WALL_SLIDE_SPEED:
		velocity.y = WALL_SLIDE_SPEED

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	velocity.y += (GRAVITY if velocity.y < 0.0 else FALL_GRAVITY) * delta
	velocity.y = minf(velocity.y, 980.0)

func _update_floor_and_wall_state(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
		_air_recovery_available = true
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)

func _perform_wall_jump() -> void:
	var wall_normal := get_wall_normal()
	if wall_normal == Vector2.ZERO:
		wall_normal = Vector2(-facing, 0.0)
	velocity.x = wall_normal.x * WALL_JUMP_HORIZONTAL
	velocity.y = WALL_JUMP_VERTICAL
	facing = signf(wall_normal.x)
	_air_recovery_available = true
	_jump_buffer_timer = 0.0
	combat_state_changed.emit(self)

func _try_dodge() -> void:
	if _dodge_cooldown_timer > 0.0 or stamina < 18.0 or _is_blocking or _attack_phase != AttackPhase.NONE:
		return
	if not is_on_floor() and not _air_recovery_available:
		return

	var direction := Input.get_axis(_action("left"), _action("right"))
	if absf(direction) > 0.01:
		facing = signf(direction)
	if not is_on_floor():
		_air_recovery_available = false

	stamina -= 18.0
	_dodge_timer = DODGE_DURATION
	_dodge_cooldown_timer = DODGE_COOLDOWN
	combat_state_changed.emit(self)

func _try_contextual_attack() -> void:
	var technique_id: StringName
	if not is_on_floor():
		technique_id = build.technique_for("tai", 1)
	elif Input.is_action_pressed(_action("down")):
		technique_id = &"ji_sweep"
	elif absf(velocity.x) > build.movement_speed() * 0.52:
		technique_id = build.technique_for("tai", 0)
	elif build.fu_index() >= build.ji_index():
		technique_id = build.technique_for("fu", 0)
	else:
		technique_id = build.technique_for("ji", 0)
	_begin_technique(technique_id)

func _try_borrowed_technique() -> void:
	if borrowed_technique_id == &"":
		return
	var echo_id := borrowed_technique_id
	if _begin_technique(echo_id):
		borrowed_technique_id = &""
		combat_state_changed.emit(self)

func _begin_technique(technique_id: StringName) -> bool:
	if technique_id == &"" or _attack_phase != AttackPhase.NONE or _dodge_timer > 0.0 or _is_blocking:
		return false
	if is_instance_valid(_grabbed_target) or is_instance_valid(_grabbed_by):
		return false

	var technique := TechniqueCatalog.get_technique(technique_id)
	if not technique.is_valid_for(is_on_floor()) or stamina < technique.stamina_cost:
		return false

	_current_technique = technique
	_last_technique_id = technique_id
	stamina -= technique.stamina_cost
	_attack_phase = AttackPhase.STARTUP
	_attack_phase_timer = technique.startup_seconds()
	_attack_targets.clear()
	attack_shape.disabled = true

	if technique.path == "tai" and is_on_floor():
		velocity.x += facing * minf(95.0, build.tai_index())
	combat_state_changed.emit(self)
	return true

func _advance_attack_phase() -> void:
	if not is_instance_valid(_current_technique):
		_end_technique()
		return

	match _attack_phase:
		AttackPhase.STARTUP:
			_attack_phase = AttackPhase.ACTIVE
			_attack_phase_timer = _current_technique.active_seconds()
			_configure_active_hitbox()
			attack_shape.set_deferred("disabled", false)
		AttackPhase.ACTIVE:
			_attack_phase = AttackPhase.RECOVERY
			_attack_phase_timer = _current_technique.recovery_seconds()
			attack_shape.set_deferred("disabled", true)
		AttackPhase.RECOVERY:
			_end_technique()

func _end_technique() -> void:
	_attack_phase = AttackPhase.NONE
	_attack_phase_timer = 0.0
	_current_technique = null
	attack_shape.set_deferred("disabled", true)
	combat_state_changed.emit(self)

func _configure_active_hitbox() -> void:
	if not is_instance_valid(_current_technique):
		return
	var rectangle := attack_shape.shape as RectangleShape2D
	if rectangle:
		rectangle.size = _current_technique.hitbox_size

func _update_attack_area() -> void:
	if not is_instance_valid(_current_technique):
		attack_area.position = Vector2(35.0 * facing, -18.0)
		return
	attack_area.position = Vector2(
		_current_technique.hitbox_offset.x * facing,
		_current_technique.hitbox_offset.y
	)

func _on_attack_area_entered(area: Area2D) -> void:
	if _attack_phase != AttackPhase.ACTIVE or not is_instance_valid(_current_technique):
		return
	if area is not HurtboxRegion:
		return

	var region := area as HurtboxRegion
	var target := region.fighter()
	if not is_instance_valid(target) or target == self or target in _attack_targets:
		return

	_attack_targets.append(target)
	if _current_technique.is_grab():
		_start_grab(target)
		return

	var path_damage := build.damage_multiplier_for(_current_technique.path)
	var path_posture := build.posture_multiplier_for(_current_technique.path)
	var damage := (
		_current_technique.damage + build.strength * 0.035 + build.technique * 0.02
	) * path_damage * region.damage_multiplier * _weapon_damage_multiplier()
	var posture_damage := (
		_current_technique.posture_damage
		* path_posture
		* region.posture_multiplier
		* _weapon_posture_multiplier()
	)
	var impulse := Vector2(
		facing * _current_technique.horizontal_force,
		_current_technique.vertical_force
	)
	target.receive_hit(
		damage,
		posture_damage,
		impulse,
		global_position,
		self,
		region.region_id,
		_current_technique,
		false,
		region.disarm_multiplier
	)

func receive_hit(
	damage: float,
	posture_damage: float,
	impulse: Vector2,
	attacker_position: Vector2,
	attacker: FighterController = null,
	region_id: StringName = &"torso",
	technique: TechniqueData = null,
	bypass_guard: bool = false,
	disarm_multiplier: float = 1.0
) -> bool:
	if _dodge_timer > 0.06 and not bypass_guard:
		return false

	if is_instance_valid(_grabbed_target):
		_release_grab_without_throw()

	last_hit_region = region_id
	var attacker_direction := signf(attacker_position.x - global_position.x)
	var guarding_front := _is_blocking and attacker_direction == facing and not bypass_guard
	if guarding_front and _parry_timer > 0.0:
		posture = minf(build.max_posture(), posture + 8.0)
		if is_instance_valid(attacker):
			attacker.apply_parry_recoil(global_position)
		parry_performed.emit(self)
		combat_state_changed.emit(self)
		return false

	var damage_reduction := clampf(build.defense * 0.0035, 0.0, 0.34)
	var posture_reduction := clampf(build.control * 0.0025, 0.0, 0.28)

	if guarding_front:
		damage *= 0.28
		posture_damage *= 1.15
		impulse *= 0.42

	health = maxf(0.0, health - damage * (1.0 - damage_reduction))
	posture -= posture_damage * (1.0 - posture_reduction)

	var did_break_posture := posture <= 0.0
	if did_break_posture:
		posture = build.max_posture() * 0.32
		impulse *= 1.55
		posture_broken.emit(self, region_id)
		_drop_technique_echo()

	_apply_disarm_pressure(technique, posture_damage, disarm_multiplier, did_break_posture)
	impulse *= 1.0 - build.knockback_resistance()
	velocity = impulse
	combat_state_changed.emit(self)

	if health <= 0.0:
		defeated.emit(self)
	return true

func apply_parry_recoil(defender_position: Vector2) -> void:
	if is_instance_valid(_grabbed_target):
		_release_grab_without_throw()
	var away := signf(global_position.x - defender_position.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 185.0, -55.0)
	_attack_phase = AttackPhase.RECOVERY
	_attack_phase_timer = 0.24
	attack_shape.set_deferred("disabled", true)
	combat_state_changed.emit(self)

func can_be_grabbed() -> bool:
	return (
		is_on_floor()
		and _dodge_timer <= 0.06
		and not is_instance_valid(_grabbed_by)
		and not is_instance_valid(_grabbed_target)
		and _attack_phase != AttackPhase.ACTIVE
	)

func _start_grab(target: FighterController) -> void:
	if not target.can_be_grabbed() or not is_instance_valid(_current_technique):
		return

	var hold_seconds := _current_technique.grab_hold_seconds
	_grabbed_target = target
	_grab_timer = hold_seconds
	target._set_grabbed_by(self)
	attack_shape.set_deferred("disabled", true)
	_attack_phase = AttackPhase.NONE
	_attack_phase_timer = 0.0
	_current_technique = null
	grab_started.emit(self, target)
	combat_state_changed.emit(self)

func _set_grabbed_by(attacker: FighterController) -> void:
	_grabbed_by = attacker
	_is_blocking = false
	_dodge_timer = 0.0
	velocity = Vector2.ZERO
	_end_technique()
	combat_state_changed.emit(self)

func _follow_grabber() -> void:
	if not is_instance_valid(_grabbed_by):
		return
	global_position = _grabbed_by.global_position + Vector2(_grabbed_by.facing * 29.0, -8.0)
	facing = -_grabbed_by.facing
	velocity = Vector2.ZERO

func _update_grabbed_target_position() -> void:
	if not is_instance_valid(_grabbed_target):
		return
	_grabbed_target.global_position = global_position + Vector2(facing * 29.0, -8.0)
	_grabbed_target.facing = -facing
	_grabbed_target.velocity = Vector2.ZERO

func _release_grab_with_throw() -> void:
	if not is_instance_valid(_grabbed_target):
		_grabbed_target = null
		return

	var target := _grabbed_target
	var direction_input := Input.get_axis(_action("left"), _action("right"))
	var throw_impulse := Vector2(facing * 340.0, -145.0)
	var throw_damage := 4.0 + build.strength * 0.035
	var throw_posture := 17.0 + build.ji_index() * 0.08

	if Input.is_action_pressed(_action("jump")):
		throw_impulse = Vector2(facing * 95.0, -390.0)
		throw_posture *= 0.88
	elif Input.is_action_pressed(_action("down")):
		throw_impulse = Vector2(facing * 105.0, -95.0)
		throw_damage *= 1.22
		throw_posture *= 1.30
	elif direction_input * facing < -0.25:
		throw_impulse = Vector2(-facing * 305.0, -165.0)
		target.global_position = global_position + Vector2(-facing * 34.0, -5.0)

	_grabbed_target = null
	target._grabbed_by = null
	var throw_technique := TechniqueCatalog.get_technique(&"ji_directional_throw")
	target.receive_hit(
		throw_damage,
		throw_posture,
		throw_impulse,
		global_position,
		self,
		&"torso",
		throw_technique,
		true,
		1.35
	)
	_attack_phase = AttackPhase.RECOVERY
	_attack_phase_timer = 0.22
	grab_finished.emit(self, target)
	combat_state_changed.emit(self)

func _release_grab_without_throw() -> void:
	if not is_instance_valid(_grabbed_target):
		_grabbed_target = null
		return
	var target := _grabbed_target
	_grabbed_target = null
	target._grabbed_by = null
	target.velocity = Vector2(facing * 75.0, -45.0)
	grab_finished.emit(self, target)
	target.combat_state_changed.emit(target)

func _apply_disarm_pressure(
	technique: TechniqueData,
	posture_damage: float,
	region_multiplier: float,
	posture_was_broken: bool
) -> void:
	if equipped_weapon_id == &"unarmed" or not is_instance_valid(technique):
		return

	var pressure_gain := technique.disarm_pressure * region_multiplier
	if technique.causes_disarm_pressure:
		pressure_gain += posture_damage * 0.45 * region_multiplier
	if posture_was_broken:
		pressure_gain += 18.0 * region_multiplier

	disarm_pressure = clampf(disarm_pressure + pressure_gain, 0.0, DISARM_THRESHOLD)
	if disarm_pressure >= DISARM_THRESHOLD:
		_drop_weapon()

func _drop_weapon() -> void:
	if equipped_weapon_id == &"unarmed":
		return

	var dropped_weapon := equipped_weapon_id
	equipped_weapon_id = &"unarmed"
	disarm_pressure = 0.0
	_spawn_temporary_loot("weapon", dropped_weapon)
	weapon_disarmed.emit(self, dropped_weapon)
	combat_state_changed.emit(self)

func _drop_technique_echo() -> void:
	if _posture_echo_dropped or _last_technique_id == &"":
		return
	_posture_echo_dropped = true
	_spawn_temporary_loot("technique", _last_technique_id)

func _spawn_temporary_loot(type_id: String, item_id: StringName) -> void:
	var loot := TemporaryLoot.new()
	loot.configure(type_id, item_id, player_index)
	get_parent().add_child(loot)
	loot.global_position = global_position + Vector2(0.0, -20.0)

func collect_temporary_weapon(weapon_id: StringName) -> bool:
	if weapon_id == &"":
		return false
	equipped_weapon_id = weapon_id
	disarm_pressure = 0.0
	loot_collected.emit(self, &"weapon", weapon_id)
	combat_state_changed.emit(self)
	return true

func collect_technique_echo(technique_id: StringName) -> bool:
	if technique_id == &"":
		return false
	borrowed_technique_id = technique_id
	loot_collected.emit(self, &"technique", technique_id)
	combat_state_changed.emit(self)
	return true

func reset_fighter(spawn_position: Vector2) -> void:
	_clear_grab_relationships()
	global_position = spawn_position
	velocity = Vector2.ZERO
	health = build.max_health()
	posture = build.max_posture()
	stamina = 100.0
	equipped_weapon_id = build.weapon_id
	borrowed_technique_id = &""
	disarm_pressure = 0.0
	last_hit_region = &"torso"
	_dodge_timer = 0.0
	_dodge_cooldown_timer = 0.0
	_parry_timer = 0.0
	_air_recovery_available = true
	_posture_echo_dropped = false
	_last_technique_id = &""
	_end_technique()
	queue_redraw()

func _clear_grab_relationships() -> void:
	if is_instance_valid(_grabbed_target):
		_grabbed_target._grabbed_by = null
	if is_instance_valid(_grabbed_by):
		_grabbed_by._grabbed_target = null
	_grabbed_target = null
	_grabbed_by = null
	_grab_timer = 0.0

func _regenerate_resources(delta: float) -> void:
	stamina = minf(100.0, stamina + (15.0 if not _is_blocking else 7.0) * delta)
	if not _is_blocking and _attack_phase == AttackPhase.NONE and not is_instance_valid(_grabbed_target):
		posture = minf(build.max_posture(), posture + 7.5 * delta)
	disarm_pressure = maxf(0.0, disarm_pressure - DISARM_DECAY_PER_SECOND * delta)

func _update_timers(delta: float) -> void:
	_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
	_parry_timer = maxf(0.0, _parry_timer - delta)

	if _attack_phase != AttackPhase.NONE:
		_attack_phase_timer -= delta
		if _attack_phase_timer <= 0.0:
			_advance_attack_phase()

	if is_instance_valid(_grabbed_target):
		_grab_timer -= delta
		if _grab_timer <= 0.0:
			_release_grab_with_throw()

func _action(suffix: String) -> StringName:
	return StringName("p%d_%s" % [player_index, suffix])

func current_technique_label() -> String:
	if is_instance_valid(_grabbed_by):
		return "JI • SOB CONTROLE"
	if is_instance_valid(_grabbed_target):
		return "JI • CONTROLE ATIVO"
	if not is_instance_valid(_current_technique):
		return "LIVRE"
	return "%s • %s" % [_current_technique.path.to_upper(), _current_technique.display_name]

func current_weapon_label() -> String:
	match equipped_weapon_id:
		&"training_staff":
			return "BASTÃO"
		&"seismic_gauntlets":
			return "MANOPLAS"
		&"unarmed":
			return "DESARMADO"
		_:
			return String(equipped_weapon_id).to_upper()

func current_echo_label() -> String:
	if borrowed_technique_id == &"":
		return "SEM ECO"
	var technique := TechniqueCatalog.get_technique(borrowed_technique_id)
	return "ECO: %s" % technique.display_name.to_upper()

func _weapon_damage_multiplier() -> float:
	match equipped_weapon_id:
		&"unarmed":
			return 0.84
		&"seismic_gauntlets":
			return 1.12
		&"training_staff":
			return 1.0
		_:
			return 1.04

func _weapon_posture_multiplier() -> float:
	match equipped_weapon_id:
		&"unarmed":
			return 0.90
		&"seismic_gauntlets":
			return 1.18
		&"training_staff":
			return 1.0
		_:
			return 1.06

func _draw() -> void:
	var alpha := 0.45 if _dodge_timer > 0.0 else 1.0
	var body_color := Color(fighter_color, alpha)
	if is_instance_valid(_grabbed_by):
		body_color = body_color.darkened(0.24)

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

	if equipped_weapon_id == &"training_staff":
		draw_line(Vector2(8 * facing, -30), Vector2(45 * facing, 10), Color(0.62, 0.40, 0.20), 5.0)
	elif equipped_weapon_id == &"seismic_gauntlets":
		draw_circle(Vector2(29 * facing, -13), 8.0, Color(0.42, 0.46, 0.54))

	if _attack_phase != AttackPhase.NONE and is_instance_valid(_current_technique):
		var arc_color := Color(0.36, 0.75, 1.0, 0.9)
		if _current_technique.path == "ji":
			arc_color = Color(1.0, 0.43, 0.22, 0.9)
		elif _current_technique.path == "fu":
			arc_color = Color(0.72, 0.42, 1.0, 0.9)
		draw_arc(
			Vector2(15 * facing, -18),
			37.0,
			-0.9 if facing > 0 else 2.25,
			0.9 if facing > 0 else 4.05,
			14,
			arc_color,
			5.0
		)

	if is_instance_valid(_grabbed_target):
		draw_arc(Vector2(20 * facing, -20), 25.0, -1.2, 1.2, 12, Color(1.0, 0.52, 0.22), 4.0)

	var health_ratio := health / build.max_health()
	var posture_ratio := posture / build.max_posture()
	var disarm_ratio := disarm_pressure / DISARM_THRESHOLD
	draw_rect(Rect2(-30, -83, 60, 5), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -83, 60 * health_ratio, 5), Color(0.92, 0.24, 0.25, 0.95))
	draw_rect(Rect2(-30, -75, 60, 3), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -75, 60 * posture_ratio, 3), Color(0.95, 0.72, 0.22, 0.95))
	draw_rect(Rect2(-30, -69, 60, 2), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -69, 60 * disarm_ratio, 2), Color(0.70, 0.42, 1.0, 0.95))
