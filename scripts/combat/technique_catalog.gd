class_name TechniqueCatalog
extends RefCounted

static func get_technique(technique_id: StringName) -> TechniqueData:
	var technique := TechniqueData.new()
	technique.technique_id = technique_id

	match technique_id:
		&"tai_advancing_kick":
			technique.display_name = "Passo Longo"
			technique.path = "tai"
			technique.startup_frames = 7
			technique.active_frames = 5
			technique.recovery_frames = 13
			technique.stamina_cost = 10.0
			technique.damage = 8.5
			technique.posture_damage = 8.0
			technique.horizontal_force = 330.0
			technique.vertical_force = -75.0
			technique.hitbox_size = Vector2(72, 34)
			technique.hitbox_offset = Vector2(47, -21)
			technique.grounded_only = true
			technique.disarm_pressure = 5.0
		&"tai_aerial_arc":
			technique.display_name = "Arco Ascendente"
			technique.path = "tai"
			technique.startup_frames = 5
			technique.active_frames = 7
			technique.recovery_frames = 15
			technique.stamina_cost = 12.0
			technique.damage = 7.5
			technique.posture_damage = 7.0
			technique.horizontal_force = 245.0
			technique.vertical_force = -235.0
			technique.hitbox_size = Vector2(62, 58)
			technique.hitbox_offset = Vector2(34, -35)
			technique.airborne_only = true
		&"ji_body_hook":
			technique.display_name = "Gancho de Centro"
			technique.path = "ji"
			technique.startup_frames = 4
			technique.active_frames = 4
			technique.recovery_frames = 10
			technique.stamina_cost = 7.0
			technique.damage = 8.0
			technique.posture_damage = 12.0
			technique.horizontal_force = 205.0
			technique.vertical_force = -65.0
			technique.hitbox_size = Vector2(48, 40)
			technique.hitbox_offset = Vector2(28, -22)
			technique.grounded_only = true
			technique.disarm_pressure = 8.0
		&"ji_sweep":
			technique.display_name = "Varredura de Base"
			technique.path = "ji"
			technique.startup_frames = 8
			technique.active_frames = 6
			technique.recovery_frames = 16
			technique.stamina_cost = 11.0
			technique.damage = 6.5
			technique.posture_damage = 15.0
			technique.horizontal_force = 280.0
			technique.vertical_force = 35.0
			technique.hitbox_size = Vector2(68, 24)
			technique.hitbox_offset = Vector2(40, 4)
			technique.grounded_only = true
			technique.disarm_pressure = 7.0
		&"ji_shove":
			technique.display_name = "Empurrão de Fundação"
			technique.path = "ji"
			technique.startup_frames = 6
			technique.active_frames = 5
			technique.recovery_frames = 15
			technique.stamina_cost = 11.0
			technique.damage = 2.5
			technique.posture_damage = 13.0
			technique.horizontal_force = 410.0
			technique.vertical_force = -45.0
			technique.hitbox_size = Vector2(54, 48)
			technique.hitbox_offset = Vector2(32, -23)
			technique.grounded_only = true
			technique.causes_disarm_pressure = true
			technique.disarm_pressure = 24.0
		&"ji_clinch_grab":
			technique.display_name = "Laço de Centro"
			technique.path = "ji"
			technique.interaction_type = "grab"
			technique.startup_frames = 7
			technique.active_frames = 5
			technique.recovery_frames = 18
			technique.grab_hold_seconds = 0.46
			technique.stamina_cost = 14.0
			technique.damage = 0.0
			technique.posture_damage = 0.0
			technique.hitbox_size = Vector2(48, 54)
			technique.hitbox_offset = Vector2(27, -22)
			technique.grounded_only = true
		&"ji_directional_throw":
			technique.display_name = "Projeção Direcional"
			technique.path = "ji"
			technique.startup_frames = 1
			technique.active_frames = 1
			technique.recovery_frames = 13
			technique.stamina_cost = 0.0
			technique.damage = 4.0
			technique.posture_damage = 18.0
			technique.horizontal_force = 340.0
			technique.vertical_force = -145.0
			technique.causes_disarm_pressure = true
			technique.disarm_pressure = 18.0
		&"fu_flow_strike":
			technique.display_name = "Golpe de Transição"
			technique.path = "fu"
			technique.startup_frames = 5
			technique.active_frames = 4
			technique.recovery_frames = 9
			technique.stamina_cost = 8.0
			technique.damage = 7.0
			technique.posture_damage = 8.0
			technique.horizontal_force = 235.0
			technique.vertical_force = -105.0
			technique.hitbox_size = Vector2(58, 42)
			technique.hitbox_offset = Vector2(36, -24)
			technique.can_turn_during_startup = true
			technique.disarm_pressure = 5.0
		&"fu_reversal":
			technique.display_name = "Reversão do Fluxo"
			technique.path = "fu"
			technique.startup_frames = 9
			technique.active_frames = 5
			technique.recovery_frames = 12
			technique.stamina_cost = 13.0
			technique.damage = 6.0
			technique.posture_damage = 10.0
			technique.horizontal_force = -315.0
			technique.vertical_force = -150.0
			technique.hitbox_size = Vector2(64, 48)
			technique.hitbox_offset = Vector2(16, -26)
			technique.disarm_pressure = 11.0
		_:
			technique.display_name = "Técnica não catalogada"

	return technique
