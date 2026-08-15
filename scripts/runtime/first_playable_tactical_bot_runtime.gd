class_name FirstPlayableTacticalBotRuntime
extends TacticalBotRuntime

# Human playtest recovery: the previous aggressive policy kept walking into the
# opponent at clinch distance, causing both sprites to remain visually stacked.
const HARD_SEPARATION_RANGE := 72.0
const CONTACT_STOP_RANGE := 112.0
const NEUTRAL_RESET_RANGE := 96.0

func _set_movement(direction: int) -> void:
	direction = clampi(direction, -1, 1)
	if is_instance_valid(_bot) and is_instance_valid(_opponent) and direction != 0:
		var delta_x := _opponent.global_position.x - _bot.global_position.x
		var distance := absf(delta_x)
		var toward := int(signf(delta_x))
		if toward == 0:
			toward = 1
		if direction == toward:
			if distance < HARD_SEPARATION_RANGE:
				direction = -toward
				_intent = "NEUTRAL RESET • SEPARAR CONTATO"
			elif distance < CONTACT_STOP_RANGE:
				direction = 0
	super._set_movement(direction)

func _apply_range_movement(distance: float, direction_to_opponent: int) -> void:
	var desired_range := _desired_range()
	if personality_id == &"aggressive":
		desired_range *= 0.82
	elif personality_id == &"guardian":
		desired_range *= 1.12
	var retreat_threshold := maxf(NEUTRAL_RESET_RANGE, desired_range - 24.0)
	if distance < retreat_threshold:
		_set_movement(-direction_to_opponent)
		_intent = "NEUTRAL RESET • RECOMPOR DISTÂNCIA"
		return
	super._apply_range_movement(distance, direction_to_opponent)

func first_playable_spacing_signature() -> Dictionary:
	return {
		"hard_separation_range": HARD_SEPARATION_RANGE,
		"contact_stop_range": CONTACT_STOP_RANGE,
		"neutral_reset_range": NEUTRAL_RESET_RANGE,
		"close_forward_drive_blocked": true,
		"all_routes_can_retreat_when_crowded": true,
		"signature": "Tehkné Solutions",
	}

# Tehkné Solutions
