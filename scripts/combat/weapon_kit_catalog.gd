class_name WeaponKitCatalog
extends RefCounted

const CONTEXT_KEYS: Array[String] = ["air", "low", "advance", "neutral_ji", "neutral_fu"]

const KITS := {
	&"serene_katana": {
		"label": "KATANA SERENA",
		# Kit provisório da vertical slice. Reutiliza técnicas genéricas já
		# validadas até os golpes exclusivos de lâmina entrarem no catálogo.
		"air": &"tai_aerial_arc",
		"low": &"ji_sweep",
		"advance": &"tai_advancing_kick",
		"neutral_ji": &"ji_body_hook",
		"neutral_fu": &"fu_flow_strike",
		"damage_multiplier": 1.04,
		"posture_multiplier": 0.98,
		"preferred_range": 112.0
	},
	&"wooden_training_saber": {
		"label": "SABRE DE TREINO",
		# Autoridade visual do Training Rival no First Playable. Até o catálogo
		# receber técnicas exclusivas de sabre, reutiliza a gramática corporal
		# genérica já validada sem declarar manoplas inexistentes no runtime.
		"air": &"tai_aerial_arc",
		"low": &"ji_sweep",
		"advance": &"tai_advancing_kick",
		"neutral_ji": &"ji_body_hook",
		"neutral_fu": &"fu_reversal",
		"damage_multiplier": 1.06,
		"posture_multiplier": 1.10,
		"preferred_range": 108.0
	},
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

static func is_technique_for_weapon(weapon_id: StringName, technique_id: StringName) -> bool:
	if technique_id == &"":
		return false
	var kit := _kit_for(weapon_id)
	for context_key in CONTEXT_KEYS:
		if StringName(kit.get(context_key, &"")) == technique_id:
			return true
	return false

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
		&"serene_katana":
			return "Precisão, transição Fu e alcance médio controlado."
		&"wooden_training_saber":
			return "Pressão disciplinada, guarda compacta e alcance médio de treino."
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
