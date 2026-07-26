class_name CombatVisualCatalog
extends RefCounted

const PATH_COLORS := {
	&"tai": Color(0.28, 0.78, 1.0, 1.0),
	&"ji": Color(1.0, 0.39, 0.18, 1.0),
	&"fu": Color(0.72, 0.40, 1.0, 1.0),
	&"neutral": Color(0.86, 0.88, 0.94, 1.0)
}

const WEAPON_COLORS := {
	&"training_staff": Color(0.76, 0.50, 0.22, 1.0),
	&"wind_wraps": Color(0.42, 0.88, 1.0, 1.0),
	&"seismic_gauntlets": Color(0.48, 0.53, 0.63, 1.0),
	&"breaker_gauntlets": Color(0.68, 0.34, 0.22, 1.0),
	&"unarmed": Color(0.92, 0.92, 0.96, 1.0)
}

static func path_color(path_id: StringName) -> Color:
	return PATH_COLORS.get(path_id, PATH_COLORS[&"neutral"])

static func weapon_color(weapon_id: StringName) -> Color:
	return WEAPON_COLORS.get(weapon_id, WEAPON_COLORS[&"unarmed"])

static func is_gauntlet(weapon_id: StringName) -> bool:
	return weapon_id in [&"seismic_gauntlets", &"breaker_gauntlets"]

static func path_label(path_id: StringName) -> String:
	match path_id:
		&"tai":
			return "TAI • ALCANCE E MOVIMENTO"
		&"ji":
			return "JI • CONTATO E CONTROLE"
		&"fu":
			return "FU • TRANSIÇÃO E ADAPTAÇÃO"
		_:
			return "FLUXO NEUTRO"
