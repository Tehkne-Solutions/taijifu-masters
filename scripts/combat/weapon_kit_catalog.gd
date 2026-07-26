class_name WeaponKitCatalog
extends RefCounted

const KITS := {
	&"training_staff": {
		"label": "BASTÃO ADAPTATIVO",
		"air": &"staff_vault_arc",
		"low": &"staff_low_sweep",
		"advance": &"staff_long_thrust",
		"neutral_ji": &"staff_center_hook",
		"neutral_fu": &"staff_flow_redirect",
		"damage_multiplier": 1.00,
		"posture_multiplier": 1.00,
		"preferred_range": 150.0
	},
	&"seismic_gauntlets": {
		"label": "MANOPLAS SÍSMICAS",
		"air": &"gauntlet_rising_break",
		"low": &"gauntlet_quake_sweep",
		"advance": &"gauntlet_shouldering_entry",
		"neutral_ji": &"gauntlet_center_crush",
		"neutral_fu": &"gauntlet_guard_turn",
		"damage_multiplier": 1.12,
		"posture_multiplier": 1.18,
		"preferred_range": 78.0
	},
	&"breaker_gauntlets": {
		"label": "MANOPLAS QUEBRA-FUNDAÇÃO",
		"air": &"gauntlet_rising_break",
		"low": &"gauntlet_quake_sweep",
		"advance": &"gauntlet_shouldering_entry",
		"neutral_ji": &"gauntlet_center_crush",
		"neutral_fu": &"gauntlet_guard_turn",
		"damage_multiplier": 1.18,
		"posture_multiplier": 1.27,
		"preferred_range": 72.0
	},
	&"wind_wraps": {
		"label": "FAIXAS DO VENTO",
		"air": &"tai_aerial_arc",
		"low": &"ji_sweep",
		"advance": &"tai_advancing_kick",
		"neutral_ji": &"ji_body_hook",
		"neutral_fu": &"fu_reversal",
		"damage_multiplier": 0.94,
		"posture_multiplier": 0.90,
		"preferred_range": 116.0
	},
	&"unarmed": {
		"label": "MÃOS LIVRES",
		"air": &"tai_aerial_arc",
		"low": &"ji_sweep",
		"advance": &"tai_advancing_kick",
		"neutral_ji": &"ji_body_hook",
		"neutral_fu": &"fu_flow_strike",
		"damage_multiplier": 0.84,
		"posture_multiplier": 0.90,
		"preferred_range": 86.0
	}
}

static func technique_for(
	weapon_id: StringName,
	context_id: StringName,
	build: BuildProfile
) -> StringName:
	var kit := _kit_for(weapon_id)
	var technique_id: StringName = kit.get(String(context_id), &"")
	if technique_id != &"":
		return technique_id

	match context_id:
		&"air":
			return build.technique_for("tai", 1)
		&"low":
			return &"ji_sweep"
		&"advance":
			return build.technique_for("tai", 0)
		&"neutral_ji":
			return build.technique_for("ji", 0)
		_:
			return build.technique_for("fu", 0)

static func label_for(weapon_id: StringName) -> String:
	return String(_kit_for(weapon_id).get("label", String(weapon_id).to_upper()))

static func damage_multiplier(weapon_id: StringName) -> float:
	return float(_kit_for(weapon_id).get("damage_multiplier", 1.0))

static func posture_multiplier(weapon_id: StringName) -> float:
	return float(_kit_for(weapon_id).get("posture_multiplier", 1.0))

static func preferred_range(weapon_id: StringName) -> float:
	return float(_kit_for(weapon_id).get("preferred_range", 90.0))

static func tactical_summary(weapon_id: StringName) -> String:
	match weapon_id:
		&"training_staff":
			return "Alcance, varredura e redirecionamento Fu."
		&"seismic_gauntlets", &"breaker_gauntlets":
			return "Entrada pesada, postura e desarmamento Ji."
		&"wind_wraps":
			return "Mobilidade aérea, aceleração e evasão Tai."
		_:
			return "Repertório corporal equilibrado."

static func _kit_for(weapon_id: StringName) -> Dictionary:
	if KITS.has(weapon_id):
		return KITS[weapon_id]
	return KITS[&"unarmed"]