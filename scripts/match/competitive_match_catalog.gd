class_name CompetitiveMatchCatalog
extends RefCounted

const FIELD_ORDER: Array[StringName] = [&"arena_id", &"series_id", &"time_id", &"modifier_id"]
const ARENA_ORDER: Array[StringName] = [&"triple_ruins", &"silent_sanctuary", &"ember_crucible"]
const SERIES_ORDER: Array[StringName] = [&"best_of_3", &"best_of_5"]
const TIME_ORDER: Array[StringName] = [&"unlimited", &"ninety", &"sixty"]
const MODIFIER_ORDER: Array[StringName] = [&"classic", &"pure_duel", &"unstable_flux"]

const ARENAS := {
	&"triple_ruins": {
		"label": "RUÍNAS DO CAMINHO TRIPLO",
		"summary": "Arena móvel equilibrada, com manifestações e fechamento progressivo.",
		"route_bias": &"fu",
		"closure_enabled": true,
		"closure_time_scale": 1.0,
		"manifestations_enabled": true,
		"manifestation_interval": 5.5,
		"pressure_scale": 1.0,
		"platform_speed_scale": 1.0,
		"background": Color(0.035, 0.045, 0.065),
		"accent": Color(0.62, 0.38, 1.0)
	},
	&"silent_sanctuary": {
		"label": "SANTUÁRIO DAS QUATRO CORRENTES",
		"summary": "Espaço estável, manifestações frequentes e maior liberdade de rota.",
		"route_bias": &"tai",
		"closure_enabled": false,
		"closure_time_scale": 1.0,
		"manifestations_enabled": true,
		"manifestation_interval": 3.8,
		"pressure_scale": 0.0,
		"platform_speed_scale": 0.72,
		"background": Color(0.025, 0.070, 0.085),
		"accent": Color(0.32, 0.82, 0.92)
	},
	&"ember_crucible": {
		"label": "CRISOL DAS CINZAS",
		"summary": "Fechamento rápido, pressão de borda elevada e combate direto.",
		"route_bias": &"ji",
		"closure_enabled": true,
		"closure_time_scale": 0.68,
		"manifestations_enabled": false,
		"manifestation_interval": 5.5,
		"pressure_scale": 1.35,
		"platform_speed_scale": 1.18,
		"background": Color(0.085, 0.030, 0.025),
		"accent": Color(1.0, 0.38, 0.16)
	}
}

const SERIES := {
	&"best_of_3": {"label": "MELHOR DE 3", "best_of": 3},
	&"best_of_5": {"label": "MELHOR DE 5", "best_of": 5}
}

const TIMES := {
	&"unlimited": {"label": "SEM LIMITE", "seconds": 0.0},
	&"ninety": {"label": "90 SEGUNDOS", "seconds": 90.0},
	&"sixty": {"label": "60 SEGUNDOS", "seconds": 60.0}
}

const MODIFIERS := {
	&"classic": {
		"label": "REGRAS CLÁSSICAS",
		"summary": "Mantém as características originais da arena."
	},
	&"pure_duel": {
		"label": "DUELO PURO",
		"summary": "Sem manifestações e sem fechamento lateral."
	},
	&"unstable_flux": {
		"label": "FLUXO INSTÁVEL",
		"summary": "Manifestações mais rápidas e fechamento mais agressivo."
	}
}

static func default_config() -> Dictionary:
	return {
		"arena_id": &"triple_ruins",
		"series_id": &"best_of_3",
		"time_id": &"ninety",
		"modifier_id": &"classic"
	}

static func sanitize(source: Dictionary) -> Dictionary:
	var result := default_config()
	var arena_id := StringName(source.get("arena_id", result["arena_id"]))
	var series_id := StringName(source.get("series_id", result["series_id"]))
	var time_id := StringName(source.get("time_id", result["time_id"]))
	var modifier_id := StringName(source.get("modifier_id", result["modifier_id"]))
	result["arena_id"] = arena_id if arena_id in ARENA_ORDER else &"triple_ruins"
	result["series_id"] = series_id if series_id in SERIES_ORDER else &"best_of_3"
	result["time_id"] = time_id if time_id in TIME_ORDER else &"ninety"
	result["modifier_id"] = modifier_id if modifier_id in MODIFIER_ORDER else &"classic"
	return result

static func options_for(field_id: StringName) -> Array[StringName]:
	match field_id:
		&"arena_id": return ARENA_ORDER.duplicate()
		&"series_id": return SERIES_ORDER.duplicate()
		&"time_id": return TIME_ORDER.duplicate()
		&"modifier_id": return MODIFIER_ORDER.duplicate()
		_: return []

static func field_label(field_id: StringName) -> String:
	match field_id:
		&"arena_id": return "ARENA"
		&"series_id": return "SÉRIE"
		&"time_id": return "TEMPO"
		&"modifier_id": return "MODIFICADOR"
		_: return String(field_id).to_upper()

static func value_label(field_id: StringName, value_id: StringName) -> String:
	match field_id:
		&"arena_id": return String((ARENAS.get(value_id, ARENAS[&"triple_ruins"]) as Dictionary).get("label", "ARENA"))
		&"series_id": return String((SERIES.get(value_id, SERIES[&"best_of_3"]) as Dictionary).get("label", "MELHOR DE 3"))
		&"time_id": return String((TIMES.get(value_id, TIMES[&"ninety"]) as Dictionary).get("label", "90 SEGUNDOS"))
		&"modifier_id": return String((MODIFIERS.get(value_id, MODIFIERS[&"classic"]) as Dictionary).get("label", "CLÁSSICO"))
		_: return String(value_id).to_upper()

static func arena_data(arena_id: StringName) -> Dictionary:
	var data: Dictionary = ARENAS.get(arena_id, ARENAS[&"triple_ruins"])
	return data.duplicate(true)

static func arena_label(config: Dictionary) -> String:
	return value_label(&"arena_id", StringName(sanitize(config)["arena_id"]))

static func arena_summary(config: Dictionary) -> String:
	return String(arena_data(StringName(sanitize(config)["arena_id"])).get("summary", ""))

static func route_bias(config: Dictionary) -> StringName:
	return StringName(arena_data(StringName(sanitize(config)["arena_id"])).get("route_bias", &"fu"))

static func target_wins(config: Dictionary) -> int:
	var clean := sanitize(config)
	var series_data: Dictionary = SERIES.get(StringName(clean["series_id"]), SERIES[&"best_of_3"])
	return int(ceil(float(series_data.get("best_of", 3)) / 2.0))

static func best_of(config: Dictionary) -> int:
	var clean := sanitize(config)
	var series_data: Dictionary = SERIES.get(StringName(clean["series_id"]), SERIES[&"best_of_3"])
	return int(series_data.get("best_of", 3))

static func round_seconds(config: Dictionary) -> float:
	var clean := sanitize(config)
	var time_data: Dictionary = TIMES.get(StringName(clean["time_id"]), TIMES[&"ninety"])
	return float(time_data.get("seconds", 90.0))

static func resolved_arena_rules(config: Dictionary) -> Dictionary:
	var clean := sanitize(config)
	var rules := arena_data(StringName(clean["arena_id"]))
	var modifier_id := StringName(clean["modifier_id"])
	match modifier_id:
		&"pure_duel":
			rules["closure_enabled"] = false
			rules["manifestations_enabled"] = false
			rules["pressure_scale"] = 0.0
		&"unstable_flux":
			rules["manifestations_enabled"] = true
			rules["manifestation_interval"] = minf(2.8, float(rules.get("manifestation_interval", 5.5)))
			rules["closure_time_scale"] = float(rules.get("closure_time_scale", 1.0)) * 0.78
			rules["pressure_scale"] = maxf(1.08, float(rules.get("pressure_scale", 1.0)))
		_:
			pass
	rules["arena_id"] = clean["arena_id"]
	rules["modifier_id"] = modifier_id
	return rules

static func config_summary(config: Dictionary) -> String:
	var clean := sanitize(config)
	return "%s • %s • %s • %s" % [
		value_label(&"arena_id", StringName(clean["arena_id"])),
		value_label(&"series_id", StringName(clean["series_id"])),
		value_label(&"time_id", StringName(clean["time_id"])),
		value_label(&"modifier_id", StringName(clean["modifier_id"]))
	]

static func validate() -> Array[String]:
	var failures: Array[String] = []
	for arena_id in ARENA_ORDER:
		var data := arena_data(arena_id)
		if String(data.get("label", "")).strip_edges() == "":
			failures.append("Arena sem nome: %s" % String(arena_id))
		if float(data.get("closure_time_scale", 0.0)) <= 0.0:
			failures.append("Arena com escala de fechamento inválida: %s" % String(arena_id))
	for series_id in SERIES_ORDER:
		var data: Dictionary = SERIES.get(series_id, {})
		if int(data.get("best_of", 0)) not in [3, 5]:
			failures.append("Série inválida: %s" % String(series_id))
	if target_wins({"series_id": &"best_of_3"}) != 2 or target_wins({"series_id": &"best_of_5"}) != 3:
		failures.append("Cálculo de vitórias-alvo incorreto")
	return failures
