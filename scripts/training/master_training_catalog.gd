class_name MasterTrainingCatalog
extends RefCounted

const MASTER_ORDER: Array[StringName] = [&"han", &"orra", &"lyenne"]

const MASTERS := {
	&"han": {
		"name": "MESTRE HAN",
		"path": "FU",
		"weapon_ids": [&"training_staff"],
		"required_stage": &"trained",
		"trial_id": &"han_three_currents",
		"trial_name": "AS TRÊS CORRENTES",
		"description": "Troque o ritmo do bastão e conecte alcance, contato e adaptação.",
		"requirements": {"uses": 3, "hits": 2, "adaptive_hits": 1},
		"base_technique_id": &"staff_flow_redirect",
		"variant_id": &"han_three_currents",
		"reward_name": "CÍRCULO DAS TRÊS CORRENTES"
	},
	&"orra": {
		"name": "MESTRA ORRA",
		"path": "JI",
		"weapon_ids": [&"seismic_gauntlets", &"breaker_gauntlets"],
		"required_stage": &"trained",
		"trial_id": &"orra_inverted_foundation",
		"trial_name": "FUNDAÇÃO INVERTIDA",
		"description": "Absorva pressão, mantenha o centro e responda sem perder a base.",
		"requirements": {"uses": 3, "hits": 2, "parries": 1},
		"base_technique_id": &"gauntlet_guard_turn",
		"variant_id": &"orra_inverted_foundation",
		"reward_name": "FUNDAÇÃO INVERTIDA"
	},
	&"lyenne": {
		"name": "MESTRA LYENNE",
		"path": "TAI",
		"weapon_ids": [&"wind_wraps"],
		"required_stage": &"trained",
		"trial_id": &"lyenne_crossing_wing",
		"trial_name": "ASA CRUZADA",
		"description": "Mude de arma, recupere altura e ataque atravessando o eixo rival.",
		"requirements": {"uses": 3, "hits": 2, "swaps": 1},
		"base_technique_id": &"tai_aerial_arc",
		"variant_id": &"lyenne_crossing_wing",
		"reward_name": "ASA CRUZADA"
	}
}

const STAGE_RANKS := {
	&"unfamiliar": 0,
	&"familiar": 1,
	&"trained": 2,
	&"proficient": 3,
	&"mastered": 4,
	&"legendary": 5
}

static func available_masters() -> Array[StringName]:
	return MASTER_ORDER.duplicate()

static func master(master_id: StringName) -> Dictionary:
	var data: Dictionary = MASTERS.get(master_id, {})
	return data.duplicate(true)

static func stage_meets(current_stage: StringName, required_stage: StringName) -> bool:
	return int(STAGE_RANKS.get(current_stage, 0)) >= int(STAGE_RANKS.get(required_stage, 0))

static func compatible_weapon(master_id: StringName, weapon_id: StringName) -> bool:
	var data := master(master_id)
	var weapon_ids: Array = data.get("weapon_ids", [])
	return weapon_id in weapon_ids

static func variant_mapping(variant_ids: Array) -> Dictionary:
	var mapping := {}
	for variant_value in variant_ids:
		var variant_id := StringName(variant_value)
		for master_id in MASTER_ORDER:
			var data := master(master_id)
			if StringName(data.get("variant_id", &"")) != variant_id:
				continue
			var base_technique := String(data.get("base_technique_id", &""))
			var weapon_ids: Array = data.get("weapon_ids", [])
			for weapon_value in weapon_ids:
				var key := "%s|%s" % [String(weapon_value), base_technique]
				mapping[key] = variant_id
	return mapping

static func apply_variant(technique: TechniqueData, variant_id: StringName) -> void:
	if not is_instance_valid(technique):
		return
	match variant_id:
		&"han_three_currents":
			technique.display_name = "Círculo das Três Correntes"
			technique.startup_frames += 2
			technique.active_frames += 2
			technique.recovery_frames += 2
			technique.stamina_cost += 3.0
			technique.damage *= 0.94
			technique.horizontal_force += 52.0
			technique.hitbox_size.x += 20.0
			technique.can_turn_during_startup = true
		&"orra_inverted_foundation":
			technique.display_name = "Fundação Invertida"
			technique.startup_frames += 1
			technique.active_frames += 1
			technique.recovery_frames += 3
			technique.stamina_cost += 3.0
			technique.damage *= 0.88
			technique.posture_damage += 6.0
			technique.disarm_pressure += 9.0
			technique.horizontal_force *= 0.78
		&"lyenne_crossing_wing":
			technique.display_name = "Asa Cruzada"
			technique.startup_frames = maxi(3, technique.startup_frames - 1)
			technique.active_frames += 1
			technique.recovery_frames += 2
			technique.stamina_cost += 2.0
			technique.damage *= 0.90
			technique.horizontal_force += 78.0
			technique.vertical_force -= 48.0
			technique.hitbox_size.x += 12.0
			technique.can_turn_during_startup = true
