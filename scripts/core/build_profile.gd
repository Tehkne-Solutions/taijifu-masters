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
@export var weapon_id: StringName = &"training_staff"
@export var element_id: StringName = &"air"
@export var armor_weight: float = 20.0

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

func light_damage() -> float:
	return 4.0 + strength * 0.075 + technique * 0.045

func knockback_power() -> float:
	return 150.0 + strength * 2.0 + ji_index() * 0.75

static func prototype_preset(preset_id: StringName) -> BuildProfile:
	var profile := BuildProfile.new()

	match preset_id:
		&"adaptive_staff":
			profile.display_name = "Bastão Adaptativo"
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
			profile.element_id = &"air"
		&"rock_guardian":
			profile.display_name = "Rocha Guardiã"
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
			profile.element_id = &"earth"
		_:
			pass

	return profile
