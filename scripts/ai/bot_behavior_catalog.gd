class_name BotBehaviorCatalog
extends RefCounted

const DIFFICULTY_ORDER: Array[StringName] = [
	&"apprentice",
	&"disciple",
	&"adept",
	&"master"
]

const PERSONALITY_ORDER: Array[StringName] = [
	&"aggressive",
	&"guardian",
	&"technical",
	&"chaotic"
]

const DIFFICULTIES := {
	&"apprentice": {
		"label": "APRENDIZ",
		"reaction_multiplier": 1.55,
		"decision_min": 0.42,
		"decision_max": 0.68,
		"defense_chance": 0.38,
		"mistake_chance": 0.28,
		"escape_interval_min": 0.18,
		"escape_interval_max": 0.28,
		"escape_dodge_chance": 0.18,
		"navigation_multiplier": 1.30
	},
	&"disciple": {
		"label": "DISCÍPULO",
		"reaction_multiplier": 1.20,
		"decision_min": 0.30,
		"decision_max": 0.50,
		"defense_chance": 0.52,
		"mistake_chance": 0.16,
		"escape_interval_min": 0.13,
		"escape_interval_max": 0.21,
		"escape_dodge_chance": 0.30,
		"navigation_multiplier": 1.10
	},
	&"adept": {
		"label": "ADEPTO",
		"reaction_multiplier": 0.96,
		"decision_min": 0.22,
		"decision_max": 0.38,
		"defense_chance": 0.64,
		"mistake_chance": 0.08,
		"escape_interval_min": 0.10,
		"escape_interval_max": 0.17,
		"escape_dodge_chance": 0.42,
		"navigation_multiplier": 0.92
	},
	&"master": {
		"label": "MESTRE",
		"reaction_multiplier": 0.82,
		"decision_min": 0.18,
		"decision_max": 0.31,
		"defense_chance": 0.72,
		"mistake_chance": 0.035,
		"escape_interval_min": 0.09,
		"escape_interval_max": 0.145,
		"escape_dodge_chance": 0.52,
		"navigation_multiplier": 0.80
	}
}

const PERSONALITIES := {
	&"aggressive": {
		"label": "AGRESSIVO",
		"route_bias": &"ji",
		"route_bias_amount": 12.0,
		"recovery_threshold": 0.20,
		"contest_chance": 0.58,
		"grab_weight": 0.34,
		"push_weight": 0.24,
		"element_chance": 0.20,
		"defense_multiplier": 0.82,
		"preferred_objective": &"engage"
	},
	&"guardian": {
		"label": "GUARDIÃO",
		"route_bias": &"ji",
		"route_bias_amount": 8.0,
		"recovery_threshold": 0.38,
		"contest_chance": 0.48,
		"grab_weight": 0.24,
		"push_weight": 0.28,
		"element_chance": 0.16,
		"defense_multiplier": 1.24,
		"preferred_objective": &"control"
	},
	&"technical": {
		"label": "TÉCNICO",
		"route_bias": &"fu",
		"route_bias_amount": 14.0,
		"recovery_threshold": 0.29,
		"contest_chance": 0.66,
		"grab_weight": 0.23,
		"push_weight": 0.20,
		"element_chance": 0.27,
		"defense_multiplier": 1.12,
		"preferred_objective": &"transition"
	},
	&"chaotic": {
		"label": "CAÓTICO",
		"route_bias": &"random",
		"route_bias_amount": 16.0,
		"recovery_threshold": 0.25,
		"contest_chance": 0.82,
		"grab_weight": 0.20,
		"push_weight": 0.18,
		"element_chance": 0.46,
		"defense_multiplier": 0.92,
		"preferred_objective": &"contest"
	},
	# Política interna do First Playable MESTRE: nenhuma ação contorna a linguagem
	# Tai/Ji/Fu. Knockback nasce de impactos e magia nasce de forma/climax.
	&"master_martial": {
		"label": "MESTRE MARCIAL",
		"route_bias": &"ji",
		"route_bias_amount": 10.0,
		"recovery_threshold": 0.29,
		"contest_chance": 0.66,
		"grab_weight": 0.23,
		"push_weight": 0.0,
		"element_chance": 0.0,
		"defense_multiplier": 1.12,
		"preferred_objective": &"engage"
	}
}

static func difficulty(difficulty_id: StringName) -> Dictionary:
	return DIFFICULTIES.get(difficulty_id, DIFFICULTIES[&"disciple"]).duplicate(true)

static func personality(personality_id: StringName) -> Dictionary:
	return PERSONALITIES.get(personality_id, PERSONALITIES[&"technical"]).duplicate(true)

static func cycle_difficulty(current_id: StringName, direction: int = 1) -> StringName:
	var index := DIFFICULTY_ORDER.find(current_id)
	if index < 0:
		index = 0
	return DIFFICULTY_ORDER[wrapi(index + direction, 0, DIFFICULTY_ORDER.size())]

static func cycle_personality(current_id: StringName, direction: int = 1) -> StringName:
	var index := PERSONALITY_ORDER.find(current_id)
	if index < 0:
		index = 0
	return PERSONALITY_ORDER[wrapi(index + direction, 0, PERSONALITY_ORDER.size())]

static func difficulty_label(difficulty_id: StringName) -> String:
	return String(difficulty(difficulty_id).get("label", "DISCÍPULO"))

static func personality_label(personality_id: StringName) -> String:
	return String(personality(personality_id).get("label", "TÉCNICO"))
