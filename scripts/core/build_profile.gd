class_name BuildProfile
extends Resource

## Atributos primários do plano de combate.
@export_range(1.0, 100.0, 1.0) var strength: float = 50.0
@export_range(1.0, 100.0, 1.0) var defense: float = 50.0
@export_range(1.0, 100.0, 1.0) var agility: float = 50.0
@export_range(1.0, 100.0, 1.0) var resistance: float = 50.0
@export_range(1.0, 100.0, 1.0) var technique: float = 50.0
@export_range(1.0, 100.0, 1.0) var control: float = 50.0
@export_range(1.0, 100.0, 1.0) var perception: float = 50.0
@export_range(1.0, 100.0, 1.0) var focus: float = 50.0

@export var display_name: String = "Build equilibrada"
@export var tactical_summary: String = "Equilíbrio entre distância, contato e transição."
@export var weapon_id: StringName = &"training_staff"
@export var secondary_weapon_id: StringName = &"wind_wraps"
@export var element_id: StringName = &"air"
@export var armor_weight: float = 20.0

## Técnicas preparadas antes da batalha. Os kits resolvem o repertório pela
## arma realmente equipada e estes slots permanecem como fallback da build.
@export var tai_techniques: Array[StringName] = [&"staff_long_thrust", &"staff_vault_arc"]
@export var ji_techniques: Array[StringName] = [&"staff_center_hook", &"staff_low_sweep"]
@export var fu_techniques: Array[StringName] = [&"staff_flow_redirect", &"fu_reversal"]

func tai_index() -> float:
	return clampf(
		agility * 0.34 + strength * 0.22 + technique * 0.18 + perception * 0.16 + focus * 0.10,
		1.0,
		100.0
	)

func ji_index() -> float:
	return clampf(
		control * 0.30 + strength * 0.24 + defense * 0.22 + resistance * 0.14 + technique * 0.10,
		1.0,
		100.0
	)

func fu_index() -> float:
	return clampf(
		technique * 0.27 + perception * 0.23 + agility * 0.20 + focus * 0.18 + control * 0.12,
		1.0,
		100.0
	)

func movement_speed() -> float:
	var weight_penalty := clampf(armor_weight * 1.15, 0.0, 65.0)
	return maxf(190.0, 260.0 + agility * 2.1 - weight_penalty)

func jump_velocity() -> float:
	return -clampf(430.0 + agility * 1.45 - armor_weight * 0.75, 390.0, 570.0)

func max_health() -> float:
	return 80.0 + resistance * 0.72 + defense * 0.28

func max_posture() -> float:
	return 55.0 + control * 0.55 + defense * 0.42 + resistance * 0.18

func knockback_resistance() -> float:
	return clampf(defense * 0.003 + resistance * 0.002 + armor_weight * 0.0022, 0.0, 0.48)

func damage_multiplier_for(path: String) -> float:
	match path:
		"tai":
			return 0.72 + tai_index() * 0.006
		"ji":
			return 0.72 + ji_index() * 0.006
		"fu":
			return 0.72 + fu_index() * 0.006
		_:
			return 1.0

func posture_multiplier_for(path: String) -> float:
	match path:
		"tai":
			return 0.82 + tai_index() * 0.004
		"ji":
			return 0.82 + ji_index() * 0.0055
		"fu":
			return 0.82 + fu_index() * 0.0045
		_:
			return 1.0

func technique_for(path: String, slot: int = 0) -> StringName:
	var collection: Array[StringName]
	match path:
		"tai":
			collection = tai_techniques
		"ji":
			collection = ji_techniques
		_:
			collection = fu_techniques
	if collection.is_empty():
		return &"fu_flow_strike"
	return collection[clampi(slot, 0, collection.size() - 1)]

static func available_prototype_presets() -> Array[StringName]:
	return [&"adaptive_staff", &"aerial_flow", &"rock_guardian", &"foundation_breaker"]

static func prototype_preset(preset_id: StringName) -> BuildProfile:
	var profile := BuildProfile.new()

	match preset_id:
		&"adaptive_staff":
			profile.display_name = "Bastão Adaptativo"
			profile.tactical_summary = "Fu elevado, alcance e redirecionamento com o bastão."
			profile.strength = 48.0
			profile.defense = 45.0
			profile.agility = 68.0
			profile.resistance = 48.0
			profile.technique = 74.0
			profile.control = 55.0
			profile.perception = 67.0
			profile.focus = 58.0
			profile.armor_weight = 16.0
			profile.weapon_id = &"training_staff"
			profile.secondary_weapon_id = &"wind_wraps"
			profile.element_id = &"air"
			profile.tai_techniques = [&"staff_long_thrust", &"staff_vault_arc"]
			profile.ji_techniques = [&"staff_center_hook", &"staff_low_sweep"]
			profile.fu_techniques = [&"staff_flow_redirect", &"fu_reversal"]
		&"aerial_flow":
			profile.display_name = "Fluxo Aéreo"
			profile.tactical_summary = "Tai ágil, domínio vertical e recuperação aérea forte."
			profile.strength = 42.0
			profile.defense = 34.0
			profile.agility = 88.0
			profile.resistance = 40.0
			profile.technique = 70.0
			profile.control = 44.0
			profile.perception = 72.0
			profile.focus = 66.0
			profile.armor_weight = 8.0
			profile.weapon_id = &"wind_wraps"
			profile.secondary_weapon_id = &"training_staff"
			profile.element_id = &"air"
			profile.tai_techniques = [&"tai_aerial_arc", &"tai_advancing_kick"]
			profile.ji_techniques = [&"ji_body_hook", &"ji_shove"]
			profile.fu_techniques = [&"fu_reversal", &"fu_flow_strike"]
		&"rock_guardian":
			profile.display_name = "Rocha Guardiã"
			profile.tactical_summary = "Ji defensivo, alta postura e pressão sísmica."
			profile.strength = 76.0
			profile.defense = 82.0
			profile.agility = 30.0
			profile.resistance = 78.0
			profile.technique = 48.0
			profile.control = 83.0
			profile.perception = 43.0
			profile.focus = 42.0
			profile.armor_weight = 48.0
			profile.weapon_id = &"seismic_gauntlets"
			profile.secondary_weapon_id = &"training_staff"
			profile.element_id = &"earth"
			profile.tai_techniques = [&"gauntlet_shouldering_entry", &"gauntlet_rising_break"]
			profile.ji_techniques = [&"gauntlet_center_crush", &"gauntlet_quake_sweep"]
			profile.fu_techniques = [&"gauntlet_guard_turn", &"fu_reversal"]
		&"foundation_breaker":
			profile.display_name = "Quebra-Fundação"
			profile.tactical_summary = "Força e dano de postura altos, com pouca mobilidade."
			profile.strength = 90.0
			profile.defense = 68.0
			profile.agility = 24.0
			profile.resistance = 72.0
			profile.technique = 46.0
			profile.control = 76.0
			profile.perception = 38.0
			profile.focus = 34.0
			profile.armor_weight = 54.0
			profile.weapon_id = &"breaker_gauntlets"
			profile.secondary_weapon_id = &"seismic_gauntlets"
			profile.element_id = &"earth"
			profile.tai_techniques = [&"gauntlet_shouldering_entry", &"gauntlet_rising_break"]
			profile.ji_techniques = [&"gauntlet_center_crush", &"gauntlet_quake_sweep"]
			profile.fu_techniques = [&"gauntlet_guard_turn", &"fu_reversal"]
		_:
			pass

	return profile