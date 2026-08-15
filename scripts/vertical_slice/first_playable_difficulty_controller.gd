class_name FirstPlayableDifficultyController
extends Node

signal difficulty_changed(difficulty_id: StringName, label: String)

const FIRST_PLAYABLE_DIFFICULTIES: Array[StringName] = [&"apprentice", &"disciple", &"master"]
const DIFFICULTY_LABELS: Array[String] = ["APRENDIZ", "DISCÍPULO", "ADEPTO", "MESTRE"]
const MASTER_MARTIAL_PERSONALITY: StringName = &"master_martial"
const CANONICAL_ARENA_LABEL := "MOUNTAIN DOJO NIGHT"

@onready var bot: TacticalBotRuntime = get_node("../TacticalBotRuntime")
@onready var difficulty_label: Label = get_node("../HUD/DifficultyInfo")
@onready var state_label: Label = get_node("../HUD/StateInfo")
@onready var center_label: Label = get_node("../HUD/CenterInfo")
@onready var controls_label: Label = get_node("../HUD/Controls")

var selected_difficulty_id: StringName = &"disciple"

func _ready() -> void:
	selected_difficulty_id = (
		FirstPlayableSession.pilot_required_difficulty()
		if FirstPlayableSession.pilot_sequence_locked()
		else FirstPlayableSession.selected_difficulty_id
	)
	FirstPlayableSession.selected_difficulty_id = selected_difficulty_id
	_register_key_action(&"first_playable_ai_easy", KEY_1)
	_register_key_action(&"first_playable_ai_normal", KEY_2)
	_register_key_action(&"first_playable_ai_hard", KEY_3)
	_apply_selected_difficulty()
	_update_labels()
	call_deferred("_hide_bot_debug_status")

func _process(_delta: float) -> void:
	if FirstPlayableSession.pilot_sequence_locked():
		var required := FirstPlayableSession.pilot_required_difficulty()
		if selected_difficulty_id != required:
			selected_difficulty_id = required
			FirstPlayableSession.selected_difficulty_id = required
			difficulty_changed.emit(selected_difficulty_id, current_label())
	else:
		if Input.is_action_just_pressed(&"first_playable_ai_easy"):
			set_difficulty(&"apprentice")
		elif Input.is_action_just_pressed(&"first_playable_ai_normal"):
			set_difficulty(&"disciple")
		elif Input.is_action_just_pressed(&"first_playable_ai_hard"):
			set_difficulty(&"master")
	# O controlador da partida pode desabilitar o bot durante countdown/result,
	# mas não deve sobrescrever a dificuldade escolhida para a próxima revanche.
	_apply_selected_difficulty()
	_update_labels()
	_hide_bot_debug_status()

func set_difficulty(difficulty_id: StringName) -> void:
	if FirstPlayableSession.pilot_sequence_locked():
		var required := FirstPlayableSession.pilot_required_difficulty()
		selected_difficulty_id = required
		FirstPlayableSession.selected_difficulty_id = required
		_apply_selected_difficulty()
		_update_labels()
		return
	if difficulty_id not in FIRST_PLAYABLE_DIFFICULTIES:
		return
	FirstPlayableSession.set_difficulty(difficulty_id)
	if selected_difficulty_id == difficulty_id:
		_apply_selected_difficulty()
		_update_labels()
		return
	selected_difficulty_id = difficulty_id
	_apply_selected_difficulty()
	_update_labels()
	difficulty_changed.emit(selected_difficulty_id, current_label())

func current_label() -> String:
	return BotBehaviorCatalog.difficulty_label(selected_difficulty_id)

func selection_signature() -> Dictionary:
	return {
		"difficulty_ids": FIRST_PLAYABLE_DIFFICULTIES.duplicate(),
		"default_id": &"disciple",
		"selected_id": selected_difficulty_id,
		"keys": {&"apprentice": "1", &"disciple": "2", &"master": "3"},
		"master_personality": MASTER_MARTIAL_PERSONALITY,
		"master_dedicated_push": false,
		"master_direct_element": false,
		"persists_across_rematch": true,
		"persists_from_menu": true,
		"pilot_sequence_locked": FirstPlayableSession.pilot_sequence_locked(),
		"pilot_required_difficulty": String(FirstPlayableSession.pilot_required_difficulty()),
		"pilot_round_number": FirstPlayableSession.pilot_round_number(),
		"pilot_expected_matches": FirstPlayableSession.pilot_expected_matches(),
		"signature": "Tehkné Solutions",
	}

func _apply_selected_difficulty() -> void:
	if not is_instance_valid(bot):
		return
	bot.difficulty_id = selected_difficulty_id
	if selected_difficulty_id == &"master":
		bot.personality_id = MASTER_MARTIAL_PERSONALITY
	elif bot.personality_id == MASTER_MARTIAL_PERSONALITY:
		bot.personality_id = &"technical"

func _update_labels() -> void:
	var pilot_locked := FirstPlayableSession.pilot_sequence_locked()
	if is_instance_valid(difficulty_label):
		if pilot_locked:
			difficulty_label.text = "PILOTO %d/%d  •  IA %s" % [
				FirstPlayableSession.pilot_round_number(),
				FirstPlayableSession.pilot_expected_matches(),
				current_label(),
			]
		else:
			difficulty_label.text = "IA %s  •  [1] APRENDIZ  [2] DISCÍPULO  [3] MESTRE" % current_label()
	if is_instance_valid(controls_label) and pilot_locked:
		controls_label.text = controls_label.text.replace(" • 1/2/3 dificuldade", "")
	if is_instance_valid(center_label) and center_label.text == "RUÍNAS DO CAMINHO TRIPLO":
		center_label.text = CANONICAL_ARENA_LABEL
	if not is_instance_valid(state_label):
		return
	var updated := state_label.text
	for old_label in DIFFICULTY_LABELS:
		updated = updated.replace("IA %s" % old_label, "IA %s" % current_label())
	state_label.text = updated

func _hide_bot_debug_status() -> void:
	if is_instance_valid(bot) and is_instance_valid(bot._status_label):
		bot._status_label.visible = false

func _register_key_action(action_id: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == physical_keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_id, event)

# Tehkné Solutions
