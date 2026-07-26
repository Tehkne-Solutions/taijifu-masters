class_name DojoTrainingRuntime
extends Node

const DUMMY_MODES: Array[StringName] = [&"passive", &"guard", &"parry", &"evade", &"counter"]
const RESOURCE_MODES: Array[StringName] = [&"standard", &"recovery", &"infinite"]
const MODE_LABELS := {
	&"passive": "PASSIVO",
	&"guard": "DEFESA CONTÍNUA",
	&"parry": "TENTATIVA DE APARO",
	&"evade": "ESQUIVA REATIVA",
	&"counter": "CONTRA-ATAQUE"
}
const RESOURCE_LABELS := {
	&"standard": "RECURSOS NORMAIS",
	&"recovery": "FÔLEGO/POSTURA RESTAURADOS",
	&"infinite": "RECURSOS DE TREINO"
}

@onready var arena: TriplePathArena = get_node("../Arena")
@onready var bot_runtime: TacticalBotRuntime = get_node("../TacticalBotRuntime")
@onready var hud: CanvasLayer = get_node("../HUD")

var active := false
var dummy_mode: StringName = &"passive"
var resource_mode: StringName = &"recovery"
var _player_one: FighterController
var _dummy: FighterController
var _previous_bot_enabled := true
var _status_label: Label
var _feedback := ""
var _reaction_cooldown := 0.0
var _tap_timers: Dictionary = {}

func _ready() -> void:
	_register_key_action(&"dojo_toggle", KEY_F8)
	_register_key_action(&"dojo_dummy_mode", KEY_F9)
	_register_key_action(&"dojo_resource_mode", KEY_F10)
	_register_key_action(&"dojo_reset", KEY_F11)
	_create_status_label()

func _process(delta: float) -> void:
	_discover_fighters()
	_update_taps(delta)
	_reaction_cooldown = maxf(0.0, _reaction_cooldown - delta)

	if Input.is_action_just_pressed(&"dojo_toggle"):
		_toggle_dojo()
	if Input.is_action_just_pressed(&"dojo_dummy_mode"):
		dummy_mode = DUMMY_MODES[wrapi(DUMMY_MODES.find(dummy_mode) + 1, 0, DUMMY_MODES.size())]
		_release_dummy_actions()
		_feedback = "COMPORTAMENTO ALTERADO"
	if Input.is_action_just_pressed(&"dojo_resource_mode"):
		resource_mode = RESOURCE_MODES[wrapi(RESOURCE_MODES.find(resource_mode) + 1, 0, RESOURCE_MODES.size())]
		_feedback = "PERFIL DE RECURSOS ALTERADO"
	if Input.is_action_just_pressed(&"dojo_reset") and active:
		_reset_training_state()

	if active:
		_enforce_training_arena()
		_apply_resource_profile()
		_drive_dummy()
	_update_status_label()

func _discover_fighters() -> void:
	if is_instance_valid(_player_one) and is_instance_valid(_dummy):
		return
	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is FighterController):
			continue
		var fighter := node as FighterController
		if fighter.player_index == 1:
			_player_one = fighter
		elif fighter.player_index == 2:
			_dummy = fighter

func _toggle_dojo() -> void:
	if active:
		_exit_dojo()
	else:
		_enter_dojo()

func _enter_dojo() -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_dummy):
		_feedback = "INICIE UMA BATALHA ANTES DE ABRIR O DOJO"
		return
	active = true
	_previous_bot_enabled = bot_runtime.enabled
	bot_runtime.enabled = false
	_release_dummy_actions()
	_reset_training_state()
	_feedback = "DOJO TÉCNICO ATIVO"

func _exit_dojo() -> void:
	active = false
	_release_dummy_actions()
	bot_runtime.enabled = _previous_bot_enabled
	arena.start_battle_flow()
	_feedback = "RETORNO À ARENA"

func _enforce_training_arena() -> void:
	arena._battle_active = false
	arena._closure_stage = 0
	arena._left_boundary = -180.0
	arena._active_manifestation = -1
	arena._manifestation_timer = 0.0
	arena.queue_redraw()
	for fighter in [_player_one, _dummy]:
		if is_instance_valid(fighter) and fighter.global_position.y > 900.0:
			_reset_training_state()
			break

func _reset_training_state() -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_dummy):
		return
	_player_one.reset_fighter(Vector2(1040.0, 665.0))
	_dummy.reset_fighter(Vector2(1440.0, 665.0))
	_player_one.facing = 1.0
	_dummy.facing = -1.0
	_release_dummy_actions()
	_feedback = "POSIÇÕES E RECURSOS REINICIADOS"

func _apply_resource_profile() -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_dummy):
		return
	match resource_mode:
		&"recovery":
			for fighter in [_player_one, _dummy]:
				fighter.stamina = 100.0
				fighter.posture = fighter.build.max_posture()
				fighter.health = maxf(fighter.health, fighter.build.max_health() * 0.45)
		&"infinite":
			for fighter in [_player_one, _dummy]:
				fighter.health = fighter.build.max_health()
				fighter.posture = fighter.build.max_posture()
				fighter.stamina = 100.0
				fighter.disarm_pressure = 0.0
		_:
			pass

func _drive_dummy() -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_dummy):
		return
	_release_continuous_actions()
	var distance := _player_one.global_position.distance_to(_dummy.global_position)
	var incoming := _player_one._attack_phase in [FighterController.AttackPhase.STARTUP, FighterController.AttackPhase.ACTIVE]

	match dummy_mode:
		&"guard":
			Input.action_press(&"p2_block")
		&"parry":
			if incoming and distance < 205.0 and _reaction_cooldown <= 0.0:
				_tap_action(&"p2_block", 0.11)
				_reaction_cooldown = 0.32
		&"evade":
			if incoming and distance < 225.0 and _reaction_cooldown <= 0.0:
				_tap_action(&"p2_dodge", 0.10)
				_reaction_cooldown = 0.48
		&"counter":
			if incoming:
				Input.action_press(&"p2_block")
			elif _player_one._attack_phase == FighterController.AttackPhase.RECOVERY and distance < 190.0 and _reaction_cooldown <= 0.0:
				_tap_action(&"p2_attack", 0.10)
				_reaction_cooldown = 0.42
		_:
			pass

func _release_continuous_actions() -> void:
	for action_id in [&"p2_left", &"p2_right", &"p2_down", &"p2_jump", &"p2_block"]:
		if not _tap_timers.has(action_id):
			Input.action_release(action_id)

func _tap_action(action_id: StringName, duration: float) -> void:
	Input.action_press(action_id)
	_tap_timers[action_id] = duration

func _update_taps(delta: float) -> void:
	for action_variant in _tap_timers.keys():
		var action_id := StringName(action_variant)
		var remaining := float(_tap_timers[action_variant]) - delta
		if remaining <= 0.0:
			Input.action_release(action_id)
			_tap_timers.erase(action_variant)
		else:
			_tap_timers[action_variant] = remaining

func _release_dummy_actions() -> void:
	for action_id in [
		&"p2_left", &"p2_right", &"p2_down", &"p2_jump", &"p2_dodge",
		&"p2_attack", &"p2_push", &"p2_block", &"p2_grab", &"p2_echo",
		&"p2_element", &"p2_swap"
	]:
		Input.action_release(action_id)
	_tap_timers.clear()

func _create_status_label() -> void:
	_status_label = Label.new()
	_status_label.offset_left = 915.0
	_status_label.offset_top = 278.0
	_status_label.offset_right = 1265.0
	_status_label.offset_bottom = 380.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.52, 0.94, 0.72, 0.96))
	hud.add_child(_status_label)

func _update_status_label() -> void:
	if not is_instance_valid(_status_label):
		return
	var state_label := "ATIVO" if active else "INATIVO"
	_status_label.text = "DOJO F8 • %s\nF9 %s\nF10 %s\nF11 REINICIA\n%s" % [
		state_label,
		MODE_LABELS.get(dummy_mode, "PASSIVO"),
		RESOURCE_LABELS.get(resource_mode, "NORMAL"),
		_feedback
	]

func _register_key_action(action_id: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == physical_keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_id, event)

func _exit_tree() -> void:
	_release_dummy_actions()
