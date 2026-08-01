extends Node

const PLAN_DELAY := 0.16
const PLAN_RETRY := 0.20
const PLAN_RANGE := 182.0
const PRESSURE_IDLE_DELAY := 0.55
const FLOW_FOR_CLIMAX := 60.0
const FLOW_WINDOW := 2.40
const CLIMAX_TELEGRAPH := 0.48
const CLIMAX_ARM_MAX_WAIT := 1.60
const CLIMAX_STAMINA_MARGIN := 0.5
const MAX_CODE_LENGTH := 4

const RECIPES := {
	"tai>ji>tai": {"element": &"element_fire_burst", "name": "DRAGÃO ESCARLATE"},
	"ji>ji>fu": {"element": &"element_earth_anchor", "name": "RAIZ DO TITÃ"},
	"fu>tai>fu": {"element": &"element_water_wave", "name": "MARÉ DA LUA"},
	"tai>fu>tai": {"element": &"element_air_gust", "name": "SOPRO CELESTE"},
}

var _root: Node
var _bot_runtime: TacticalBotRuntime
var _bot: MasteredWeaponFighterController
var _player: MasteredWeaponFighterController
var _combo: FirstPlayableComboRuntime
var _telemetry: MatchTelemetry
var _last_technique: StringName = &""
var _last_family: StringName = &""
var _code: Array[StringName] = []
var _flow := 0.0
var _flow_timer := 0.0
var _plan_pending := false
var _plan_timer := 0.0
var _pressure_timer := PRESSURE_IDLE_DELAY
var _target_recipe := ""
var _climax_armed := false
var _climax_arm_timer := 0.0
var _climax_pending := false
var _climax_timer := 0.0
var _climax_technique: StringName = &""
var _climax_name := ""

func _ready() -> void:
	process_priority = 28
	_root = get_parent()

func _process(delta: float) -> void:
	_resolve_runtime()
	if not _is_master_active():
		return
	_flow_timer = maxf(0.0, _flow_timer - delta)
	_plan_timer = maxf(0.0, _plan_timer - delta)
	_pressure_timer = maxf(0.0, _pressure_timer - delta)
	_climax_arm_timer = maxf(0.0, _climax_arm_timer - delta)
	if _flow_timer <= 0.0 and not _code.is_empty() and not _climax_pending and not _climax_armed:
		_code.clear()
		_flow = maxf(0.0, _flow - 22.0)
		_target_recipe = ""
		_plan_pending = false
	if _climax_pending:
		_update_climax(delta)
		return
	if _climax_armed:
		_update_armed_climax()
		if _climax_armed:
			return
	if _player_climax_active():
		return
	if _plan_pending and _plan_timer <= 0.0:
		_advance_plan()
	elif not _plan_pending and _pressure_timer <= 0.0:
		_schedule_pressure_plan()

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
		var candidate_player: Variant = _root.get("player_one")
		if candidate_player is MasteredWeaponFighterController:
			_player = candidate_player as MasteredWeaponFighterController
			if not _player.impact_resolved.is_connected(_on_player_impact_resolved):
				_player.impact_resolved.connect(_on_player_impact_resolved)
	if is_instance_valid(_bot_runtime) and is_instance_valid(_bot_runtime._bot):
		var resolved_bot := _bot_runtime._bot as MasteredWeaponFighterController
		if _bot != resolved_bot:
			_bot = resolved_bot
			if is_instance_valid(_bot) and not _bot.technique_executed.is_connected(_on_bot_technique_executed):
				_bot.technique_executed.connect(_on_bot_technique_executed)

func _is_master_active() -> bool:
	return is_instance_valid(_bot_runtime) and is_instance_valid(_bot) and is_instance_valid(_player) and _bot_runtime.enabled and _bot_runtime.difficulty_id == &"master"

func _player_climax_active() -> bool:
	return is_instance_valid(_combo) and bool(_combo.get("_climax_active"))

func _on_bot_technique_executed(_fighter: MasteredWeaponFighterController, technique: TechniqueData, _variant_id: StringName) -> void:
	if not is_instance_valid(technique):
		return
	_last_technique = technique.technique_id
	_last_family = StringName(technique.path)
	_pressure_timer = PRESSURE_IDLE_DELAY

func _on_player_impact_resolved(_target: MasteredWeaponFighterController, attacker: FighterController, technique: TechniqueData, result_id: StringName, _damage: float, _posture: float, _intensity: float, _position: Vector2) -> void:
	if attacker != _bot or not is_instance_valid(technique) or technique.technique_id != _last_technique:
		return
	match result_id:
		&"hit":
			_register_hit(_last_family, 34.0)
		&"posture_break":
			_register_hit(_last_family, 44.0)
		&"blocked":
			_flow = minf(100.0, _flow + 8.0)
			_schedule_plan(PLAN_RETRY)
		&"evaded", &"parried":
			_code.clear()
			_flow = 0.0
			_target_recipe = ""
			_plan_pending = false
			_cancel_armed_climax()

func _register_hit(family: StringName, gain: float) -> void:
	if family not in [&"tai", &"ji", &"fu"]:
		return
	_flow = minf(100.0, _flow + gain)
	_flow_timer = FLOW_WINDOW
	_code.append(family)
	while _code.size() > MAX_CODE_LENGTH:
		_code.pop_front()
	if _try_arm_climax():
		return
	_select_target_recipe()
	_schedule_plan(PLAN_DELAY)

func _try_arm_climax() -> bool:
	if _code.size() < 3 or _flow < FLOW_FOR_CLIMAX:
		return false
	var key := _last_three_key()
	if not RECIPES.has(key):
		return false
	var recipe: Dictionary = RECIPES[key]
	_climax_armed = true
	_climax_arm_timer = CLIMAX_ARM_MAX_WAIT
	_climax_technique = StringName(recipe["element"])
	_climax_name = String(recipe["name"])
	_plan_pending = false
	_bot_runtime._intent = "MESTRE • FORMA ARMADA • %s" % _climax_name
	_record(&"martial_plan_complete", StringName(key))
	_record(&"climax_armed", StringName(_climax_name))
	return true

func _update_armed_climax() -> void:
	if not _climax_armed:
		return
	if _player_climax_active():
		return
	if _climax_arm_timer <= 0.0:
		_record(&"climax_deferred", &"resource_or_window")
		_cancel_armed_climax()
		_schedule_plan(PLAN_RETRY)
		return
	if _bot._attack_phase != FighterController.AttackPhase.NONE or _bot._is_blocking or _bot._dodge_timer > 0.0:
		return
	var elemental := TechniqueCatalog.get_technique(_climax_technique)
	if not is_instance_valid(elemental):
		_cancel_armed_climax()
		return
	if _bot.stamina + 0.001 < elemental.stamina_cost + CLIMAX_STAMINA_MARGIN:
		_bot_runtime._intent = "MESTRE • FORMA ARMADA • RECUPERANDO FÔLEGO"
		return
	_start_climax_telegraph()

func _start_climax_telegraph() -> void:
	_climax_armed = false
	_climax_pending = true
	_climax_timer = CLIMAX_TELEGRAPH
	_bot_runtime._set_movement(0)
	_bot_runtime._decision_timer = maxf(_bot_runtime._decision_timer, CLIMAX_TELEGRAPH + 0.18)
	_bot_runtime._intent = "MESTRE • FORMA COMPLETA • %s" % _climax_name
	_record(&"climax_started", StringName(_climax_name))

func _update_climax(delta: float) -> void:
	_climax_timer = maxf(0.0, _climax_timer - delta)
	_bot_runtime._set_movement(0)
	_bot_runtime._decision_timer = maxf(_bot_runtime._decision_timer, 0.12)
	if _climax_timer > 0.0 or _bot._attack_phase != FighterController.AttackPhase.NONE:
		return
	var elemental := TechniqueCatalog.get_technique(_climax_technique)
	if not is_instance_valid(elemental) or _bot.stamina + 0.001 < elemental.stamina_cost:
		# Não anuncia uma forma que não pode concluir: volta ao estado armado e espera recurso real.
		_climax_pending = false
		_climax_armed = true
		_climax_arm_timer = 0.35
		_bot_runtime._intent = "MESTRE • FORMA ARMADA • RECUPERANDO FÔLEGO"
		return
	var began := _bot._begin_technique(_climax_technique)
	if began:
		_bot_runtime._intent = "MESTRE • INVOCAÇÃO • %s" % _climax_name
		_record(&"climax_resolved", StringName(_climax_name))
		_reset_climax_after_resolution()
	else:
		# Corrida de estado rara: rearmar em vez de emitir falso Climax failed.
		_climax_pending = false
		_climax_armed = true
		_climax_arm_timer = 0.30
		_record(&"climax_rearmed", &"runtime_window")

func _reset_climax_after_resolution() -> void:
	_climax_pending = false
	_climax_armed = false
	_climax_technique = &""
	_climax_name = ""
	_code.clear()
	_flow = 0.0
	_flow_timer = 0.0
	_target_recipe = ""
	_pressure_timer = PRESSURE_IDLE_DELAY

func _cancel_armed_climax() -> void:
	_climax_armed = false
	_climax_pending = false
	_climax_arm_timer = 0.0
	_climax_timer = 0.0
	_climax_technique = &""
	_climax_name = ""

func _schedule_plan(delay: float) -> void:
	if _climax_pending or _climax_armed:
		return
	_plan_pending = true
	_plan_timer = delay

func _schedule_pressure_plan() -> void:
	if not _is_master_active() or _player_climax_active() or _climax_pending or _climax_armed:
		return
	if _bot._attack_phase != FighterController.AttackPhase.NONE or _bot._is_blocking or _bot._dodge_timer > 0.0:
		_pressure_timer = 0.16
		return
	_select_target_recipe()
	_plan_pending = true
	_plan_timer = 0.0
	_pressure_timer = PRESSURE_IDLE_DELAY
	_record(&"martial_pressure", StringName(_target_recipe))

func _advance_plan() -> void:
	if not _is_master_active() or _climax_pending or _climax_armed or _player_climax_active():
		return
	if _bot._attack_phase != FighterController.AttackPhase.NONE or _bot._is_blocking or _bot._dodge_timer > 0.0:
		_schedule_plan(PLAN_RETRY)
		return
	var delta_x := _player.global_position.x - _bot.global_position.x
	var distance := absf(delta_x)
	if distance > PLAN_RANGE:
		_bot_runtime._set_movement(int(signf(delta_x)))
		_bot_runtime._decision_timer = maxf(_bot_runtime._decision_timer, 0.16)
		_schedule_plan(PLAN_RETRY)
		return
	_select_target_recipe()
	var desired_family := _next_planned_family()
	if desired_family == &"":
		_plan_pending = false
		return
	var technique_id := _technique_for_family(desired_family)
	if technique_id == &"":
		_schedule_plan(PLAN_RETRY)
		return
	_bot_runtime._set_movement(int(signf(delta_x)))
	if _bot._begin_technique(technique_id):
		_bot_runtime._decision_timer = maxf(_bot_runtime._decision_timer, 0.30)
		_bot_runtime._intent = "MESTRE • FORMA • %s" % String(desired_family).to_upper()
		_record(&"martial_plan_step", StringName("%s:%s" % [_target_recipe, desired_family]))
		_plan_pending = false
		_pressure_timer = PRESSURE_IDLE_DELAY
	else:
		_schedule_plan(PLAN_RETRY)

func _select_target_recipe() -> void:
	var best_key := ""
	var best_progress := 0
	for key in RECIPES.keys():
		var progress := _recipe_progress(String(key))
		if progress > best_progress and progress < 3:
			best_key = String(key)
			best_progress = progress
	if not best_key.is_empty():
		_target_recipe = best_key
		return
	if not _code.is_empty():
		var last := String(_code.back())
		for key in RECIPES.keys():
			if String(key).begins_with(last + ">"):
				_target_recipe = String(key)
				return
	_target_recipe = "tai>ji>tai"

func _recipe_progress(recipe_key: String) -> int:
	var parts := recipe_key.split(">")
	var max_check := mini(2, mini(parts.size(), _code.size()))
	for length in range(max_check, 0, -1):
		var matches := true
		for index in range(length):
			if String(_code[_code.size() - length + index]) != String(parts[index]):
				matches = false
				break
		if matches:
			return length
	return 0

func _next_planned_family() -> StringName:
	if _target_recipe.is_empty():
		return &""
	var parts := _target_recipe.split(">")
	var progress := _recipe_progress(_target_recipe)
	if progress >= parts.size():
		return &""
	return StringName(parts[progress])

func _technique_for_family(family: StringName) -> StringName:
	var technique_id := _bot.build.technique_for(String(family), 0)
	if technique_id == &"ji_shove":
		technique_id = &"gauntlet_center_crush"
	return technique_id

func _last_three_key() -> String:
	var count := _code.size()
	return "%s>%s>%s" % [_code[count - 3], _code[count - 2], _code[count - 1]]

func _record(event_id: StringName, value_id: StringName) -> void:
	if not is_instance_valid(_telemetry):
		return
	_telemetry.record_event(&"p2", event_id, value_id)
	_telemetry.record_combat_metric(&"p2", event_id, 1.0)

func presentation_signature() -> Dictionary:
	return {
		"master_recipe_planner": true,
		"plans_from_confirmed_hits": true,
		"recipe_prefix_recovery": true,
		"planned_tai_ji_fu_steps": true,
		"proactive_pressure_planning": true,
		"pressure_idle_seconds": PRESSURE_IDLE_DELAY,
		"flow_threshold": FLOW_FOR_CLIMAX,
		"climax_telegraph_seconds": CLIMAX_TELEGRAPH,
		"climax_armed_before_telegraph": true,
		"climax_stamina_preflight": true,
		"false_climax_failure_removed": true,
		"element_requires_completed_recipe": true,
		"dedicated_push_attack": false,
		"player_climax_has_defensive_priority": true,
		"damage_changes": false,
		"attribute_buffs": false,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions