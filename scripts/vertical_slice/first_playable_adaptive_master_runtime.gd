class_name FirstPlayableAdaptiveMasterRuntime
extends Node

const MEMORY_SIZE := 5
const REACTION_DELAY_MIN := 0.070
const REACTION_DELAY_MAX := 0.120
const COUNTER_DELAY := 0.16
const CLIMAX_LATE_REACTION_THRESHOLD := 0.055
const CLIMAX_GUARD_HOLD := 0.72

var _root: Node
var _bot_runtime: TacticalBotRuntime
var _player: MasteredWeaponFighterController
var _bot: MasteredWeaponFighterController
var _combo: FirstPlayableComboRuntime
var _telemetry: MatchTelemetry
var _recent_paths: Array[StringName] = []
var _pattern_score := 0
var _reaction_timer := 0.0
var _counter_timer := 0.0
var _reaction_pending := false
var _counter_pending := false
var _climax_seen := false
var _climax_response_pending := false
var _climax_response_mode: StringName = &""

func _ready() -> void:
	process_priority = 30
	_root = get_parent()

func _process(delta: float) -> void:
	_resolve_runtime()
	if not _is_master_active():
		return
	_reaction_timer = maxf(0.0, _reaction_timer - delta)
	_counter_timer = maxf(0.0, _counter_timer - delta)
	_watch_climax()
	if _reaction_pending and _reaction_timer <= 0.0:
		_reaction_pending = false
		_execute_pattern_response()
	if _counter_pending and _counter_timer <= 0.0:
		_counter_pending = false
		_execute_counter_attack()

func _resolve_runtime() -> void:
	if not is_instance_valid(_root):
		return
	if not is_instance_valid(_bot_runtime):
		var candidate := _root.get_node_or_null("TacticalBotRuntime")
		if candidate is TacticalBotRuntime:
			_bot_runtime = candidate as TacticalBotRuntime
	if not is_instance_valid(_combo):
		var combo_candidate := _root.get_node_or_null("FirstPlayableComboRuntime")
		if combo_candidate is FirstPlayableComboRuntime:
			_combo = combo_candidate as FirstPlayableComboRuntime
	if not is_instance_valid(_telemetry):
		var telemetry_candidate: Variant = _root.get("_telemetry")
		if telemetry_candidate is MatchTelemetry:
			_telemetry = telemetry_candidate as MatchTelemetry
	if not is_instance_valid(_player):
		var player_candidate: Variant = _root.get("player_one")
		if player_candidate is MasteredWeaponFighterController:
			_player = player_candidate as MasteredWeaponFighterController
			if not _player.technique_executed.is_connected(_on_player_technique_executed):
				_player.technique_executed.connect(_on_player_technique_executed)
	if is_instance_valid(_bot_runtime) and is_instance_valid(_bot_runtime._bot):
		_bot = _bot_runtime._bot as MasteredWeaponFighterController

func _is_master_active() -> bool:
	return (
		is_instance_valid(_bot_runtime)
		and is_instance_valid(_player)
		and is_instance_valid(_bot)
		and _bot_runtime.enabled
		and _bot_runtime.difficulty_id == &"master"
	)

func _on_player_technique_executed(
	_fighter: MasteredWeaponFighterController,
	technique: TechniqueData,
	_variant_id: StringName
) -> void:
	if not is_instance_valid(technique):
		return
	_recent_paths.append(StringName(technique.path))
	while _recent_paths.size() > MEMORY_SIZE:
		_recent_paths.pop_front()
	_pattern_score = _calculate_pattern_score()
	if _is_master_active() and _pattern_score >= 2 and not _climax_response_pending:
		_reaction_pending = true
		_reaction_timer = randf_range(REACTION_DELAY_MIN, REACTION_DELAY_MAX)
		_record_ai_event(&"pattern_read", StringName(technique.path))

func _calculate_pattern_score() -> int:
	if _recent_paths.size() < 3:
		return 0
	var score := 0
	var last := _recent_paths[_recent_paths.size() - 1]
	var same_count := 0
	for index in range(_recent_paths.size() - 1, -1, -1):
		if _recent_paths[index] == last:
			same_count += 1
		else:
			break
	if same_count >= 3:
		score += 3
	elif same_count == 2:
		score += 1

	if _recent_paths.size() >= 4:
		var a := _recent_paths[_recent_paths.size() - 4]
		var b := _recent_paths[_recent_paths.size() - 3]
		var c := _recent_paths[_recent_paths.size() - 2]
		var d := _recent_paths[_recent_paths.size() - 1]
		if a == c and b == d:
			score += 2

	var frequency := {}
	for family in _recent_paths:
		frequency[family] = int(frequency.get(family, 0)) + 1
	var dominant_count := 0
	for family in frequency:
		dominant_count = maxi(dominant_count, int(frequency[family]))
	if _recent_paths.size() >= 5 and dominant_count >= 3:
		score += 2
	return score

func _execute_pattern_response() -> void:
	if not _is_master_active():
		return
	var distance := absf(_player.global_position.x - _bot.global_position.x)
	var direction_to_player := int(signf(_player.global_position.x - _bot.global_position.x))
	if direction_to_player == 0:
		direction_to_player = 1
	_bot_runtime._decision_timer = maxf(_bot_runtime._decision_timer, 0.24)
	if distance < 175.0 and _can_dodge() and randf() < 0.64:
		_bot_runtime._set_movement(-direction_to_player)
		_bot_runtime._tap(&"dodge", 0.11)
		_bot_runtime._intent = "MESTRE • LEITURA DE PADRÃO • ESQUIVA"
		_record_ai_event(&"pattern_evade", &"master")
	else:
		_bot_runtime._set_movement(0)
		_bot_runtime._tap(&"block", 0.34)
		_bot_runtime._intent = "MESTRE • LEITURA DE PADRÃO • GUARDA"
		_record_ai_event(&"pattern_guard", &"master")
	_counter_pending = true
	_counter_timer = COUNTER_DELAY

func _execute_counter_attack() -> void:
	if not _is_master_active():
		return
	if _bot._attack_phase != FighterController.AttackPhase.NONE:
		return
	var delta_x := _player.global_position.x - _bot.global_position.x
	var distance := absf(delta_x)
	if distance <= 145.0:
		_bot_runtime._set_movement(int(signf(delta_x)))
		_bot_runtime._tap(&"attack", 0.10)
		_bot_runtime._intent = "MESTRE • CONTRA-ATAQUE APÓS LEITURA"
		_record_ai_event(&"pattern_counter", &"attack")
	elif distance <= 245.0:
		_bot_runtime._set_movement(int(signf(delta_x)))
		_bot_runtime._decision_timer = maxf(_bot_runtime._decision_timer, 0.18)

func _watch_climax() -> void:
	if not is_instance_valid(_combo):
		return
	var climax_active := bool(_combo.get("_climax_active"))
	if climax_active and not _climax_seen:
		_climax_seen = true
		_prepare_climax_response()
	elif not climax_active:
		_climax_seen = false
		_climax_response_pending = false
		_climax_response_mode = &""
		return

	if not climax_active or not _climax_response_pending:
		return
	var remaining := float(_combo.get("_climax_timer"))
	if remaining <= CLIMAX_LATE_REACTION_THRESHOLD:
		_execute_climax_response()

func _prepare_climax_response() -> void:
	if not _is_master_active():
		return
	var distance := absf(_player.global_position.x - _bot.global_position.x)
	if distance < 225.0 and _can_dodge() and randf() < 0.68:
		_climax_response_mode = &"dodge"
	else:
		_climax_response_mode = &"guard"
	_climax_response_pending = true
	_record_ai_event(&"climax_read", _climax_response_mode)

func _execute_climax_response() -> void:
	if not _is_master_active() or not _climax_response_pending:
		return
	_climax_response_pending = false
	var direction_to_player := int(signf(_player.global_position.x - _bot.global_position.x))
	if direction_to_player == 0:
		direction_to_player = 1
	_bot_runtime._decision_timer = maxf(_bot_runtime._decision_timer, 0.72)
	if _climax_response_mode == &"dodge" and _can_dodge():
		_bot_runtime._set_movement(-direction_to_player)
		_bot_runtime._tap(&"dodge", 0.10)
		_bot_runtime._intent = "MESTRE • CLIMAX LIDO • ESQUIVA TARDIA"
		_record_ai_event(&"climax_response", &"dodge")
	else:
		_bot_runtime._set_movement(0)
		_bot_runtime._tap(&"block", CLIMAX_GUARD_HOLD)
		_bot_runtime._intent = "MESTRE • CLIMAX LIDO • GUARDA/PARRY"
		_record_ai_event(&"climax_response", &"guard")
	_climax_response_mode = &""

func _can_dodge() -> bool:
	return (
		is_instance_valid(_bot)
		and _bot._dodge_cooldown_timer <= 0.0
		and _bot.stamina >= 18.0
		and not _bot._is_blocking
		and _bot._attack_phase == FighterController.AttackPhase.NONE
	)

func _record_ai_event(event_id: StringName, value_id: StringName) -> void:
	if not is_instance_valid(_telemetry):
		return
	_telemetry.record_event(&"p2", event_id, value_id)
	_telemetry.record_combat_metric(&"p2", event_id, 1.0)

func presentation_signature() -> Dictionary:
	return {
		"master_pattern_memory": true,
		"anti_mash_is_counterplay": true,
		"pattern_window": MEMORY_SIZE,
		"dominant_family_detection": true,
		"climax_telegraph_reaction": true,
		"climax_late_defense": true,
		"climax_reaction_threshold": CLIMAX_LATE_REACTION_THRESHOLD,
		"no_hidden_input_reading": true,
		"defense_then_counter": true,
		"apprentice_unchanged": true,
		"disciple_unchanged": true,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
