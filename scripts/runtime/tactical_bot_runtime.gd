class_name TacticalBotRuntime
extends Node

@onready var arena: TriplePathArena = get_node("../Arena")
@onready var hud: CanvasLayer = get_node("../HUD")

var enabled := true
var _bot: FighterController
var _opponent: FighterController
var _status_label: Label
var _decision_timer := 0.0
var _route_timer := 0.0
var _reaction_timer := 0.0
var _jump_cooldown := 0.0
var _reaction_pending := false
var _movement_direction := 0
var _preferred_route: StringName = &"fu"
var _intent := "AGUARDANDO LUTADORES"
var _tap_timers: Dictionary = {}
var _grab_escape_side := -1
var _grab_throw_suffix: StringName = &""

func _ready() -> void:
	_register_toggle_action()
	_create_status_label()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"toggle_bot"):
		enabled = not enabled
		_release_all_actions()
		_intent = "BOT ATIVADO" if enabled else "CONTROLE LOCAL P2"

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
		_route_timer = randf_range(1.8, 3.2)

	var delta_position := _opponent.global_position - _bot.global_position
	var distance := absf(delta_position.x)
	var direction_to_opponent := int(signf(delta_position.x))
	if direction_to_opponent == 0:
		direction_to_opponent = 1

	if _bot._attack_phase == FighterController.AttackPhase.NONE:
		_bot.facing = float(direction_to_opponent)

	if _is_in_boundary_danger():
		_reaction_pending = false
		_set_movement(1)
		_intent = "FU • ESCAPAR DO COLAPSO"
		_try_route_jump()
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

	if _decision_timer > 0.0:
		_apply_range_movement(distance, direction_to_opponent)
		_try_route_jump()
		return

	_decision_timer = _reaction_delay()
	_choose_combat_action(distance, direction_to_opponent)
	_try_route_jump()

func _react_to_attack(direction_to_opponent: int) -> void:
	_decision_timer = randf_range(0.28, 0.48)
	var posture_ratio := _bot.posture / maxf(1.0, _bot.build.max_posture())
	if posture_ratio > 0.30 and randf() < 0.62:
		_set_movement(0)
		_tap(&"block", 0.24)
		_intent = "FU • DEFENDER/APARAR"
	else:
		_set_movement(-direction_to_opponent)
		_tap(&"dodge", 0.10)
		_intent = "FU • ESQUIVA REATIVA"

func _choose_combat_action(distance: float, direction_to_opponent: int) -> void:
	var posture_ratio := _bot.posture / maxf(1.0, _bot.build.max_posture())
	if posture_ratio < 0.28 and distance < 210.0:
		_set_movement(-direction_to_opponent)
		_tap(&"block", 0.28)
		_intent = "RECUAR E RECOMPOR POSTURA"
		return

	if distance <= 92.0:
		_set_movement(direction_to_opponent)
		var close_roll := randf()
		if close_roll < 0.28 and _bot.stamina >= 18.0:
			_tap(&"grab")
			_intent = "JI • BUSCAR CONTROLE"
		elif close_roll < 0.50:
			_tap(&"push")
			_intent = "JI • QUEBRAR FUNDAÇÃO"
		else:
			_tap(&"attack")
			_intent = "JI • PRESSÃO DO KIT"
		return

	if distance <= 270.0:
		_set_movement(direction_to_opponent if randf() < 0.52 else 0)
		if _bot.stamina >= 24.0 and randf() < 0.26:
			_tap(&"element")
			_intent = "FU • ALTERAR CONDIÇÃO ELEMENTAL"
		else:
			_tap(&"attack")
			_intent = "%s • TÉCNICA DO KIT" % _preferred_route.to_upper()
		return

	_set_movement(direction_to_opponent)
	if distance < 430.0 and _bot.stamina >= 28.0 and randf() < 0.18:
		_tap(&"element")
		_intent = "FU • PROJEÇÃO ELEMENTAL"
	else:
		_intent = "TAI • APROXIMAÇÃO"

func _apply_range_movement(distance: float, direction_to_opponent: int) -> void:
	var desired_range := _desired_range()
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
	_decision_timer = randf_range(0.10, 0.18)
	_grab_escape_side *= -1
	_tap(&"left" if _grab_escape_side < 0 else &"right")
	if _bot.stamina >= 24.0 and randf() < 0.34:
		_tap(&"dodge")
	_intent = "FU • DISPUTAR FUGA"

func _handle_active_grab() -> void:
	_set_movement(0)
	if _grab_throw_suffix == &"":
		var throw_roll := randf()
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
		_decision_timer = randf_range(0.34, 0.48)
		_tap(&"grab")
	_intent = "JI • MANTER E PROJETAR"

func _release_throw_direction() -> void:
	if _grab_throw_suffix == &"":
		return
	_hold_action(_grab_throw_suffix, false)
	_grab_throw_suffix = &""

func _choose_preferred_route() -> StringName:
	var tai := _bot.build.tai_index()
	var ji := _bot.build.ji_index()
	var fu := _bot.build.fu_index()
	if tai >= ji and tai >= fu:
		return &"tai"
	if ji >= tai and ji >= fu:
		return &"ji"
	return &"fu"

func _try_route_jump() -> void:
	if _jump_cooldown > 0.0 or not _bot.is_on_floor():
		return
	if _bot._attack_phase != FighterController.AttackPhase.NONE:
		return
	if _preferred_route == &"tai" and _bot.global_position.y > 470.0 and randf() < 0.16:
		_tap(&"jump", 0.12)
		_jump_cooldown = 0.78
		_intent = "TAI • SUBIR PARA ESPAÇO ABERTO"
	elif _preferred_route == &"fu" and absf(_opponent.global_position.y - _bot.global_position.y) > 115.0 and randf() < 0.11:
		_tap(&"jump", 0.12)
		_jump_cooldown = 0.72
		_intent = "FU • TROCAR DE NÍVEL"

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
	return lerpf(0.38, 0.17, perception_ratio) + randf_range(-0.02, 0.07)

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

func _register_toggle_action() -> void:
	if not InputMap.has_action(&"toggle_bot"):
		InputMap.add_action(&"toggle_bot")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_TAB
	for existing in InputMap.action_get_events(&"toggle_bot"):
		if existing is InputEventKey and existing.physical_keycode == KEY_TAB:
			return
	InputMap.action_add_event(&"toggle_bot", event)

func _create_status_label() -> void:
	_status_label = Label.new()
	_status_label.offset_left = 350.0
	_status_label.offset_top = 606.0
	_status_label.offset_right = 930.0
	_status_label.offset_bottom = 642.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0, 0.96))
	hud.add_child(_status_label)

func _update_status_label() -> void:
	if not is_instance_valid(_status_label):
		return
	if enabled:
		_status_label.text = "TAB: BOT P2 ATIVO • %s • ROTA %s" % [_intent, _preferred_route.to_upper()]
	else:
		_status_label.text = "TAB: P2 LOCAL • CONTROLES NUMÉRICOS LIBERADOS"
