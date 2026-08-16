class_name FirstPlayableAiWatchdogRuntime
extends Node

## P0.2 structural safety layer for the First Playable CPU.
## It does not replace the tactical planner yet; it makes combat state explicit,
## records state diversity/inactivity and prevents the planner from becoming
## inert for multi-second windows while a round is active.
## Tehkné Solutions

enum CombatState {
	OBSERVE,
	APPROACH,
	HOLD_RANGE,
	ATTACK,
	DEFEND,
	RECOVER,
	REPOSITION,
	PUNISH,
}

const STATE_NAMES := {
	CombatState.OBSERVE: "Observe",
	CombatState.APPROACH: "Approach",
	CombatState.HOLD_RANGE: "HoldRange",
	CombatState.ATTACK: "Attack",
	CombatState.DEFEND: "Defend",
	CombatState.RECOVER: "Recover",
	CombatState.REPOSITION: "Reposition",
	CombatState.PUNISH: "Punish",
}
const REQUIRED_STATES := [
	"Observe", "Approach", "HoldRange", "Attack",
	"Defend", "Recover", "Reposition", "Punish",
]
const INACTIVITY_LIMITS := {
	&"apprentice": 2.80,
	&"disciple": 2.40,
	&"master": 2.00,
}
const DIRECT_ENGAGE_RANGE := 460.0
const ATTACK_RANGE := 285.0
const PUNISH_RANGE := 245.0
const HOLD_RANGE := 330.0
const STUCK_SECONDS := 0.82

var _tactical: TacticalBotRuntime
var _bot: FighterController
var _opponent: FighterController
var _state: CombatState = CombatState.OBSERVE
var _state_seconds := 0.0
var _combat_inactivity_seconds := 0.0
var _max_combat_inactivity_seconds := 0.0
var _watchdog_forces := 0
var _transition_count := 0
var _transition_counts: Dictionary = {}
var _last_action_active := false
var _last_bot_position := Vector2.ZERO
var _stuck_seconds := 0.0

func _ready() -> void:
	for state_name in REQUIRED_STATES:
		_transition_counts[state_name] = 0
	_transition_counts[STATE_NAMES[_state]] = 1
	_discover_runtime()

func _process(delta: float) -> void:
	_discover_runtime()
	if not _runtime_ready():
		_transition_to(CombatState.OBSERVE)
		_combat_inactivity_seconds = 0.0
		return

	_state_seconds += delta
	_update_stuck(delta)
	_update_action_activity(delta)
	_transition_to(_resolve_state())
	_apply_inactivity_watchdog()

func current_state_name() -> String:
	return String(STATE_NAMES.get(_state, "Observe"))

func inactivity_limit_seconds() -> float:
	if not is_instance_valid(_tactical):
		return float(INACTIVITY_LIMITS[&"disciple"])
	return float(INACTIVITY_LIMITS.get(_tactical.difficulty_id, 2.40))

func runtime_signature() -> Dictionary:
	return {
		"runtime": "first_playable_ai_watchdog_v1",
		"active": _runtime_ready(),
		"state": current_state_name(),
		"required_states": REQUIRED_STATES.duplicate(),
		"state_count": REQUIRED_STATES.size(),
		"state_seconds": _state_seconds,
		"combat_inactivity_seconds": _combat_inactivity_seconds,
		"max_combat_inactivity_seconds": _max_combat_inactivity_seconds,
		"inactivity_limit_seconds": inactivity_limit_seconds(),
		"watchdog_forces": _watchdog_forces,
		"transition_count": _transition_count,
		"transition_counts": _transition_counts.duplicate(true),
		"planner_owner": "TacticalBotRuntime",
		"watchdog_owner": "FirstPlayableAiWatchdogRuntime",
		"signature": "Tehkné Solutions",
	}

func _discover_runtime() -> void:
	var match_root := get_parent()
	if match_root == null:
		return
	if not is_instance_valid(_tactical):
		_tactical = match_root.get_node_or_null("TacticalBotRuntime") as TacticalBotRuntime
	if is_instance_valid(_tactical):
		_bot = _tactical._bot
		_opponent = _tactical._opponent
	if is_instance_valid(_bot) and _last_bot_position == Vector2.ZERO:
		_last_bot_position = _bot.global_position

func _runtime_ready() -> bool:
	return (
		is_instance_valid(_tactical)
		and _tactical.enabled
		and is_instance_valid(_bot)
		and is_instance_valid(_opponent)
		and _bot.health > 0.0
		and _opponent.health > 0.0
	)

func _update_action_activity(delta: float) -> void:
	var active := _combat_action_active()
	if active:
		_combat_inactivity_seconds = 0.0
	elif _last_action_active:
		_combat_inactivity_seconds = 0.0
	else:
		_combat_inactivity_seconds += delta
		_max_combat_inactivity_seconds = maxf(
			_max_combat_inactivity_seconds,
			_combat_inactivity_seconds
		)
	_last_action_active = active

func _combat_action_active() -> bool:
	if not is_instance_valid(_bot):
		return false
	return (
		_bot._attack_phase != FighterController.AttackPhase.NONE
		or _bot._dodge_timer > 0.0
		or _bot._is_blocking
		or is_instance_valid(_bot._grabbed_target)
		or is_instance_valid(_bot._grabbed_by)
	)

func _resolve_state() -> CombatState:
	var distance := absf(_opponent.global_position.x - _bot.global_position.x)
	if is_instance_valid(_bot._grabbed_by):
		return CombatState.RECOVER
	if is_instance_valid(_bot._grabbed_target) or _bot._attack_phase != FighterController.AttackPhase.NONE:
		return CombatState.ATTACK
	if _bot._is_blocking or _bot._dodge_timer > 0.0:
		return CombatState.DEFEND
	if _opponent._attack_phase == FighterController.AttackPhase.RECOVERY and distance <= PUNISH_RANGE:
		return CombatState.PUNISH
	var posture_ratio := _bot.posture / maxf(1.0, _bot.build.max_posture())
	if posture_ratio < 0.24:
		return CombatState.RECOVER
	if distance > HOLD_RANGE:
		return CombatState.APPROACH
	if absf(_bot.velocity.x) > 34.0 or _stuck_seconds > 0.0:
		return CombatState.REPOSITION
	return CombatState.HOLD_RANGE

func _transition_to(next_state: CombatState) -> void:
	if next_state == _state:
		return
	_state = next_state
	_state_seconds = 0.0
	_transition_count += 1
	var state_name := String(STATE_NAMES.get(_state, "Observe"))
	_transition_counts[state_name] = int(_transition_counts.get(state_name, 0)) + 1

func _apply_inactivity_watchdog() -> void:
	if _combat_inactivity_seconds < inactivity_limit_seconds():
		return
	var delta_position := _opponent.global_position - _bot.global_position
	var distance := absf(delta_position.x)
	var direction := int(signf(delta_position.x))
	if direction == 0:
		direction = 1

	_watchdog_forces += 1
	_tactical._decision_timer = 0.0
	_tactical._navigation_timer = 0.0
	_tactical._reaction_pending = false

	if distance <= ATTACK_RANGE:
		_tactical._set_movement(direction if distance > 82.0 else 0)
		_tactical._tap(&"attack")
		_transition_to(CombatState.ATTACK)
		_combat_inactivity_seconds = 0.0
		return

	_tactical._set_movement(direction)
	_transition_to(CombatState.APPROACH)
	if distance <= DIRECT_ENGAGE_RANGE and _bot.stamina >= 18.0:
		_tactical._tap(&"attack")
		_transition_to(CombatState.ATTACK)
		_combat_inactivity_seconds = 0.0
	else:
		# Keep the watchdog from firing every frame while direct pursuit closes a
		# genuinely long gap, but never permit another multi-second dead zone.
		_combat_inactivity_seconds = inactivity_limit_seconds() * 0.55

	if _stuck_seconds >= STUCK_SECONDS and _bot.is_on_floor():
		_tactical._tap(&"jump", 0.12)
		_stuck_seconds = 0.0

func _update_stuck(delta: float) -> void:
	if not is_instance_valid(_bot):
		return
	var moved := _bot.global_position.distance_to(_last_bot_position)
	if absf(_bot.velocity.x) > 20.0 and moved < 2.0:
		_stuck_seconds += delta
	else:
		_stuck_seconds = maxf(0.0, _stuck_seconds - delta * 2.0)
	_last_bot_position = _bot.global_position

# Tehkné Solutions
