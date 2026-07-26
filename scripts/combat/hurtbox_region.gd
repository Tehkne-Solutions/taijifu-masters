class_name HurtboxRegion
extends Area2D

@export var region_id: StringName = &"torso"
@export var damage_multiplier: float = 1.0
@export var posture_multiplier: float = 1.0
@export var disarm_multiplier: float = 1.0

func fighter() -> FighterController:
	var parent := get_parent()
	if parent is FighterController:
		return parent as FighterController
	return null
