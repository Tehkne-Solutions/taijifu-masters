class_name FirstPlayableAdaptiveMasterRuntime
extends Node

const MEMORY_SIZE := 5
const REACTION_DELAY_MIN := 0.070
const REACTION_DELAY_MAX := 0.120
const COUNTER_DELAY := 0.13
const CLIMAX_LATE_REACTION_THRESHOLD := 0.055
const CLIMAX_GUARD_HOLD := 0.72
const BOT_FLOW_FOR_CLIMAX := 60.0
const BOT_FLOW_WINDOW := 2.40

const BOT_RECIPES := {
	"tai>ji>tai": {"technique": &"element_fire_burst", "name": "DRAGÃO ESCARLATE"},
	"ji>ji>fu": {"technique": &"element_earth_anchor", "name": "RAIZ DO TITÃ"},
	"fu>tai>fu": {"technique": &"element_water_wave", "name": "MARÉ DA LUA"},
	"tai>fu>tai": {"technique": &"element_air_gust", "name": "SOPRO CELESTE"},
}

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
var _bot_code: Array[StringName] = []
var _bot_flow := 0.0
var _bot_flow_timer := 0.0
var _bot_last_technique: StringName = &""
var _bot_last_family: StringName = &""

func _ready() -> void:
	process_priority = 30
	_root = get_parent()

func _process(delta: float) -> void:
	_resolve_runtime()
	if not _is_master_active():
		return
	# Empurrão dedicado não pertence ao First Playable: knockback nasce dos golpes.
	Input.action_release(_bot._action("push"))
	_reaction_timer = maxf(0.0, _reaction_timer - delta)
	_counter_timer = maxf(0.0, _counter_timer - delta)
	_bot_flow_timer = maxf(0.0, _bot_flow_timer - delta)
	if _bot_flow_timer <= 0.0 and not _bot_code.is_empty():
		_bot_code.clear()
		_bot_flow = maxf(0.0, _bot_flow - 22.0)
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
			if not _player.impact_resolved.is_connected(_on_player_impact_resolved):
				_player.impact_resolved.connect(_on_player_impact_resolved)
	if is_instance_valid(_bot_runtime) and is_instance_valid(_bot_runtime._bot):
		var resolved_bot := _bot_runtime._bot as MasteredWeaponFighterController
		if _bot != resolved_bot:
			_bot = resolved_bot
			if is_instance_valid(_bot) and not _bot.technique_executed.is_connected(_on_bot_technique_executed):
				_bot.technique_executed.connect(_on_bot_technique_executed)

func _is_master_active() -> bool:
	return is_instance_valid(_bot_runtime) and is_instance_valid(_player) and is_instance_valid(_bot) and _bot_runtime.enabled and _bot_runtime.difficulty_id == &"master"

func _on_player_technique_executed(_fighter: MasteredWeaponFighterController, technique: TechniqueData, _variant_id: StringName) -> void:
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

func _on_bot_technique_executed(_fighter: MasteredWeaponFighterController, technique: TechniqueData, _variant_id: StringName) -> void:
	if not is_instance_valid(technique):
		return
	_bot_last_technique = technique.technique_id
	_bot_last_family = StringName(technique.path)

func _on_player_impact_resolved(_target: MasteredWeaponFighterController, attacker: FighterController, technique: TechniqueData, result_id: StringName, _damage: float, _posture: float, _intensity: float, _position: Vector2) -> void:
	if attacker != _bot or not is_instance_valid(technique) or technique.technique_id != _bot_last_technique:
		return
	if result_id == &"hit" or result_id == &"posture_break":
		_register_bot_martial_hit(_bot_last_family, 44.0 if result_id == &"posture_break" else 34.0)
	elif result_id == &"blocked":
		_bot_flow = minf(100.0, _bot_flow + 8.0)
	elif result_id == &"evaded" or result_id == &"parried":
		_bot_code.clear()
		_bot_flow = 0.0

func _register_bot_martial_hit(family: StringName, gain: float) -> void:
	if family != &"tai" and family != &"ji" and family != &"fu":
		return
	_bot_flow = minf(100.0, _bot_flow + gain)
	_bot_flow_timer = BOT_FLOW_WINDOW
	_bot_code.append(family)
	while _bot_code.size() > 4:
		_bot_code.pop_front()
	_record_ai_event(&"martial_code", StringName(_bot_code_key()))
	_telemetry.record_combat_metric(&"p2", &"code_steps", 1.0)
	_telemetry.record_combat_max(&"p2", &"max_flow", _bot_flow)
	_try_bot_climax()

func _try_bot_climax() -> void:
	if _bot_code.size() < 3 or _bot_flow < BOT_FLOW_FOR_CLIMAX or _bot._attack_phase != FighterController.AttackPhase.NONE:
		return
	var key := _last_three_bot_code_key()
	if not BOT_RECIPES.has(key):
		return
	var recipe: Dictionary = BOT_RECIPES[key]
	var technique_id := StringName(recipe["technique"])
	if _bot._begin_technique(technique_id):
		_record_ai_event(&"climax_started", StringName(recipe["name"]))
		_telemetry.record_combat_metric(&"p2", &"climax_started", 1.0)
		_bot_runtime._intent = "MESTRE • FORMA ELEMENTAL • %s" % String(recipe["name"])
		_bot_code.clear()
		_bot_flow = maxf(0.0, _bot_flow - BOT_FLOW_FOR_CLIMAX)

func _bot_code_key() -> String:
	var parts: Array[String] = []
	for family in _bot_code:
		parts.append(String(family))
	return ">".join(parts)

func _last_three_bot_code_key() -> String:
	var count := _bot_code.size()
	return "%s>%s>%s" % [_bot_code[count - 3], _bot_code[count - 2], _bot_code[count - 1]]

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
		_bot_runtime._intent = "MESTRE • LEITURA • ESQUIVA"
		_record_ai_event(&"pattern_evade", &"master")
	else:
		_bot_runtime._set_movement(0)
		_bot_runtime._tap(&"block", 0.34)
		_bot_runtime._intent = "MESTRE • LEITURA • GUARDA"
		_record_ai_event(&"pattern_guard", &"master")
	_counter_pending = true
	_counter_timer = COUNTER_DELAY

func _execute_counter_attack() -> void:
	if not _is_master_active() or _bot._attack_phase != FighterController.AttackPhase.NONE:
		return
	var delta_x := _player.global_position.x - _bot.global_position.x
	var distance := absf(delta_x)
	if distance > 175.0:
		_bot_runtime._set_movement(int(signf(delta_x)))
		_bot_runtime._decision_timer = maxf(_bot_runtime._decision_timer, 0.12)
		return
	_bot_runtime._set_movement(int(signf(delta_x)))
	var technique_id := _counter_technique_for_opening()
	if technique_id != &"" and _bot._begin_technique(technique_id):
		_bot_runtime._intent = "MESTRE • CONVERSÃO • %s" % String(technique_id).to_upper()
		_record_ai_event(&"pattern_counter", technique_id)

func _counter_technique_for_opening() -> StringName:
	# Converte leitura em técnica real; alterna famílias para construir código próprio.
	var desired_family: StringName = &"ji"
	if _bot_code.is_empty():
		desired_family = &"tai"
	elif _bot_code.back() == &"tai":
		desired_family = &"ji"
	elif _bot_code.back() == &"ji":
		desired_family = &"fu"
	else:
		desired_family = &"tai"
	var technique_id := _bot.build.technique_for(String(desired_family), 0)
	if technique_id == &"" or technique_id == &"ji_shove":
		technique_id = _bot.build.technique_for("ji", 0)
	if technique_id == &"ji_shove":
		technique_id = &"gauntlet_center_crush"
	return technique_id

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
	_climax_response_mode = &"dodge" if distance < 225.0 and _can_dodge() and randf() < 0.68 else &"guard"
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
		_bot_runtime._intent = "MESTRE • CLIMAX • ESQUIVA TARDIA"
		_record_ai_event(&"climax_response", &"dodge")
	else:
		_bot_runtime._set_movement(0)
		_bot_runtime._tap(&"block", CLIMAX_GUARD_HOLD)
		_bot_runtime._intent = "MESTRE • CLIMAX • GUARDA/PARRY"
		_record_ai_event(&"climax_response", &"guard")
	_climax_response_mode = &""

func _can_dodge() -> bool:
	return is_instance_valid(_bot) and _bot._dodge_cooldown_timer <= 0.0 and _bot.stamina >= 18.0 and not _bot._is_blocking and _bot._attack_phase == FighterController.AttackPhase.NONE

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
		"counter_uses_real_technique": true,
		"dedicated_push_disabled": true,
		"bot_builds_martial_code": true,
		"bot_builds_flow": true,
		"bot_elemental_climax": true,
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
