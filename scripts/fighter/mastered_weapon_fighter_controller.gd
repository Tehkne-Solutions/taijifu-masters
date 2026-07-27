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

func _begin_technique(technique_id: StringName) -> bool:
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
		combat_state_changed.emit(self)
	technique_executed.emit(self, _current_technique, variant_id)
	return true

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
	var disarm_ratio := clampf(disarm_pressure / DISARM_THRESHOLD, 0.0, 1.0)
	draw_rect(Rect2(-30, -83, 60, 5), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -83, 60 * health_ratio, 5), Color(0.92, 0.24, 0.25, 0.95))
	draw_rect(Rect2(-30, -75, 60, 3), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -75, 60 * posture_ratio, 3), Color(0.95, 0.72, 0.22, 0.95))
	draw_rect(Rect2(-30, -69, 60, 2), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-30, -69, 60 * disarm_ratio, 2), Color(0.70, 0.42, 1.0, 0.95))
