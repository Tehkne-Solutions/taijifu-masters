class_name CharacterAttachmentCatalog
extends RefCounted

const FRAME_COUNT := 4

const CHARACTER_BASE := {
	&"kael": {"hand": Vector2(11.0, -21.0), "rear_hand": Vector2(-12.0, -25.0), "angle": -0.56, "reach": 1.00},
	&"nara": {"hand": Vector2(15.0, -18.0), "rear_hand": Vector2(-13.0, -23.0), "angle": -0.34, "reach": 0.92},
	&"lyra": {"hand": Vector2(13.0, -24.0), "rear_hand": Vector2(-15.0, -27.0), "angle": -0.72, "reach": 1.08},
	&"rin": {"hand": Vector2(14.0, -20.0), "rear_hand": Vector2(-11.0, -24.0), "angle": -0.48, "reach": 1.04}
}

const STATE_HAND_OFFSETS := {
	&"idle": [Vector2(0.0, 0.0), Vector2(0.5, -1.0), Vector2(0.0, 0.0), Vector2(-0.5, 1.0)],
	&"move": [Vector2(-2.0, 1.0), Vector2(1.0, -2.0), Vector2(4.0, -1.0), Vector2(0.0, 2.0)],
	&"attack": [Vector2(-4.0, -2.0), Vector2(5.0, -5.0), Vector2(15.0, -1.0), Vector2(3.0, 2.0)],
	&"guard": [Vector2(-2.0, -1.0), Vector2(0.0, -3.0), Vector2(2.0, -1.0), Vector2(-1.0, 1.0)]
}

const STATE_REAR_OFFSETS := {
	&"idle": [Vector2.ZERO, Vector2(-1.0, 0.0), Vector2.ZERO, Vector2(1.0, 0.0)],
	&"move": [Vector2(2.0, 1.0), Vector2(-2.0, -1.0), Vector2(-4.0, 0.0), Vector2(1.0, 1.0)],
	&"attack": [Vector2(2.0, 0.0), Vector2(-3.0, -2.0), Vector2(-7.0, -1.0), Vector2(0.0, 2.0)],
	&"guard": [Vector2(4.0, 0.0), Vector2(2.0, -2.0), Vector2(0.0, -1.0), Vector2(3.0, 1.0)]
}

const STATE_ANGLE_OFFSETS := {
	&"idle": [0.00, -0.03, 0.00, 0.04],
	&"move": [-0.08, -0.02, 0.07, 0.02],
	&"attack": [-0.24, -0.05, 0.38, 0.16],
	&"guard": [0.24, 0.34, 0.28, 0.18]
}

static func attachment(character_id: StringName, state_id: StringName, frame_index: int, facing: float = 1.0) -> Dictionary:
	var data: Dictionary = CHARACTER_BASE.get(character_id, CHARACTER_BASE[&"kael"])
	var safe_state: StringName = state_id if STATE_HAND_OFFSETS.has(state_id) else &"idle"
	var safe_frame := clampi(frame_index, 0, FRAME_COUNT - 1)
	var hand_offsets: Array = STATE_HAND_OFFSETS[safe_state]
	var rear_offsets: Array = STATE_REAR_OFFSETS[safe_state]
	var angle_offsets: Array = STATE_ANGLE_OFFSETS[safe_state]
	var hand: Vector2 = data.get("hand", Vector2(11.0, -21.0))
	var rear_hand: Vector2 = data.get("rear_hand", Vector2(-12.0, -25.0))
	var hand_offset: Vector2 = hand_offsets[safe_frame]
	var rear_offset: Vector2 = rear_offsets[safe_frame]
	hand += hand_offset
	rear_hand += rear_offset
	hand.x *= facing
	rear_hand.x *= facing
	return {
		"hand": hand,
		"rear_hand": rear_hand,
		"angle": float(data.get("angle", -0.56)) + float(angle_offsets[safe_frame]),
		"reach": float(data.get("reach", 1.0)),
		"state": safe_state,
		"frame": safe_frame
	}

static func validate() -> Array[String]:
	var failures: Array[String] = []
	for character_id in CharacterVisualCatalog.character_ids():
		if not CHARACTER_BASE.has(character_id):
			failures.append("Sem encaixe-base para %s" % String(character_id))
	for state_id in CharacterVisualCatalog.STATE_ORDER:
		for source in [STATE_HAND_OFFSETS, STATE_REAR_OFFSETS, STATE_ANGLE_OFFSETS]:
			if not source.has(state_id):
				failures.append("Estado sem encaixes: %s" % String(state_id))
				continue
			var values: Array = source[state_id]
			if values.size() != FRAME_COUNT:
				failures.append("Estado %s possui %d encaixes; esperado %d" % [String(state_id), values.size(), FRAME_COUNT])
	return failures
