class_name DojoSequenceRuntime
extends Node

const SAVE_PATH := "user://dojo_sequence.json"
const MAX_DURATION := 8.0
const SLOT_COUNT := 3
const LOOP_DELAY := 0.34
const ACTION_SUFFIXES: Array[StringName] = [
	&"left", &"right", &"down", &"jump", &"dodge", &"attack", &"push",
	&"grab", &"echo", &"block", &"element", &"swap"
]

@onready var dojo_runtime: DojoTrainingRuntime = get_node("../DojoTrainingRuntime")
@onready var hud: CanvasLayer = get_node("../HUD")

var _slots: Dictionary = {"1": [], "2": [], "3": []}
var _events: Array[Dictionary] = []
var _selected_slot := 1
var _loop_enabled := false
var _recording := false
var _playing := false
var _record_time := 0.0
var _play_time := 0.0
var _play_index := 0
var _loop_wait := 0.0
var _last_states: Dictionary = {}
var _status_label: Label
var _feedback := "SEM SEQUÊNCIA"

func _ready() -> void:
	_register_key_action(&"dojo_record_sequence", KEY_F12)
	_register_key_action(&"dojo_play_sequence", KEY_F5)
	_register_key_action(&"dojo_clear_sequence", KEY_F1)
	_register_key_action(&"dojo_previous_slot", KEY_BRACKETLEFT)
	_register_key_action(&"dojo_next_slot", KEY_BRACKETRIGHT)
	_register_key_action(&"dojo_toggle_loop", KEY_L)
	_create_status_label()
	_load_sequences()
	_load_selected_slot()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"dojo_record_sequence"):
		_toggle_recording()
	if Input.is_action_just_pressed(&"dojo_play_sequence"):
		_start_playback()
	if Input.is_action_just_pressed(&"dojo_clear_sequence"):
		_clear_selected_sequence()
	if Input.is_action_just_pressed(&"dojo_previous_slot"):
		_select_slot(-1)
	if Input.is_action_just_pressed(&"dojo_next_slot"):
		_select_slot(1)
	if Input.is_action_just_pressed(&"dojo_toggle_loop"):
		_toggle_loop()

	if not dojo_runtime.active:
		if _recording:
			_stop_recording("GRAVAÇÃO ENCERRADA AO SAIR DO DOJO")
		if _playing:
			_stop_playback("REPETIÇÃO ENCERRADA")
		_update_status_label()
		return

	if _recording:
		_capture_recording(delta)
	if _playing:
		_advance_playback(delta)
	_update_status_label()

func _toggle_recording() -> void:
	if not dojo_runtime.active:
		_feedback = "ATIVE O DOJO COM F8"
		return
	if _recording:
		_stop_recording("SEQUÊNCIA GRAVADA")
	else:
		_start_recording()

func _start_recording() -> void:
	_stop_playback("")
	_events.clear()
	_last_states.clear()
	_record_time = 0.0
	_recording = true
	for suffix in ACTION_SUFFIXES:
		var pressed := Input.is_action_pressed(_player_action(1, suffix))
		_last_states[String(suffix)] = pressed
		if pressed:
			_events.append({"time": 0.0, "action": String(suffix), "pressed": true})
	_feedback = "GRAVANDO P1 NO SLOT %d" % _selected_slot

func _capture_recording(delta: float) -> void:
	_record_time += delta
	for suffix in ACTION_SUFFIXES:
		var key := String(suffix)
		var pressed := Input.is_action_pressed(_player_action(1, suffix))
		var previous := bool(_last_states.get(key, false))
		if pressed == previous:
			continue
		_last_states[key] = pressed
		_events.append({"time": _record_time, "action": key, "pressed": pressed})
	if _record_time >= MAX_DURATION:
		_stop_recording("LIMITE DE 8 SEGUNDOS ALCANÇADO")

func _stop_recording(message: String) -> void:
	if not _recording:
		return
	_recording = false
	for suffix in ACTION_SUFFIXES:
		var key := String(suffix)
		if bool(_last_states.get(key, false)):
			_events.append({"time": _record_time, "action": key, "pressed": false})
	_last_states.clear()
	_sync_selected_slot()
	_save_sequences()
	if message != "":
		_feedback = "%s • SLOT %d • %d EVENTOS" % [message, _selected_slot, _events.size()]

func _start_playback() -> void:
	if not dojo_runtime.active:
		_feedback = "ATIVE O DOJO COM F8"
		return
	if _events.is_empty():
		_feedback = "SLOT %d ESTÁ VAZIO" % _selected_slot
		return
	if _recording:
		_stop_recording("SEQUÊNCIA GRAVADA")
	_stop_playback("")
	dojo_runtime.dummy_mode = &"passive"
	dojo_runtime._release_dummy_actions()
	_restart_playback_cycle()
	_playing = true
	_feedback = "REPRODUZINDO SLOT %d" % _selected_slot

func _restart_playback_cycle() -> void:
	_release_playback_actions()
	dojo_runtime._reset_training_state()
	_play_time = 0.0
	_play_index = 0
	_loop_wait = 0.0

func _advance_playback(delta: float) -> void:
	if _loop_wait > 0.0:
		_loop_wait = maxf(0.0, _loop_wait - delta)
		if _loop_wait <= 0.0:
			_restart_playback_cycle()
		return

	_play_time += delta
	while _play_index < _events.size():
		var event: Dictionary = _events[_play_index]
		if float(event.get("time", 0.0)) > _play_time:
			break
		var suffix := StringName(event.get("action", ""))
		if suffix in ACTION_SUFFIXES:
			var action_id := _player_action(2, suffix)
			if bool(event.get("pressed", false)):
				Input.action_press(action_id)
			else:
				Input.action_release(action_id)
		_play_index += 1

	if _play_index >= _events.size() and _play_time >= _sequence_duration() + 0.18:
		_release_playback_actions()
		if _loop_enabled:
			_loop_wait = LOOP_DELAY
			_feedback = "LOOP SLOT %d" % _selected_slot
		else:
			_stop_playback("REPETIÇÃO CONCLUÍDA")

func _stop_playback(message: String) -> void:
	if _playing or message != "":
		_release_playback_actions()
	_playing = false
	_play_time = 0.0
	_play_index = 0
	_loop_wait = 0.0
	if message != "":
		_feedback = message

func _select_slot(direction: int) -> void:
	if _recording or _playing:
		_feedback = "PARE A GRAVAÇÃO OU REPETIÇÃO PARA TROCAR"
		return
	_sync_selected_slot()
	_selected_slot += direction
	if _selected_slot < 1:
		_selected_slot = SLOT_COUNT
	elif _selected_slot > SLOT_COUNT:
		_selected_slot = 1
	_load_selected_slot()
	_save_sequences()
	_feedback = "SLOT %d SELECIONADO" % _selected_slot

func _toggle_loop() -> void:
	_loop_enabled = not _loop_enabled
	_save_sequences()
	_feedback = "LOOP %s" % ("ATIVO" if _loop_enabled else "DESATIVADO")

func _clear_selected_sequence() -> void:
	_stop_playback("")
	_recording = false
	_events.clear()
	_last_states.clear()
	_sync_selected_slot()
	_save_sequences()
	_feedback = "SLOT %d APAGADO" % _selected_slot

func _sync_selected_slot() -> void:
	_slots[String(_selected_slot)] = _events.duplicate(true)

func _load_selected_slot() -> void:
	_events.clear()
	var loaded: Variant = _slots.get(String(_selected_slot), [])
	if loaded is Array:
		for value in loaded:
			if value is Dictionary:
				_events.append((value as Dictionary).duplicate(true))
	_events.sort_custom(_sort_events)

func _release_playback_actions() -> void:
	for suffix in ACTION_SUFFIXES:
		Input.action_release(_player_action(2, suffix))

func _sequence_duration() -> float:
	if _events.is_empty():
		return 0.0
	return float(_events[_events.size() - 1].get("time", 0.0))

func _save_sequences() -> void:
	_sync_selected_slot()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_feedback = "FALHA AO SALVAR SEQUÊNCIAS"
		return
	file.store_string(JSON.stringify({
		"version": 2,
		"selected_slot": _selected_slot,
		"loop_enabled": _loop_enabled,
		"slots": _slots
	}, "\t"))

func _load_sequences() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed := JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return

	var version := int(parsed.get("version", 1))
	if version <= 1:
		_slots["1"] = _sanitize_events(parsed.get("events", []))
		_selected_slot = 1
		_loop_enabled = false
		_feedback = "SEQUÊNCIA ANTIGA MIGRADA PARA O SLOT 1"
		return

	_selected_slot = clampi(int(parsed.get("selected_slot", 1)), 1, SLOT_COUNT)
	_loop_enabled = bool(parsed.get("loop_enabled", false))
	var loaded_slots: Variant = parsed.get("slots", {})
	if loaded_slots is Dictionary:
		for slot_id in range(1, SLOT_COUNT + 1):
			_slots[String(slot_id)] = _sanitize_events(loaded_slots.get(String(slot_id), []))
	_feedback = "3 SLOTS CARREGADOS"

func _sanitize_events(source: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if not (source is Array):
		return sanitized
	for value in source:
		if not (value is Dictionary):
			continue
		var event: Dictionary = value
		var suffix := StringName(event.get("action", ""))
		if suffix not in ACTION_SUFFIXES:
			continue
		sanitized.append({
			"time": clampf(float(event.get("time", 0.0)), 0.0, MAX_DURATION),
			"action": String(suffix),
			"pressed": bool(event.get("pressed", false))
		})
	sanitized.sort_custom(_sort_events)
	return sanitized

func _sort_events(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("time", 0.0)) < float(b.get("time", 0.0))

func _player_action(player_index: int, suffix: StringName) -> StringName:
	return StringName("p%d_%s" % [player_index, String(suffix)])

func _create_status_label() -> void:
	_status_label = Label.new()
	_status_label.offset_left = 20.0
	_status_label.offset_top = 278.0
	_status_label.offset_right = 365.0
	_status_label.offset_bottom = 382.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 0.96))
	hud.add_child(_status_label)

func _update_status_label() -> void:
	if not is_instance_valid(_status_label):
		return
	var mode := "PRONTO"
	if _recording:
		mode = "GRAVANDO %.1fs" % _record_time
	elif _playing and _loop_wait > 0.0:
		mode = "AGUARDANDO LOOP"
	elif _playing:
		mode = "REPRODUZINDO %.1fs" % _play_time
	_status_label.text = "SEQUÊNCIAS DO DOJO • SLOT %d/3 • LOOP %s\n[ / ] TROCA • L LOOP • F12 GRAVA\nF5 REPETE • F1 APAGA\n%s • %.2fs • %d EVENTOS\n%s" % [
		_selected_slot,
		"ON" if _loop_enabled else "OFF",
		mode,
		_sequence_duration(),
		_events.size(),
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
	if _recording:
		_stop_recording("")
	_stop_playback("")
	_save_sequences()
