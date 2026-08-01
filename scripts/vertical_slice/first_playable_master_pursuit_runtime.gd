extends Node

const PURSUIT_DISTANCE := 360.0
const VERTICAL_PURSUIT := 105.0
const STUCK_SECONDS := 0.45
const JUMP_COOLDOWN := 0.62
const REENGAGE_DISTANCE := 190.0

var _root: Node
var _bot_runtime: TacticalBotRuntime
var _bot: MasteredWeaponFighterController
var _player: MasteredWeaponFighterController
var _last_position := Vector2.ZERO
var _stuck_timer := 0.0
var _jump_cooldown := 0.0
var _pursuing := false
var _telemetry: MatchTelemetry

func _ready() -> void:
	process_priority = 45
	_root = get_parent()

func _process(delta: float) -> void:
	_resolve_runtime()
	if not _is_master_active():
		_pursuing = false
		return
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	var delta_pos := _player.global_position - _bot.global_position
	var horizontal := absf(delta_pos.x)
	var vertical := delta_pos.y
	var disconnected := horizontal > PURSUIT_DISTANCE or absf(vertical) > VERTICAL_PURSUIT
	if disconnected:
		_drive_direct_pursuit(delta_pos, delta)
	elif _pursuing and horizontal > REENGAGE_DISTANCE:
		_drive_direct_pursuit(delta_pos, delta)
	else:
		if _pursuing:
			_record(&"pursuit_reengaged", &"combat_range")
		_pursuing = false
		_stuck_timer = 0.0
	_last_position = _bot.global_position

func _resolve_runtime() -> void:
	if not is_instance_valid(_root):
		return
	if not is_instance_valid(_bot_runtime):
		var candidate := _root.get_node_or_null("TacticalBotRuntime")
		if candidate is TacticalBotRuntime:
			_bot_runtime = candidate as TacticalBotRuntime
	if not is_instance_valid(_telemetry):
		var value: Variant = _root.get("_telemetry")
		if value is MatchTelemetry:
			_telemetry = value as MatchTelemetry
	if is_instance_valid(_bot_runtime):
		if is_instance_valid(_bot_runtime._bot):
			_bot = _bot_runtime._bot as MasteredWeaponFighterController
		if is_instance_valid(_bot_runtime._opponent):
			_player = _bot_runtime._opponent as MasteredWeaponFighterController
	if is_instance_valid(_bot) and _last_position == Vector2.ZERO:
		_last_position = _bot.global_position

func _is_master_active() -> bool:
	return is_instance_valid(_bot_runtime) and is_instance_valid(_bot) and is_instance_valid(_player) and _bot_runtime.enabled and _bot_runtime.difficulty_id == &"master"

func _drive_direct_pursuit(delta_pos: Vector2, delta: float) -> void:
	if is_instance_valid(_bot._grabbed_by) or is_instance_valid(_bot._grabbed_target):
		return
	if _bot._attack_phase != FighterController.AttackPhase.NONE or _bot._is_blocking or _bot._dodge_timer > 0.0:
		return
	var direction := int(signf(delta_pos.x))
	if direction == 0:
		direction = 1
	_bot_runtime._objective = &"engage"
	_bot_runtime._strategic_target = _player.global_position
	_bot_runtime._strategic_point_id = &"direct_player_pursuit"
	_bot_runtime._navigation_timer = 0.18
	_bot_runtime._decision_timer = maxf(_bot_runtime._decision_timer, 0.10)
	_bot_runtime._set_movement(direction)
	_bot_runtime._intent = "MESTRE • PERSEGUIR RIVAL"
	if not _pursuing:
		_pursuing = true
		_record(&"pursuit_started", &"direct_player")
	_update_stuck(delta)
	if delta_pos.y < -58.0 and _bot.is_on_floor():
		_try_jump(&"vertical_chase")
	elif _stuck_timer >= STUCK_SECONDS and _bot.is_on_floor():
		_try_jump(&"unstuck")
		_stuck_timer = 0.0

func _update_stuck(delta: float) -> void:
	var moved := _bot.global_position.distance_to(_last_position)
	if moved < 2.2:
		_stuck_timer += delta
	else:
		_stuck_timer = maxf(0.0, _stuck_timer - delta * 2.0)

func _try_jump(reason: StringName) -> void:
	if _jump_cooldown > 0.0 or _bot.stamina < 8.0:
		return
	_bot_runtime._tap(&"jump", 0.14)
	_jump_cooldown = JUMP_COOLDOWN
	_record(&"pursuit_jump", reason)

func _record(event_id: StringName, value_id: StringName) -> void:
	if not is_instance_valid(_telemetry):
		return
	_telemetry.record_event(&"p2", event_id, value_id)
	_telemetry.record_combat_metric(&"p2", event_id, 1.0)

func presentation_signature() -> Dictionary:
	return {
		"direct_player_pursuit": true,
		"disconnect_distance": PURSUIT_DISTANCE,
		"vertical_chase": true,
		"vertical_threshold": VERTICAL_PURSUIT,
		"stuck_recovery": true,
		"stuck_seconds": STUCK_SECONDS,
		"jump_recovery": true,
		"strategic_point_override_when_disconnected": true,
		"returns_control_in_combat_range": true,
		"damage_changes": false,
		"attribute_buffs": false,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
