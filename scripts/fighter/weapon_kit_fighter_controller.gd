class_name WeaponKitFighterController
extends ElementalFighterController

func _try_contextual_attack() -> void:
	var context_id := &"neutral_fu"
	if not is_on_floor():
		context_id = &"air"
	elif Input.is_action_pressed(_action("down")):
		context_id = &"low"
	elif absf(velocity.x) > build.movement_speed() * 0.52:
		context_id = &"advance"
	elif build.ji_index() > build.fu_index():
		context_id = &"neutral_ji"

	var technique_id := WeaponKitCatalog.technique_for(
		equipped_weapon_id,
		context_id,
		build
	)
	_begin_technique(technique_id)

func _weapon_damage_multiplier() -> float:
	var multiplier := WeaponKitCatalog.damage_multiplier(equipped_weapon_id)
	if steam_timer > 0.0:
		multiplier *= 0.82
	return multiplier

func _weapon_posture_multiplier() -> float:
	var multiplier := WeaponKitCatalog.posture_multiplier(equipped_weapon_id)
	if mud_timer > 0.0:
		multiplier *= 0.88
	return multiplier

func current_weapon_label() -> String:
	return WeaponKitCatalog.label_for(equipped_weapon_id)

func current_weapon_kit_summary() -> String:
	return WeaponKitCatalog.tactical_summary(equipped_weapon_id)
