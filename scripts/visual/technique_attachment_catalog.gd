class_name TechniqueAttachmentCatalog
extends RefCounted

const PREVIEW_STAGES: Array[StringName] = [&"startup", &"active_early", &"active_late", &"recovery"]

const PROFILES := {
	&"staff_long_thrust": {
		&"startup": {"hand": Vector2(-7, 1), "rear": Vector2(-4, 1), "angle": -0.18, "reach": 0.94},
		&"active_early": {"hand": Vector2(8, -1), "rear": Vector2(-2, 0), "angle": 0.02, "reach": 1.08},
		&"active_late": {"hand": Vector2(18, -1), "rear": Vector2(3, 0), "angle": 0.06, "reach": 1.20},
		&"recovery": {"hand": Vector2(2, 2), "rear": Vector2(1, 1), "angle": 0.22, "reach": 0.92},
		"trail": {"enabled": true, "duration": 0.18, "width": 6.0, "opacity": 0.78}
	},
	&"staff_vault_arc": {
		&"startup": {"hand": Vector2(-4, 5), "rear": Vector2(-2, 5), "angle": -0.48, "reach": 0.96},
		&"active_early": {"hand": Vector2(4, -9), "rear": Vector2(-3, -5), "angle": -0.20, "reach": 1.04},
		&"active_late": {"hand": Vector2(12, -14), "rear": Vector2(2, -9), "angle": 0.72, "reach": 1.12},
		&"recovery": {"hand": Vector2(2, -2), "rear": Vector2(1, -1), "angle": 0.36, "reach": 0.94},
		"trail": {"enabled": true, "duration": 0.28, "width": 7.0, "opacity": 0.72}
	},
	&"staff_low_sweep": {
		&"startup": {"hand": Vector2(-6, 8), "rear": Vector2(-2, 5), "angle": -0.18, "reach": 0.98},
		&"active_early": {"hand": Vector2(5, 12), "rear": Vector2(-3, 7), "angle": 0.68, "reach": 1.08},
		&"active_late": {"hand": Vector2(14, 13), "rear": Vector2(4, 8), "angle": 1.14, "reach": 1.16},
		&"recovery": {"hand": Vector2(1, 6), "rear": Vector2(1, 4), "angle": 0.46, "reach": 0.92},
		"trail": {"enabled": true, "duration": 0.32, "width": 8.0, "opacity": 0.74}
	},
	&"staff_center_hook": {
		&"startup": {"hand": Vector2(-4, 0), "rear": Vector2(-1, 0), "angle": -0.16, "reach": 0.94},
		&"active_early": {"hand": Vector2(7, -4), "rear": Vector2(-2, -2), "angle": 0.42, "reach": 1.00},
		&"active_late": {"hand": Vector2(3, -1), "rear": Vector2(3, 1), "angle": 1.08, "reach": 0.96},
		&"recovery": {"hand": Vector2(-2, 2), "rear": Vector2(1, 2), "angle": 0.34, "reach": 0.90},
		"trail": {"enabled": true, "duration": 0.22, "width": 6.0, "opacity": 0.68}
	},
	&"staff_flow_redirect": {
		&"startup": {"hand": Vector2(-3, -2), "rear": Vector2(-2, -1), "angle": -0.42, "reach": 0.94},
		&"active_early": {"hand": Vector2(4, -7), "rear": Vector2(-4, -3), "angle": -0.76, "reach": 1.02},
		&"active_late": {"hand": Vector2(10, 1), "rear": Vector2(2, -1), "angle": 0.92, "reach": 1.10},
		&"recovery": {"hand": Vector2(0, 2), "rear": Vector2(1, 1), "angle": 0.18, "reach": 0.94},
		"trail": {"enabled": true, "duration": 0.34, "width": 5.0, "opacity": 0.66}
	},
	&"gauntlet_shouldering_entry": {
		&"startup": {"hand": Vector2(-6, 3), "rear": Vector2(-2, 2), "angle": -0.10, "reach": 0.92},
		&"active_early": {"hand": Vector2(9, 1), "rear": Vector2(1, 1), "angle": 0.10, "reach": 1.08},
		&"active_late": {"hand": Vector2(18, -1), "rear": Vector2(5, 0), "angle": 0.18, "reach": 1.18},
		&"recovery": {"hand": Vector2(2, 2), "rear": Vector2(1, 1), "angle": 0.12, "reach": 0.94},
		"trail": {"enabled": true, "duration": 0.16, "width": 11.0, "opacity": 0.62}
	},
	&"gauntlet_rising_break": {
		&"startup": {"hand": Vector2(-4, 7), "rear": Vector2(-2, 3), "angle": -0.22, "reach": 0.92},
		&"active_early": {"hand": Vector2(5, -5), "rear": Vector2(0, -2), "angle": -0.60, "reach": 1.04},
		&"active_late": {"hand": Vector2(8, -17), "rear": Vector2(2, -6), "angle": -1.08, "reach": 1.10},
		&"recovery": {"hand": Vector2(1, -4), "rear": Vector2(1, -2), "angle": -0.32, "reach": 0.92},
		"trail": {"enabled": true, "duration": 0.24, "width": 10.0, "opacity": 0.68}
	},
	&"gauntlet_quake_sweep": {
		&"startup": {"hand": Vector2(-5, 9), "rear": Vector2(-2, 5), "angle": 0.18, "reach": 0.94},
		&"active_early": {"hand": Vector2(7, 12), "rear": Vector2(1, 7), "angle": 0.62, "reach": 1.08},
		&"active_late": {"hand": Vector2(15, 11), "rear": Vector2(4, 7), "angle": 1.02, "reach": 1.15},
		&"recovery": {"hand": Vector2(2, 5), "rear": Vector2(1, 3), "angle": 0.30, "reach": 0.94},
		"trail": {"enabled": true, "duration": 0.28, "width": 12.0, "opacity": 0.64}
	},
	&"gauntlet_center_crush": {
		&"startup": {"hand": Vector2(-4, 0), "rear": Vector2(3, 0), "angle": 0.0, "reach": 0.94},
		&"active_early": {"hand": Vector2(8, 0), "rear": Vector2(7, 0), "angle": 0.08, "reach": 1.06},
		&"active_late": {"hand": Vector2(14, 0), "rear": Vector2(11, 0), "angle": 0.12, "reach": 1.12},
		&"recovery": {"hand": Vector2(1, 1), "rear": Vector2(1, 1), "angle": 0.05, "reach": 0.94},
		"trail": {"enabled": true, "duration": 0.14, "width": 13.0, "opacity": 0.60}
	},
	&"gauntlet_guard_turn": {
		&"startup": {"hand": Vector2(-3, -2), "rear": Vector2(-2, -1), "angle": -0.22, "reach": 0.94},
		&"active_early": {"hand": Vector2(4, -7), "rear": Vector2(-4, -3), "angle": -0.72, "reach": 1.00},
		&"active_late": {"hand": Vector2(9, 2), "rear": Vector2(3, 1), "angle": 0.82, "reach": 1.08},
		&"recovery": {"hand": Vector2(0, 2), "rear": Vector2(1, 1), "angle": 0.18, "reach": 0.94},
		"trail": {"enabled": true, "duration": 0.30, "width": 9.0, "opacity": 0.58}
	},
	&"tai_advancing_kick": {
		&"startup": {"hand": Vector2(-3, 1), "rear": Vector2(-1, 0), "angle": -0.10, "reach": 0.94},
		&"active_early": {"hand": Vector2(5, -2), "rear": Vector2(-2, 0), "angle": 0.16, "reach": 1.04},
		&"active_late": {"hand": Vector2(9, -1), "rear": Vector2(1, 0), "angle": 0.24, "reach": 1.08},
		&"recovery": {"hand": Vector2(0, 2), "rear": Vector2(0, 1), "angle": 0.10, "reach": 0.94},
		"trail": {"enabled": true, "duration": 0.14, "width": 5.0, "opacity": 0.54}
	},
	&"tai_aerial_arc": {
		&"startup": {"hand": Vector2(-2, 4), "rear": Vector2(-1, 2), "angle": -0.32, "reach": 0.94},
		&"active_early": {"hand": Vector2(3, -6), "rear": Vector2(-2, -3), "angle": -0.62, "reach": 1.02},
		&"active_late": {"hand": Vector2(7, -10), "rear": Vector2(2, -5), "angle": 0.72, "reach": 1.08},
		&"recovery": {"hand": Vector2(0, -2), "rear": Vector2(0, -1), "angle": 0.24, "reach": 0.94},
		"trail": {"enabled": true, "duration": 0.23, "width": 5.0, "opacity": 0.58}
	},
	&"ji_sweep": {
		&"startup": {"hand": Vector2(-4, 7), "rear": Vector2(-2, 4), "angle": 0.12, "reach": 0.94},
		&"active_early": {"hand": Vector2(6, 10), "rear": Vector2(1, 6), "angle": 0.58, "reach": 1.05},
		&"active_late": {"hand": Vector2(12, 11), "rear": Vector2(3, 7), "angle": 0.98, "reach": 1.10},
		&"recovery": {"hand": Vector2(1, 4), "rear": Vector2(1, 3), "angle": 0.28, "reach": 0.94},
		"trail": {"enabled": true, "duration": 0.24, "width": 6.0, "opacity": 0.56}
	},
	&"fu_flow_strike": {
		&"startup": {"hand": Vector2(-3, -1), "rear": Vector2(-2, 0), "angle": -0.28, "reach": 0.94},
		&"active_early": {"hand": Vector2(3, -6), "rear": Vector2(-3, -2), "angle": -0.64, "reach": 1.00},
		&"active_late": {"hand": Vector2(9, 0), "rear": Vector2(2, 0), "angle": 0.76, "reach": 1.08},
		&"recovery": {"hand": Vector2(0, 2), "rear": Vector2(1, 1), "angle": 0.16, "reach": 0.94},
		"trail": {"enabled": true, "duration": 0.26, "width": 5.0, "opacity": 0.60}
	},
	&"fu_reversal": {
		&"startup": {"hand": Vector2(-5, -2), "rear": Vector2(-3, -1), "angle": -0.52, "reach": 0.92},
		&"active_early": {"hand": Vector2(-2, -8), "rear": Vector2(-5, -4), "angle": -0.94, "reach": 0.98},
		&"active_late": {"hand": Vector2(10, 1), "rear": Vector2(3, 0), "angle": 1.10, "reach": 1.10},
		&"recovery": {"hand": Vector2(0, 2), "rear": Vector2(1, 1), "angle": 0.20, "reach": 0.92},
		"trail": {"enabled": true, "duration": 0.34, "width": 6.0, "opacity": 0.62}
	},
	&"element_fire_burst": {"trail": {"enabled": true, "duration": 0.26, "width": 10.0, "opacity": 0.72}},
	&"element_water_wave": {"trail": {"enabled": true, "duration": 0.34, "width": 8.0, "opacity": 0.58}},
	&"element_earth_anchor": {"trail": {"enabled": true, "duration": 0.22, "width": 13.0, "opacity": 0.60}},
	&"element_air_gust": {"trail": {"enabled": true, "duration": 0.30, "width": 7.0, "opacity": 0.62}}
}

static func technique_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in PROFILES.keys():
		result.append(StringName(key))
	result.sort()
	return result

static func preview_stage(phase_id: StringName, progress: float) -> StringName:
	if phase_id == &"active":
		return &"active_early" if progress < 0.5 else &"active_late"
	if phase_id in [&"startup", &"recovery"]:
		return phase_id
	return &"startup"

static func resolve(
	base_attachment: Dictionary,
	technique_id: StringName,
	phase_id: StringName,
	progress: float,
	facing: float,
	user_override: Dictionary = {}
) -> Dictionary:
	var result := base_attachment.duplicate(true)
	var stage := preview_stage(phase_id, progress)
	var profile: Dictionary = PROFILES.get(technique_id, {})
	var stage_data: Dictionary = profile.get(stage, {})
	_apply_values(result, stage_data, facing)
	_apply_values(result, user_override, facing)
	result["technique_id"] = technique_id
	result["preview_stage"] = stage
	result["trail"] = trail_profile(technique_id)
	return result

static func trail_profile(technique_id: StringName) -> Dictionary:
	var profile: Dictionary = PROFILES.get(technique_id, {})
	var trail: Dictionary = profile.get("trail", {})
	if trail.is_empty():
		return {"enabled": false, "duration": 0.18, "width": 5.0, "opacity": 0.55}
	return trail.duplicate(true)

static func override_key(character_id: StringName, technique_id: StringName, stage_id: StringName) -> String:
	return "%s|%s|%s" % [String(character_id), String(technique_id), String(stage_id)]

static func default_override() -> Dictionary:
	return {
		"hand_x": 0.0,
		"hand_y": 0.0,
		"rear_x": 0.0,
		"rear_y": 0.0,
		"angle": 0.0,
		"reach": 1.0
	}

static func validate() -> Array[String]:
	var failures: Array[String] = []
	for technique_id in technique_ids():
		var profile: Dictionary = PROFILES[technique_id]
		if not profile.has("trail"):
			failures.append("Técnica sem perfil de trilha: %s" % String(technique_id))
		for stage_id in PREVIEW_STAGES:
			if profile.has(stage_id) and not (profile[stage_id] is Dictionary):
				failures.append("Estágio inválido em %s/%s" % [String(technique_id), String(stage_id)])
	return failures

static func _apply_values(target: Dictionary, values: Dictionary, facing: float) -> void:
	if values.is_empty():
		return
	var hand: Vector2 = target.get("hand", Vector2.ZERO)
	var rear_hand: Vector2 = target.get("rear_hand", Vector2.ZERO)
	if values.has("hand"):
		var offset: Vector2 = values["hand"]
		hand += Vector2(offset.x * facing, offset.y)
	if values.has("rear"):
		var rear_offset: Vector2 = values["rear"]
		rear_hand += Vector2(rear_offset.x * facing, rear_offset.y)
	hand += Vector2(float(values.get("hand_x", 0.0)) * facing, float(values.get("hand_y", 0.0)))
	rear_hand += Vector2(float(values.get("rear_x", 0.0)) * facing, float(values.get("rear_y", 0.0)))
	target["hand"] = hand
	target["rear_hand"] = rear_hand
	target["angle"] = float(target.get("angle", 0.0)) + float(values.get("angle", 0.0))
	var reach_multiplier := float(values.get("reach", 1.0))
	target["reach"] = maxf(0.45, float(target.get("reach", 1.0)) * reach_multiplier)
