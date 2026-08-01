class_name MasteredWeaponFighterController
extends WeaponKitFighterController

signal technique_executed(
	fighter: MasteredWeaponFighterController,
	technique: TechniqueData,
	variant_id: StringName
)
signal impact_resolved(
	target: MasteredWeaponFighterController,
	attacker: FighterController,
	technique: TechniqueData,
	result_id: StringName,
	damage_applied: float,
	posture_applied: float,
	intensity: float,
	world_position: Vector2
)
signal regional_hit_received(
	fighter: MasteredWeaponFighterController,
	region_id: StringName,
	result_id: StringName,
	intensity: float
)

const MAX_MANA := 100.0
const MANA_REGEN_PER_SECOND := 6.0
const MANA_REGEN_DELAY_AFTER_CAST := 1.15
const FIRST_PLAYABLE_PHYSICAL_TEMPO_SCALE := 1.22
const FIRST_PLAYABLE_ELEMENT_TEMPO_SCALE := 1.30
const AIR_JUMP_COSTS := [10.0, 16.0]
const AIR_JUMP_VERTICAL_FACTORS := [0.92, 0.78]
const WALL_CLIMB_STAMINA_COST := 10.0
const WALL_CLIMB_VERTICAL := -515.0

const ELEMENT_MANA_COSTS := {
	&"element_fire_burst": 34.0,
	&"element_water_wave": 30.0,
	&"element_earth_anchor": 38.0,
	&"element_air_gust": 28.0,
}

const ELEMENT_RANGES := {
	"fire": {"size": Vector2(260.0, 58.0), "offset": Vector2(145.0, -24.0)},
	"water": {"size": Vector2(340.0, 62.0), "offset": Vector2(185.0, -20.0)},
	"earth": {"size": Vector2(220.0, 54.0), "offset": Vector2(125.0, -4.0)},
	"air": {"size": Vector2(300.0, 70.0), "offset": Vector2(165.0, -26.0)},
}

var mana: float = MAX_MANA
var _mana_regen_delay := 0.0
var _air_jump_count := 0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_mana_regen_delay = maxf(0.0, _mana_regen_delay - delta)
	if _mana_regen_delay <= 0.0 and _attack_phase == AttackPhase.NONE and not _is_blocking:
		mana = minf(MAX_MANA, mana + MANA_REGEN_PER_SECOND * delta)

func _process_actions() -> void:
	var jump_pressed := Input.is_action_just_pressed(_action("jump"))
	var was_airborne := not is_on_floor()
	var was_on_wall := is_on_wall_only()
	super._process_actions()
	if jump_pressed and was_airborne and not was_on_wall and _attack_phase == AttackPhase.NONE:
		_try_air_jump()

func _update_floor_and_wall_state(delta: float) -> void:
	super._update_floor_and_wall_state(delta)
	if is_on_floor():
		_air_jump_count = 0

func _perform_wall_jump() -> void:
	if stamina < WALL_CLIMB_STAMINA_COST:
		return
	stamina -= WALL_CLIMB_STAMINA_COST
	super._perform_wall_jump()
	velocity.y = minf(velocity.y, WALL_CLIMB_VERTICAL)
	# O wall jump funciona como etapa de escalada e devolve um salto aéreo de ajuste.
	_air_jump_count = mini(_air_jump_count, 1)
	combat_state_changed.emit(self)

func _try_air_jump() -> bool:
	if _air_jump_count >= AIR_JUMP_COSTS.size() or _dodge_timer > 0.0 or _is_blocking:
		return false
	var cost: float = AIR_JUMP_COSTS[_air_jump_count]
	if stamina < cost:
		return false
	stamina -= cost
	var factor: float = AIR_JUMP_VERTICAL_FACTORS[_air_jump_count]
	velocity.y = build.jump_velocity() * factor
	_air_jump_count += 1
	_jump_buffer_timer = 0.0
	_air_recovery_available = true
	combat_state_changed.emit(self)
	return true

func _begin_technique(technique_id: StringName) -> bool:
	var probe := TechniqueCatalog.get_technique(technique_id)
	var elemental := is_instance_valid(probe) and probe.has_element()
	if elemental:
		return _begin_elemental_technique(technique_id, probe)

	var variant_id := unlocked_variant_for(technique_id)
	if variant_id != selected_training_variant():
		variant_id = &""
	var additional_cost := 0.0
	if variant_id != &"":
		var base_technique := TechniqueCatalog.get_technique(technique_id)
		var preview := TechniqueCatalog.get_technique(technique_id)
		MasterTrainingCatalog.apply_variant(preview, variant_id)
		if stamina < preview.stamina_cost:
			return false
		additional_cost = maxf(0.0, preview.stamina_cost - base_technique.stamina_cost)
	var began := super._begin_technique(technique_id)
	if not began or not is_instance_valid(_current_technique):
		return began
	if additional_cost > 0.0:
		stamina = maxf(0.0, stamina - additional_cost)
	_apply_first_playable_tempo_and_range(_current_technique)
	combat_state_changed.emit(self)
	technique_executed.emit(self, _current_technique, variant_id)
	return true

func _begin_elemental_technique(technique_id: StringName, probe: TechniqueData) -> bool:
	var mana_cost := mana_cost_for(technique_id)
	if mana + 0.001 < mana_cost:
		return false
	# A camada base ainda conhece apenas stamina. Compensamos o custo antigo antes
	# da chamada e restauramos depois: magia gasta MANA, nunca stamina.
	var stamina_before := stamina
	stamina += probe.stamina_cost
	var began := super._begin_technique(technique_id)
	stamina = stamina_before
	if not began or not is_instance_valid(_current_technique):
		return false
	mana = maxf(0.0, mana - mana_cost)
	_mana_regen_delay = MANA_REGEN_DELAY_AFTER_CAST
	_apply_first_playable_tempo_and_range(_current_technique)
	combat_state_changed.emit(self)
	technique_executed.emit(self, _current_technique, &"")
	return true

func mana_cost_for(technique_id: StringName) -> float:
	return float(ELEMENT_MANA_COSTS.get(technique_id, 0.0))

func can_cast_elemental(technique_id: StringName) -> bool:
	return mana + 0.001 >= mana_cost_for(technique_id)

func max_mana() -> float:
	return MAX_MANA

func _apply_first_playable_tempo_and_range(technique: TechniqueData) -> void:
	if not is_instance_valid(technique) or not _is_first_playable_fighter():
		return
	var scale := FIRST_PLAYABLE_ELEMENT_TEMPO_SCALE if technique.has_element() else FIRST_PLAYABLE_PHYSICAL_TEMPO_SCALE
	technique.startup_frames = maxi(1, int(round(technique.startup_frames * scale)))
	technique.active_frames = maxi(1, int(round(technique.active_frames * scale)))
	technique.recovery_frames = maxi(1, int(round(technique.recovery_frames * scale)))
	_attack_phase_timer = technique.startup_seconds()
	if technique.has_element() and ELEMENT_RANGES.has(technique.element_id):
		var range_data: Dictionary = ELEMENT_RANGES[technique.element_id]
		technique.hitbox_size = range_data["size"]
		technique.hitbox_offset = range_data["offset"]

func _is_first_playable_fighter() -> bool:
	return is_instance_valid(build) and build.character_id in [&"lian_wu", &"training_rival"]

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
	var health_before := health
	var posture_before := posture
	var attacker_direction := signf(attacker_position.x - global_position.x)
	var guarding_front := _is_blocking and attacker_direction == facing and not bypass_guard
	var was_evading := _dodge_timer > 0.06 and not bypass_guard
	var was_parrying := guarding_front and _parry_timer > 0.0
	var accepted := super.receive_hit(
		damage,
		posture_damage,
		impulse,
		attacker_position,
		attacker,
		region_id,
		technique,
		bypass_guard,
		disarm_multiplier
	)
	if not is_instance_valid(attacker) or not is_instance_valid(technique):
		return accepted
	var damage_applied := maxf(0.0, health_before - health)
	var posture_applied := maxf(0.0, posture_before - posture)
	var result_id := &"hit"
	if was_evading:
		result_id = &"evaded"
	elif was_parrying:
		result_id = &"parried"
	elif guarding_front:
		result_id = &"blocked"
	elif posture > posture_before and posture_before <= build.max_posture() * 0.40:
		result_id = &"posture_break"
		posture_applied = posture_before
	var intensity := clampf(damage_applied / 18.0 + posture_applied / 28.0, 0.16, 1.0)
	match result_id:
		&"evaded":
			intensity = 0.18
		&"blocked":
			intensity = maxf(0.38, intensity * 0.72)
		&"parried":
			intensity = 0.88
		&"posture_break":
			intensity = 1.0
	regional_hit_received.emit(self, region_id, result_id, intensity)
	impact_resolved.emit(
		self,
		attacker,
		technique,
		result_id,
		damage_applied,
		posture_applied,
		intensity,
		_region_world_position(region_id)
	)
	return accepted

func reset_fighter(spawn_position: Vector2) -> void:
	super.reset_fighter(spawn_position)
	mana = MAX_MANA
	_mana_regen_delay = 0.0
	_air_jump_count = 0

func _region_world_position(region_id: StringName) -> Vector2:
	var local_offset := Vector2(0.0, -17.0)
	match region_id:
		&"head":
			local_offset = Vector2(0.0, -49.0)
		&"legs":
			local_offset = Vector2(0.0, 20.0)
	return global_position + local_offset

func _draw() -> void:
	var presenter := get_node_or_null("SpritePresenter") as ProvisionalSpritePresenter
	if not is_instance_valid(presenter) or not presenter.has_active_sprite():
		super._draw()
		return
	_draw_resource_bars()

func _draw_resource_bars() -> void:
	if not is_instance_valid(build):
		return
	var health_ratio := clampf(health / build.max_health(), 0.0, 1.0)
	var posture_ratio := clampf(posture / build.max_posture(), 0.0, 1.0)
	var stamina_ratio := clampf(stamina / 100.0, 0.0, 1.0)
	var mana_ratio := clampf(mana / MAX_MANA, 0.0, 1.0)
	var disarm_ratio := clampf(disarm_pressure / DISARM_THRESHOLD, 0.0, 1.0)
	draw_rect(Rect2(-30, -87, 60, 5), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -87, 60 * health_ratio, 5), Color(0.92, 0.24, 0.25, 0.95))
	draw_rect(Rect2(-30, -80, 60, 3), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -80, 60 * posture_ratio, 3), Color(0.95, 0.72, 0.22, 0.95))
	draw_rect(Rect2(-30, -75, 60, 2), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -75, 60 * stamina_ratio, 2), Color(0.40, 0.86, 0.54, 0.95))
	draw_rect(Rect2(-30, -71, 60, 2), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -71, 60 * mana_ratio, 2), Color(0.30, 0.58, 1.0, 0.95))
	draw_rect(Rect2(-30, -67, 60, 2), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -67, 60 * disarm_ratio, 2), Color(0.70, 0.42, 1.0, 0.95))

func combat_economy_signature() -> Dictionary:
	return {
		"separate_mana_and_stamina": true,
		"physical_uses_stamina": true,
		"elemental_uses_mana": true,
		"mana_max": MAX_MANA,
		"mana_regen_per_second": MANA_REGEN_PER_SECOND,
		"mana_regen_delay_after_cast": MANA_REGEN_DELAY_AFTER_CAST,
		"physical_tempo_scale": FIRST_PLAYABLE_PHYSICAL_TEMPO_SCALE,
		"element_tempo_scale": FIRST_PLAYABLE_ELEMENT_TEMPO_SCALE,
		"ranged_elemental_hitboxes": true,
		"air_jump_levels": 3,
		"two_air_jumps": true,
		"wall_climb_jump": true,
		"wall_climb_costs_stamina": true,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
