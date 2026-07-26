class_name ElementalFighterController
extends FighterController

signal elemental_state_changed(fighter: FighterController, status_id: StringName)
signal elemental_interaction(fighter: FighterController, interaction_id: StringName, element_id: StringName)

const ELEMENT_TECHNIQUES := {
	&"fire": &"element_fire_burst",
	&"water": &"element_water_wave",
	&"earth": &"element_earth_anchor",
	&"air": &"element_air_gust"
}

const ELEMENT_COLORS := {
	&"fire": Color(1.0, 0.34, 0.12),
	&"water": Color(0.20, 0.62, 1.0),
	&"earth": Color(0.58, 0.42, 0.22),
	&"air": Color(0.58, 0.92, 1.0)
}

var burning_timer := 0.0
var wet_timer := 0.0
var anchored_timer := 0.0
var mud_timer := 0.0
var air_unstable_timer := 0.0
var steam_timer := 0.0

var _burn_tick_timer := 0.0

func _physics_process(delta: float) -> void:
	_update_elemental_states(delta)
	super._physics_process(delta)

func _process_actions() -> void:
	super._process_actions()
	if Input.is_action_just_pressed(_action("element")):
		_try_elemental_technique()

func _apply_movement(delta: float) -> void:
	var previous_velocity_x := velocity.x
	super._apply_movement(delta)

	var direction := Input.get_axis(_action("left"), _action("right"))
	if wet_timer > 0.0 and is_on_floor() and absf(direction) < 0.01:
		velocity.x = lerpf(previous_velocity_x, velocity.x, 0.28)

	if mud_timer > 0.0:
		velocity.x *= 0.68
	elif anchored_timer > 0.0:
		velocity.x *= 0.82

	if anchored_timer > 0.0 and velocity.y < 0.0:
		velocity.y = maxf(velocity.y, build.jump_velocity() * 0.74)
	elif mud_timer > 0.0 and velocity.y < 0.0:
		velocity.y = maxf(velocity.y, build.jump_velocity() * 0.68)

func _perform_wall_jump() -> void:
	if mud_timer > 0.0:
		combat_state_changed.emit(self)
		return
	super._perform_wall_jump()

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
	var adjusted_impulse := impulse
	if anchored_timer > 0.0:
		adjusted_impulse *= 0.62
	elif mud_timer > 0.0:
		adjusted_impulse *= 0.85

	if wet_timer > 0.0:
		adjusted_impulse *= 1.10
	if air_unstable_timer > 0.0:
		adjusted_impulse *= 1.26

	var applied := super.receive_hit(
		damage,
		posture_damage,
		adjusted_impulse,
		attacker_position,
		attacker,
		region_id,
		technique,
		bypass_guard,
		disarm_multiplier
	)

	if applied and is_instance_valid(technique) and technique.has_element():
		_apply_element(StringName(technique.element_id), technique.element_power, attacker)
	return applied

func _weapon_damage_multiplier() -> float:
	var multiplier := super._weapon_damage_multiplier()
	if steam_timer > 0.0:
		multiplier *= 0.82
	return multiplier

func _weapon_posture_multiplier() -> float:
	var multiplier := super._weapon_posture_multiplier()
	if mud_timer > 0.0:
		multiplier *= 0.88
	return multiplier

func reset_fighter(spawn_position: Vector2) -> void:
	super.reset_fighter(spawn_position)
	burning_timer = 0.0
	wet_timer = 0.0
	anchored_timer = 0.0
	mud_timer = 0.0
	air_unstable_timer = 0.0
	steam_timer = 0.0
	_burn_tick_timer = 0.0
	queue_redraw()

func _try_elemental_technique() -> void:
	var element_id := StringName(build.element_id)
	var technique_id: StringName = ELEMENT_TECHNIQUES.get(element_id, &"")
	if technique_id == &"":
		return
	_begin_technique(technique_id)

func _apply_element(element_id: StringName, power: float, attacker: FighterController) -> void:
	match element_id:
		&"fire":
			_apply_fire(power, attacker)
		&"water":
			_apply_water(power)
		&"earth":
			_apply_earth(power)
		&"air":
			_apply_air(power)
	queue_redraw()
	combat_state_changed.emit(self)

func _apply_fire(power: float, _attacker: FighterController) -> void:
	if wet_timer > 0.0:
		wet_timer = 0.0
		steam_timer = maxf(steam_timer, 2.3 + power * 0.5)
		posture = maxf(1.0, posture - 4.5 * power)
		elemental_interaction.emit(self, &"steam", &"fire")
		return

	burning_timer = maxf(burning_timer, 4.0 + power * 1.2)
	if air_unstable_timer > 0.0:
		burning_timer += 1.3
		health = maxf(0.0, health - 2.2 * power)
		elemental_interaction.emit(self, &"combustion", &"fire")
	else:
		elemental_state_changed.emit(self, &"burning")

func _apply_water(power: float) -> void:
	if burning_timer > 0.0:
		burning_timer = 0.0
		elemental_interaction.emit(self, &"extinguished", &"water")

	if anchored_timer > 0.0:
		anchored_timer = 0.0
		mud_timer = maxf(mud_timer, 5.0 + power)
		elemental_interaction.emit(self, &"mud", &"water")
	else:
		wet_timer = maxf(wet_timer, 5.5 + power)
		elemental_state_changed.emit(self, &"wet")

func _apply_earth(power: float) -> void:
	if wet_timer > 0.0:
		wet_timer = 0.0
		mud_timer = maxf(mud_timer, 5.5 + power)
		elemental_interaction.emit(self, &"mud", &"earth")
		return

	anchored_timer = maxf(anchored_timer, 4.2 + power * 0.8)
	posture = minf(build.max_posture(), posture + 4.0 * power)
	elemental_state_changed.emit(self, &"anchored")

func _apply_air(power: float) -> void:
	if anchored_timer > 0.0 or mud_timer > 0.0:
		air_unstable_timer = maxf(air_unstable_timer, 0.8)
		elemental_interaction.emit(self, &"air_resisted", &"air")
		return

	air_unstable_timer = maxf(air_unstable_timer, 3.2 + power * 0.6)
	velocity.y -= 55.0 * power
	if burning_timer > 0.0:
		burning_timer += 1.5
		health = maxf(0.0, health - 2.8 * power)
		elemental_interaction.emit(self, &"combustion", &"air")
	else:
		elemental_state_changed.emit(self, &"air_unstable")

func _update_elemental_states(delta: float) -> void:
	burning_timer = maxf(0.0, burning_timer - delta)
	wet_timer = maxf(0.0, wet_timer - delta)
	anchored_timer = maxf(0.0, anchored_timer - delta)
	mud_timer = maxf(0.0, mud_timer - delta)
	air_unstable_timer = maxf(0.0, air_unstable_timer - delta)
	steam_timer = maxf(0.0, steam_timer - delta)

	if burning_timer > 0.0 and health > 0.0:
		_burn_tick_timer -= delta
		if _burn_tick_timer <= 0.0:
			_burn_tick_timer = 0.72
			health = maxf(0.0, health - 1.15)
			posture = maxf(1.0, posture - 0.35)
			combat_state_changed.emit(self)
			if health <= 0.0:
				defeated.emit(self)
	else:
		_burn_tick_timer = 0.0

func current_element_label() -> String:
	match StringName(build.element_id):
		&"fire":
			return "FOGO"
		&"water":
			return "ÁGUA"
		&"earth":
			return "TERRA"
		&"air":
			return "AR"
		_:
			return "NEUTRO"

func current_elemental_status_label() -> String:
	var labels: Array[String] = []
	if burning_timer > 0.0:
		labels.append("QUEIMANDO")
	if wet_timer > 0.0:
		labels.append("MOLHADO")
	if anchored_timer > 0.0:
		labels.append("ANCORADO")
	if mud_timer > 0.0:
		labels.append("LAMA")
	if air_unstable_timer > 0.0:
		labels.append("DESEQUILIBRADO")
	if steam_timer > 0.0:
		labels.append("VAPOR")
	if labels.is_empty():
		return "ESTÁVEL"
	return " + ".join(labels.slice(0, 2))

func _draw() -> void:
	super._draw()
	var element_id := StringName(build.element_id)
	var element_color: Color = ELEMENT_COLORS.get(element_id, Color(0.78, 0.78, 0.82))
	draw_arc(Vector2(0, -18), 29.0, 0.0, TAU, 28, Color(element_color, 0.42), 2.0)

	if burning_timer > 0.0:
		draw_circle(Vector2(-15, -60), 5.0, ELEMENT_COLORS[&"fire"])
	if wet_timer > 0.0:
		draw_circle(Vector2(-5, -63), 5.0, ELEMENT_COLORS[&"water"])
	if anchored_timer > 0.0 or mud_timer > 0.0:
		draw_circle(Vector2(5, -63), 5.0, ELEMENT_COLORS[&"earth"])
	if air_unstable_timer > 0.0:
		draw_circle(Vector2(15, -60), 5.0, ELEMENT_COLORS[&"air"])
	if steam_timer > 0.0:
		draw_arc(Vector2(0, -46), 18.0, -2.8, -0.2, 12, Color(0.86, 0.88, 0.92, 0.78), 3.0)