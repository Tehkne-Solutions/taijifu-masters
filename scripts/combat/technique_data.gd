class_name TechniqueData
extends Resource

@export var technique_id: StringName
@export var display_name: String
@export_enum("tai", "ji", "fu") var path: String = "fu"
@export_enum("strike", "grab") var interaction_type: String = "strike"

@export_group("Timing")
@export_range(1, 60, 1) var startup_frames: int = 6
@export_range(1, 60, 1) var active_frames: int = 4
@export_range(1, 90, 1) var recovery_frames: int = 12
@export var grab_hold_seconds: float = 0.42

@export_group("Cost and impact")
@export var stamina_cost: float = 8.0
@export var damage: float = 8.0
@export var posture_damage: float = 10.0
@export var horizontal_force: float = 260.0
@export var vertical_force: float = -90.0
@export var disarm_pressure: float = 0.0

@export_group("Hitbox")
@export var hitbox_size: Vector2 = Vector2(58, 42)
@export var hitbox_offset: Vector2 = Vector2(34, -22)

@export_group("Conditions")
@export var grounded_only: bool = false
@export var airborne_only: bool = false
@export var can_turn_during_startup: bool = false
@export var causes_disarm_pressure: bool = false

func startup_seconds() -> float:
	return startup_frames / 60.0

func active_seconds() -> float:
	return active_frames / 60.0

func recovery_seconds() -> float:
	return recovery_frames / 60.0

func total_seconds() -> float:
	return startup_seconds() + active_seconds() + recovery_seconds()

func is_valid_for(grounded: bool) -> bool:
	if grounded_only and not grounded:
		return false
	if airborne_only and grounded:
		return false
	return true

func is_grab() -> bool:
	return interaction_type == "grab"
