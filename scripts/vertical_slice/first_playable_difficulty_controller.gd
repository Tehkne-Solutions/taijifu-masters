class_name FirstPlayableDifficultyController
extends Node

signal difficulty_changed(difficulty_id: StringName, label: String)

const FIRST_PLAYABLE_DIFFICULTIES: Array[StringName] = [&"apprentice", &"disciple", &"master"]

@onready var bot: TacticalBotRuntime = get_node("../TacticalBotRuntime")
@onready var difficulty_label: Label = get_node("../HUD/DifficultyInfo")

var selected_difficulty_id: StringName = &"disciple"

func _ready() -> void:
	_register_key_action(&"first_playable_ai_easy", KEY_1)
	_register_key_action(&"first_playable_ai_normal", KEY_2)
	_register_key_action(&"first_playable_ai_hard", KEY_3)
	_apply_selected_difficulty()
	call_deferred("_hide_bot_debug_status")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"first_playable_ai_easy"):
		set_difficulty(&"apprentice")
	elif Input.is_action_just_pressed(&"first_playable_ai_normal"):
		set_difficulty(&"disciple")
	elif Input.is_action_just_pressed(&"first_playable_ai_hard"):
		set_difficulty(&"master")
	# O controlador da partida pode desabilitar o bot durante countdown/result,
	# mas não deve sobrescrever a dificuldade escolhida para a próxima revanche.
	_apply_selected_difficulty()
	_update_label()
	_hide_bot_debug_status()

func set_difficulty(difficulty_id: StringName) -> void:
	if difficulty_id not in FIRST_PLAYABLE_DIFFICULTIES:
		return
	if selected_difficulty_id == difficulty_id:
		_apply_selected_difficulty()
		_update_label()
		return
	selected_difficulty_id = difficulty_id
	_apply_selected_difficulty()
	_update_label()
	difficulty_changed.emit(selected_difficulty_id, current_label())

func current_label() -> String:
	return BotBehaviorCatalog.difficulty_label(selected_difficulty_id)

func selection_signature() -> Dictionary:
	return {
		"difficulty_ids": FIRST_PLAYABLE_DIFFICULTIES.duplicate(),
		"default_id": &"disciple",
		"selected_id": selected_difficulty_id,
		"keys": {&"apprentice": "1", &"disciple": "2", &"master": "3"},
		"persists_across_rematch": true
	}

func _apply_selected_difficulty() -> void:
	if is_instance_valid(bot):
		bot.difficulty_id = selected_difficulty_id

func _update_label() -> void:
	if not is_instance_valid(difficulty_label):
		return
	difficulty_label.text = "IA %s  •  [1] APRENDIZ  [2] DISCÍPULO  [3] MESTRE" % current_label()

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
