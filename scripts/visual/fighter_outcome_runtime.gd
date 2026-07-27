class_name FighterOutcomeRuntime
extends Node

signal outcome_state_changed(fighter: FighterController, state_id: StringName)

const FALL_DURATION := 0.42

var _fighter: FighterController
var _state_id: StringName = &"normal"
var _state_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fighter = get_parent() as FighterController
	if is_instance_valid(_fighter) and _fighter.has_signal("defeated"):
		_fighter.defeated.connect(_on_fighter_defeated)

func _process(delta: float) -> void:
	if _state_id == &"normal":
		return
	_state_time += delta
	if _state_id == &"fall" and _state_time >= FALL_DURATION:
		_set_state(&"defeat")

func play_defeat() -> void:
	if _state_id == &"fall" or _state_id == &"defeat":
		return
	_freeze_fighter()
	_set_state(&"fall")

func play_victory() -> void:
	if _state_id == &"victory":
		return
	_freeze_fighter()
	_set_state(&"victory")

func reset_outcome() -> void:
	_state_id = &"normal"
	_state_time = 0.0
	if is_instance_valid(_fighter):
		_fighter.set_physics_process(true)
		_fighter.velocity = Vector2.ZERO
		outcome_state_changed.emit(_fighter, _state_id)

func preview_outcome(state_id: StringName, elapsed: float = 0.0) -> void:
	_state_id = state_id
	_state_time = maxf(0.0, elapsed)

func state_id() -> StringName:
	return _state_id

func state_time() -> float:
	return _state_time

func is_outcome_active() -> bool:
	return _state_id != &"normal"

func expression_id() -> StringName:
	match _state_id:
		&"fall": return &"shock"
		&"defeat": return &"defeat"
		&"victory": return &"victory"
		_: return &"neutral"

func visual_transform() -> Dictionary:
	match _state_id:
		&"fall":
			var progress := clampf(_state_time / FALL_DURATION, 0.0, 1.0)
			return {
				"offset": Vector2(lerpf(0.0, -8.0, progress), lerpf(0.0, 25.0, progress)),
				"rotation": lerpf(0.0, -1.32 * _fighter.facing, progress),
				"scale": Vector2(1.0, lerpf(1.0, 0.86, progress)),
				"alpha": 1.0
			}
		&"defeat":
			return {
				"offset": Vector2(-8.0 * _fighter.facing, 25.0),
				"rotation": -1.32 * _fighter.facing,
				"scale": Vector2(1.0, 0.86),
				"alpha": 0.78
			}
		&"victory":
			var pulse := sin(_state_time * 7.0)
			return {
				"offset": Vector2(0.0, -6.0 - absf(pulse) * 4.0),
				"rotation": pulse * 0.035,
				"scale": Vector2.ONE * (1.0 + absf(pulse) * 0.035),
				"alpha": 1.0
			}
		_:
			return {"offset": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE, "alpha": 1.0}

func transform_local_point(point: Vector2) -> Vector2:
	var visual := visual_transform()
	var scale_value: Vector2 = visual.get("scale", Vector2.ONE)
	var rotation_value := float(visual.get("rotation", 0.0))
	var offset_value: Vector2 = visual.get("offset", Vector2.ZERO)
	return (point * scale_value).rotated(rotation_value) + offset_value

func _freeze_fighter() -> void:
	if not is_instance_valid(_fighter):
		return
	_fighter.velocity = Vector2.ZERO
	_fighter.set_physics_process(false)

func _set_state(state_id: StringName) -> void:
	_state_id = state_id
	_state_time = 0.0
	if is_instance_valid(_fighter):
		outcome_state_changed.emit(_fighter, _state_id)

func _on_fighter_defeated(_defeated_fighter: FighterController) -> void:
	play_defeat()
