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
			technique.grab_hold_seconds = 1.35
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

		# Kit do Bastão Adaptativo.
		&"staff_long_thrust":
			technique.display_name = "Estocada do Horizonte"
			technique.path = "tai"
			technique.startup_frames = 7
			technique.active_frames = 5
			technique.recovery_frames = 14
			technique.stamina_cost = 10.0
			technique.damage = 7.2
			technique.posture_damage = 8.5
			technique.horizontal_force = 305.0
			technique.vertical_force = -55.0
			technique.hitbox_size = Vector2(94, 28)
			technique.hitbox_offset = Vector2(61, -20)
			technique.grounded_only = true
			technique.disarm_pressure = 6.0
		&"staff_vault_arc":
			technique.display_name = "Arco de Alavanca"
			technique.path = "tai"
			technique.startup_frames = 6
			technique.active_frames = 7
			technique.recovery_frames = 15
			technique.stamina_cost = 12.0
			technique.damage = 7.0
			technique.posture_damage = 9.0
			technique.horizontal_force = 225.0
			technique.vertical_force = -215.0
			technique.hitbox_size = Vector2(72, 64)
			technique.hitbox_offset = Vector2(40, -36)
			technique.airborne_only = true
		&"staff_low_sweep":
			technique.display_name = "Varrida de Eixo"
			technique.path = "ji"
			technique.startup_frames = 8
			technique.active_frames = 7
			technique.recovery_frames = 16
			technique.stamina_cost = 11.0
			technique.damage = 5.5
			technique.posture_damage = 14.0
			technique.horizontal_force = 275.0
			technique.vertical_force = 28.0
			technique.hitbox_size = Vector2(86, 24)
			technique.hitbox_offset = Vector2(48, 4)
			technique.grounded_only = true
			technique.disarm_pressure = 8.0
		&"staff_center_hook":
			technique.display_name = "Gancho de Haste"
			technique.path = "ji"
			technique.startup_frames = 5
			technique.active_frames = 4
			technique.recovery_frames = 11
			technique.stamina_cost = 8.0
			technique.damage = 7.0
			technique.posture_damage = 11.0
			technique.horizontal_force = 195.0
			technique.vertical_force = -82.0
			technique.hitbox_size = Vector2(60, 40)
			technique.hitbox_offset = Vector2(34, -22)
			technique.grounded_only = true
			technique.disarm_pressure = 10.0
		&"staff_flow_redirect":
			technique.display_name = "Círculo de Retorno"
			technique.path = "fu"
			technique.startup_frames = 5
			technique.active_frames = 5
			technique.recovery_frames = 9
			technique.stamina_cost = 9.0
			technique.damage = 6.2
			technique.posture_damage = 7.5
			technique.horizontal_force = 215.0
			technique.vertical_force = -112.0
			technique.hitbox_size = Vector2(68, 46)
			technique.hitbox_offset = Vector2(40, -24)
			technique.can_turn_during_startup = true
			technique.disarm_pressure = 5.0

		# Kit das Manoplas Sísmicas.
		&"gauntlet_shouldering_entry":
			technique.display_name = "Entrada de Obsidiana"
			technique.path = "tai"
			technique.startup_frames = 10
			technique.active_frames = 6
			technique.recovery_frames = 17
			technique.stamina_cost = 14.0
			technique.damage = 9.0
			technique.posture_damage = 13.0
			technique.horizontal_force = 365.0
			technique.vertical_force = -58.0
			technique.hitbox_size = Vector2(66, 50)
			technique.hitbox_offset = Vector2(39, -21)
			technique.grounded_only = true
			technique.causes_disarm_pressure = true
			technique.disarm_pressure = 12.0
		&"gauntlet_rising_break":
			technique.display_name = "Ruptura Ascendente"
			technique.path = "tai"
			technique.startup_frames = 7
			technique.active_frames = 6
			technique.recovery_frames = 18
			technique.stamina_cost = 15.0
			technique.damage = 8.0
			technique.posture_damage = 12.0
			technique.horizontal_force = 195.0
			technique.vertical_force = -265.0
			technique.hitbox_size = Vector2(58, 64)
			technique.hitbox_offset = Vector2(31, -38)
			technique.airborne_only = true
		&"gauntlet_quake_sweep":
			technique.display_name = "Rasteira Sísmica"
			technique.path = "ji"
			technique.startup_frames = 11
			technique.active_frames = 6
			technique.recovery_frames = 19
			technique.stamina_cost = 14.0
			technique.damage = 7.0
			technique.posture_damage = 18.0
			technique.horizontal_force = 250.0
			technique.vertical_force = 30.0
			technique.hitbox_size = Vector2(74, 30)
			technique.hitbox_offset = Vector2(40, 2)
			technique.grounded_only = true
			technique.causes_disarm_pressure = true
			technique.disarm_pressure = 15.0
		&"gauntlet_center_crush":
			technique.display_name = "Prensa do Centro"
			technique.path = "ji"
			technique.startup_frames = 6
			technique.active_frames = 5
			technique.recovery_frames = 13
			technique.stamina_cost = 11.0
			technique.damage = 10.0
			technique.posture_damage = 17.0
			technique.horizontal_force = 180.0
			technique.vertical_force = -52.0
			technique.hitbox_size = Vector2(48, 46)
			technique.hitbox_offset = Vector2(28, -22)
			technique.grounded_only = true
			technique.causes_disarm_pressure = true
			technique.disarm_pressure = 14.0
		&"gauntlet_guard_turn":
			technique.display_name = "Giro de Fundação"
			technique.path = "fu"
			technique.startup_frames = 7
			technique.active_frames = 5
			technique.recovery_frames = 12
			technique.stamina_cost = 12.0
			technique.damage = 5.5
			technique.posture_damage = 12.0
			technique.horizontal_force = -255.0
			technique.vertical_force = -110.0
			technique.hitbox_size = Vector2(58, 50)
			technique.hitbox_offset = Vector2(27, -24)
			technique.can_turn_during_startup = true
			technique.disarm_pressure = 10.0

		&"element_fire_burst":
			technique.display_name = "Pulso de Brasa"
			technique.path = "fu"
			technique.startup_frames = 9
			technique.active_frames = 5
			technique.recovery_frames = 17
			technique.stamina_cost = 16.0
			technique.damage = 5.5
			technique.posture_damage = 5.0
			technique.horizontal_force = 225.0
			technique.vertical_force = -70.0
			technique.hitbox_size = Vector2(72, 48)
			technique.hitbox_offset = Vector2(45, -24)
			technique.element_id = "fire"
			technique.element_power = 1.0
		&"element_water_wave":
			technique.display_name = "Onda de Fluxo"
			technique.path = "fu"
			technique.startup_frames = 8
			technique.active_frames = 7
			technique.recovery_frames = 16
			technique.stamina_cost = 15.0
			technique.damage = 3.0
			technique.posture_damage = 6.0
			technique.horizontal_force = 345.0
			technique.vertical_force = -35.0
			technique.hitbox_size = Vector2(82, 50)
			technique.hitbox_offset = Vector2(48, -20)
			technique.element_id = "water"
			technique.element_power = 1.0
		&"element_earth_anchor":
			technique.display_name = "Impacto de Fundação"
			technique.path = "fu"
			technique.startup_frames = 12
			technique.active_frames = 6
			technique.recovery_frames = 19
			technique.stamina_cost = 18.0
			technique.damage = 4.5
			technique.posture_damage = 16.0
			technique.horizontal_force = 190.0
			technique.vertical_force = 20.0
			technique.hitbox_size = Vector2(70, 42)
			technique.hitbox_offset = Vector2(41, -2)
			technique.grounded_only = true
			technique.element_id = "earth"
			technique.element_power = 1.0
		&"element_air_gust":
			technique.display_name = "Rajada de Desvio"
			technique.path = "fu"
			technique.startup_frames = 6
			technique.active_frames = 6
			technique.recovery_frames = 13
			technique.stamina_cost = 14.0
			technique.damage = 3.5
			technique.posture_damage = 5.0
			technique.horizontal_force = 430.0
			technique.vertical_force = -125.0
			technique.hitbox_size = Vector2(88, 54)
			technique.hitbox_offset = Vector2(52, -24)
			technique.can_turn_during_startup = true
			technique.element_id = "air"
			technique.element_power = 1.0
		_:
			technique.display_name = "Técnica não catalogada"

	return technique
