class_name TacticalBotRuntime
extends Node

@onready var arena: TriplePathArena = get_node("../Arena")
@onready var hud: CanvasLayer = get_node("../HUD")

var enabled := true
var difficulty_id: StringName = &"disciple"
var personality_id: StringName = &"technical"

var _bot: FighterController
var _opponent: FighterController
var _status_label: Label
var _decision_timer := 0.0
var _route_timer := 0.0
var _reaction_timer := 0.0
var _jump_cooldown := 0.0
var _navigation_timer := 0.0
var _reaction_pending := false
var _movement_direction := 0
var _preferred_route: StringName = &"fu"
var _objective: StringName = &"control"
var _strategic_target := Vector2.ZERO
var _strategic_point_id: StringName = &"none"
var _intent := "AGUARDANDO LUTADORES"
var _tap_timers: Dictionary = {}
var _grab_escape_side := -1
var _grab_throw_suffix: StringName = &""
var _last_bot_position := Vector2.ZERO
var _stuck_timer := 0.0

func _ready() -> void:
	_register_key_action(&"toggle_bot", KEY_TAB)
	_register_key_action(&"cycle_bot_difficulty", KEY_F4)
	_register_key_action(&"cycle_bot_personality", KEY_F7)
	_create_status_label()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"toggle_bot"):
		enabled = not enabled
		_release_all_actions()
		_intent = "BOT ATIVADO" if enabled else "CONTROLE LOCAL P2"

	if Input.is_action_just_pressed(&"cycle_bot_difficulty"):
		difficulty_id = BotBehaviorCatalog.cycle_difficulty(difficulty_id)
		_reset_decision_state("DIFICULDADE ALTERADA")

	if Input.is_action_just_pressed(&"cycle_bot_personality"):
		personality_id = BotBehaviorCatalog.cycle_personality(personality_id)
		_reset_decision_state("PERSONALIDADE ALTERADA")

	_update_taps(delta)
	_discover_fighters()
	_update_status_label()

	if not enabled or not is_instance_valid(_bot) or not is_instance_valid(_opponent):
		_set_movement(0)
		return

	_decision_timer = maxf(0.0, _decision_timer - delta)
	_route_timer = maxf(0.0, _route_timer - delta)
	_reaction_timer = maxf(0.0, _reaction_timer - delta)
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	_navigation_timer = maxf(0.0, _navigation_timer - delta)
	_update_stuck_state(delta)
	_drive_bot()

func _discover_fighters() -> void:
	if is_instance_valid(_bot) and is_instance_valid(_opponent):
		return
	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is FighterController):
			continue
		var fighter := node as FighterController
		if fighter.player_index == 1:
			_opponent = fighter
		elif fighter.player_index == 2:
			_bot = fighter
	if is_instance_valid(_bot):
		_last_bot_position = _bot.global_position
		_navigation_timer = 0.0

func _drive_bot() -> void:
	if is_instance_valid(_bot._grabbed_by):
		_handle_grab_escape()
		return

	if is_instance_valid(_bot._grabbed_target):
		_handle_active_grab()
		return

	_release_throw_direction()
	if _route_timer <= 0.0:
		_preferred_route = _choose_preferred_route()
		_route_timer = randf_range(1.8, 3.2) * float(_difficulty().get("navigation_multiplier", 1.0))

	var delta_position := _opponent.global_position - _bot.global_position
	var distance := absf(delta_position.x)
	var vertical_distance := absf(delta_position.y)
	var direction_to_opponent := int(signf(delta_position.x))
	if direction_to_opponent == 0:
		direction_to_opponent = 1

	if _bot._attack_phase == FighterController.AttackPhase.NONE:
		_bot.facing = float(direction_to_opponent)

	if _is_in_boundary_danger():
		_reaction_pending = false
		_select_navigation_target(&"escape")
		_navigate_to_target(true)
		return

	var incoming_attack := (
		_opponent._attack_phase == FighterController.AttackPhase.STARTUP
		or _opponent._attack_phase == FighterController.AttackPhase.ACTIVE
	)
	if incoming_attack and distance < 190.0:
		if not _reaction_pending:
			_reaction_pending = true
			_reaction_timer = _reaction_delay()
			_intent = "PERCEPÇÃO • LENDO ATAQUE"
		if _reaction_timer <= 0.0:
			_reaction_pending = false
			_react_to_attack(direction_to_opponent)
		return
	else:
		_reaction_pending = false

	if _navigation_timer <= 0.0:
		_refresh_navigation_target(distance, vertical_distance)

	if _should_navigate(distance, vertical_distance):
		_navigate_to_target(false)
		return

	if _decision_timer > 0.0:
		_apply_range_movement(distance, direction_to_opponent)
		return

	_decision_timer = _decision_delay()
	_choose_combat_action(distance, direction_to_opponent)

func _refresh_navigation_target(distance: float, vertical_distance: float) -> void:
	_objective = _choose_objective(distance, vertical_distance)
	if _objective == &"contest":
		var manifestation := arena.active_manifestation_data()
		if not manifestation.is_empty():
			_strategic_target = manifestation["global_position"]
			_strategic_point_id = StringName("manifestation_%s" % String(manifestation["type"]))
			_navigation_timer = randf_range(0.55, 0.85) * float(_difficulty().get("navigation_multiplier", 1.0))
			return

	_select_navigation_target(_objective)

func _select_navigation_target(objective_id: StringName) -> void:
	_objective = objective_id
	var point := arena.best_strategic_point(
		_preferred_route,
		_bot.global_position,
		_opponent.global_position,
		objective_id
	)
	_strategic_target = point.get("global_position", _opponent.global_position)
	_strategic_point_id = StringName(point.get("id", &"fallback"))
	_navigation_timer = randf_range(0.85, 1.35) * float(_difficulty().get("navigation_multiplier", 1.0))

func _choose_objective(distance: float, vertical_distance: float) -> StringName:
	var personality := _personality()
	var posture_ratio := _bot.posture / maxf(1.0, _bot.build.max_posture())
	var recovery_threshold := float(personality.get("recovery_threshold", 0.28))
	if posture_ratio < recovery_threshold:
		return &"escape"

	var manifestation := arena.active_manifestation_data()
	if not manifestation.is_empty():
		var manifestation_position: Vector2 = manifestation["global_position"]
		var manifestation_type := StringName(manifestation["type"])
		var needs_resource := (
			manifestation_type == &"tai" and _bot.stamina < 72.0
			or manifestation_type == &"ji" and posture_ratio < 0.72
			or manifestation_type == &"fu" and (_bot.health < _bot.build.max_health() * 0.84 or _bot.stamina < 68.0)
		)
		var contest_chance := float(personality.get("contest_chance", 0.62))
		if _bot.global_position.distance_to(manifestation_position) < 610.0 and (
			needs_resource or manifestation_type == _preferred_route
		) and randf() < contest_chance:
			return &"contest"

	var preferred_objective := StringName(personality.get("preferred_objective", &"control"))
	if personality_id == &"chaotic" and randf() < 0.28:
		return [&"engage", &"range", &"transition", &"control"].pick_random()
	if vertical_distance > 145.0:
		return &"transition"
	if personality_id == &"aggressive" and distance < 390.0:
		return &"engage"
	if personality_id == &"guardian" and distance < 245.0:
		return &"control"
	if _preferred_route == &"tai" and distance > 180.0:
		return &"range"
	if _preferred_route == &"ji":
		return &"engage"
	return preferred_objective

func _should_navigate(distance: float, vertical_distance: float) -> bool:
	if _strategic_target == Vector2.ZERO:
		return false
	if _objective == &"escape" or _objective == &"contest":
		return _bot.global_position.distance_to(_strategic_target) > 48.0
	if distance < 205.0 and vertical_distance < 105.0:
		return false
	return _bot.global_position.distance_to(_strategic_target) > 78.0

func _navigate_to_target(force_forward: bool) -> void:
	var delta_target := _strategic_target - _bot.global_position
	var direction := int(signf(delta_target.x))
	if force_forward:
		direction = 1
	_set_movement(direction)

	if absf(delta_target.x) <= 55.0:
		_set_movement(0)

	if delta_target.y < -68.0 and _bot.is_on_floor() and _jump_cooldown <= 0.0:
		_tap(&"jump", 0.12)
		_jump_cooldown = 0.68
	elif _stuck_timer >= 0.72 and _bot.is_on_floor() and _jump_cooldown <= 0.0:
		_tap(&"jump", 0.12)
		_jump_cooldown = 0.82
		_stuck_timer = 0.0

	_intent = "%s • NAVEGAR %s" % [_objective.to_upper(), String(_strategic_point_id).to_upper()]

func _update_stuck_state(delta: float) -> void:
	if not is_instance_valid(_bot):
		return
	if _movement_direction != 0 and _bot.global_position.distance_to(_last_bot_position) < 3.0:
		_stuck_timer += delta
	else:
		_stuck_timer = maxf(0.0, _stuck_timer - delta * 2.0)
	_last_bot_position = _bot.global_position

func _react_to_attack(direction_to_opponent: int) -> void:
	_decision_timer = _decision_delay()
	var difficulty := _difficulty()
	var personality := _personality()
	var mistake_chance := float(difficulty.get("mistake_chance", 0.14))
	if randf() < mistake_chance:
		_set_movement(0)
		_intent = "ERRO DE LEITURA • RESPOSTA TARDIA"
		return

	var posture_ratio := _bot.posture / maxf(1.0, _bot.build.max_posture())
	var defense_chance := clampf(
		float(difficulty.get("defense_chance", 0.52)) * float(personality.get("defense_multiplier", 1.0)),
		0.12,
		0.84
	)
	if posture_ratio > 0.30 and randf() < defense_chance:
		_set_movement(0)
		_tap(&"block", 0.24)
		_intent = "FU • DEFENDER/APARAR"
	else:
		_set_movement(-direction_to_opponent)
		_tap(&"dodge", 0.10)
		_intent = "FU • ESQUIVA REATIVA"

func _choose_combat_action(distance: float, direction_to_opponent: int) -> void:
	var difficulty := _difficulty()
	var personality := _personality()
	var posture_ratio := _bot.posture / maxf(1.0, _bot.build.max_posture())
	if randf() < float(difficulty.get("mistake_chance", 0.14)):
		_make_tactical_error(direction_to_opponent)
		return

	if posture_ratio < float(personality.get("recovery_threshold", 0.28)) and distance < 210.0:
		_set_movement(-direction_to_opponent)
		_tap(&"block", 0.28)
		_intent = "RECUAR E RECOMPOR POSTURA"
		return

	if distance <= 92.0:
		_set_movement(direction_to_opponent)
		var grab_weight := float(personality.get("grab_weight", 0.26))
		var push_weight := float(personality.get("push_weight", 0.22))
		var close_roll := randf()
		if close_roll < grab_weight and _bot.stamina >= 18.0:
			_tap(&"grab")
			_intent = "JI • BUSCAR CONTROLE"
		elif close_roll < grab_weight + push_weight:
			_tap(&"push")
			_intent = "JI • QUEBRAR FUNDAÇÃO"
		else:
			_tap(&"attack")
			_intent = "JI • PRESSÃO DO KIT"
		return

	var element_chance := float(personality.get("element_chance", 0.24))
	if distance <= 270.0:
		_set_movement(direction_to_opponent if randf() < 0.52 else 0)
		if _bot.stamina >= 24.0 and randf() < element_chance:
			_tap(&"element")
			_intent = "FU • ALTERAR CONDIÇÃO ELEMENTAL"
		else:
			_tap(&"attack")
			_intent = "%s • TÉCNICA DO KIT" % _preferred_route.to_upper()
		return

	_set_movement(direction_to_opponent)
	if distance < 430.0 and _bot.stamina >= 28.0 and randf() < element_chance * 0.72:
		_tap(&"element")
		_intent = "FU • PROJEÇÃO ELEMENTAL"
	else:
		_intent = "TAI • APROXIMAÇÃO"

func _make_tactical_error(direction_to_opponent: int) -> void:
	var error_roll := randf()
	if error_roll < 0.34:
		_set_movement(0)
		_intent = "HESITAÇÃO • SEM AÇÃO"
	elif error_roll < 0.67:
		_set_movement(-direction_to_opponent)
		_intent = "LEITURA INCORRETA • RECUO"
	else:
		_set_movement(direction_to_opponent)
		_tap(&"attack")
		_intent = "ENTRADA PREVISÍVEL"

func _apply_range_movement(distance: float, direction_to_opponent: int) -> void:
	var desired_range := _desired_range()
	if personality_id == &"aggressive":
		desired_range *= 0.82
	elif personality_id == &"guardian":
		desired_range *= 1.12
	if distance > desired_range + 55.0:
		_set_movement(direction_to_opponent)
	elif distance < desired_range - 35.0 and _preferred_route == &"tai":
		_set_movement(-direction_to_opponent)
	else:
		_set_movement(0)

func _handle_grab_escape() -> void:
	_release_throw_direction()
	_set_movement(0)
	if _decision_timer > 0.0:
		return
	var difficulty := _difficulty()
	_decision_timer = randf_range(
		float(difficulty.get("escape_interval_min", 0.12)),
		float(difficulty.get("escape_interval_max", 0.20))
	)
	_grab_escape_side *= -1
	_tap(&"left" if _grab_escape_side < 0 else &"right")
	if _bot.stamina >= 24.0 and randf() < float(difficulty.get("escape_dodge_chance", 0.32)):
		_tap(&"dodge")
	_intent = "FU • DISPUTAR FUGA"

func _handle_active_grab() -> void:
	_set_movement(0)
	if _grab_throw_suffix == &"":
		var throw_roll := randf()
		if personality_id == &"aggressive":
			throw_roll = minf(0.71, throw_roll)
		if throw_roll < 0.24:
			_grab_throw_suffix = &"jump"
		elif throw_roll < 0.48:
			_grab_throw_suffix = &"down"
		elif throw_roll < 0.72:
			_grab_throw_suffix = &"left" if _bot.facing > 0.0 else &"right"
		else:
			_grab_throw_suffix = &"right" if _bot.facing > 0.0 else &"left"
		_hold_action(_grab_throw_suffix, true)

	if _decision_timer <= 0.0 and _bot.stamina >= 18.0:
		_decision_timer = _decision_delay()
		_tap(&"grab")
	_intent = "JI • MANTER E PROJETAR"

func _release_throw_direction() -> void:
	if _grab_throw_suffix == &"":
		return
	_hold_action(_grab_throw_suffix, false)
	_grab_throw_suffix = &""

func _choose_preferred_route() -> StringName:
	var values := {
		&"tai": _bot.build.tai_index(),
		&"ji": _bot.build.ji_index(),
		&"fu": _bot.build.fu_index()
	}
	var personality := _personality()
	var route_bias := StringName(personality.get("route_bias", &"fu"))
	if route_bias == &"random":
		route_bias = [&"tai", &"ji", &"fu"].pick_random()
	values[route_bias] = float(values.get(route_bias, 0.0)) + float(personality.get("route_bias_amount", 0.0))

	var best_route: StringName = &"fu"
	var best_value := -INF
	for route_variant in values.keys():
		var route_id := StringName(route_variant)
		var value := float(values[route_variant])
		if value > best_value:
			best_value = value
			best_route = route_id
	return best_route

func _desired_range() -> float:
	match _bot.equipped_weapon_id:
		&"training_staff":
			return 150.0
		&"seismic_gauntlets", &"breaker_gauntlets":
			return 78.0
		&"wind_wraps":
			return 118.0
		_:
			return 88.0

func _is_in_boundary_danger() -> bool:
	return _bot.global_position.x < arena.camera_left_limit() + 165.0

func _reaction_delay() -> float:
	var perception_ratio := clampf(_bot.build.perception / 100.0, 0.0, 1.0)
	var base_delay := lerpf(0.38, 0.17, perception_ratio) + randf_range(-0.02, 0.07)
	return maxf(0.10, base_delay * float(_difficulty().get("reaction_multiplier", 1.0)))

func _decision_delay() -> float:
	var difficulty := _difficulty()
	return randf_range(
		float(difficulty.get("decision_min", 0.28)),
		float(difficulty.get("decision_max", 0.48))
	)

func _difficulty() -> Dictionary:
	return BotBehaviorCatalog.difficulty(difficulty_id)

func _personality() -> Dictionary:
	return BotBehaviorCatalog.personality(personality_id)

func _reset_decision_state(message: String) -> void:
	_release_all_actions()
	_decision_timer = 0.0
	_route_timer = 0.0
	_navigation_timer = 0.0
	_reaction_timer = 0.0
	_intent = message

func _set_movement(direction: int) -> void:
	direction = clampi(direction, -1, 1)
	if direction == _movement_direction:
		return
	_hold_action(&"left", false)
	_hold_action(&"right", false)
	_movement_direction = direction
	if direction < 0:
		_hold_action(&"left", true)
	elif direction > 0:
		_hold_action(&"right", true)

func _tap(suffix: StringName, duration: float = 0.09) -> void:
	if not is_instance_valid(_bot):
		return
	var action := _bot._action(String(suffix))
	Input.action_release(action)
	Input.action_press(action)
	_tap_timers[action] = maxf(duration, float(_tap_timers.get(action, 0.0)))

func _hold_action(suffix: StringName, pressed: bool) -> void:
	if not is_instance_valid(_bot):
		return
	var action := _bot._action(String(suffix))
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
		_tap_timers.erase(action)

func _update_taps(delta: float) -> void:
	for action_variant in _tap_timers.keys():
		var action := StringName(action_variant)
		var remaining := float(_tap_timers[action]) - delta
		if remaining <= 0.0:
			Input.action_release(action)
			_tap_timers.erase(action)
		else:
			_tap_timers[action] = remaining

func _release_all_actions() -> void:
	if not is_instance_valid(_bot):
		_tap_timers.clear()
		_movement_direction = 0
		_grab_throw_suffix = &""
		return
	for suffix in [&"left", &"right", &"down", &"jump", &"dodge", &"attack", &"push", &"grab", &"echo", &"block", &"element"]:
		Input.action_release(_bot._action(String(suffix)))
	_tap_timers.clear()
	_movement_direction = 0
	_grab_throw_suffix = &""
	_reaction_pending = false
	_strategic_target = Vector2.ZERO

func _register_key_action(action_id: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == physical_keycode:
			return
	InputMap.action_add_event(action_id, event)

func _create_status_label() -> void:
	_status_label = Label.new()
	_status_label.offset_left = 220.0
	_status_label.offset_top = 594.0
	_status_label.offset_right = 1060.0
	_status_label.offset_bottom = 642.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0, 0.96))
	hud.add_child(_status_label)

func _update_status_label() -> void:
	if not is_instance_valid(_status_label):
		return
	var difficulty_label := BotBehaviorCatalog.difficulty_label(difficulty_id)
	var personality_label := BotBehaviorCatalog.personality_label(personality_id)
	if enabled:
		_status_label.text = "TAB BOT • F4 %s • F7 %s • %s • ROTA %s • %s" % [
			difficulty_label,
			personality_label,
			_intent,
			_preferred_route.to_upper(),
			String(_strategic_point_id).to_upper()
		]
	else:
		_status_label.text = "TAB: P2 LOCAL • F2 RELATÓRIO • F3 HEATMAP • F4/F7 CONFIGURAM IA"
