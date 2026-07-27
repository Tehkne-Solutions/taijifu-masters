class_name CompetitiveMatchRuntime
extends Node

signal round_timeout(winner_index: int, reason: String)

const SAVE_PATH := "user://competitive_match.json"
const SUDDEN_DEATH_SECONDS := 15.0

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")

var _config: Dictionary = CompetitiveMatchCatalog.default_config()
var _field_index := 0
var _series_active := false
var _round_active := false
var _scores: Array[int] = [0, 0]
var _round_number := 1
var _time_remaining := 0.0
var _sudden_death := false
var _player_one: FighterController
var _player_two: FighterController
var _player_names: Array[String] = ["P1", "P2"]
var _setup_layer: CanvasLayer
var _setup_panel: PanelContainer
var _setup_label: Label
var _score_layer: CanvasLayer
var _score_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	_load_config()
	_build_setup_panel()
	_build_scoreboard()
	_refresh_setup()
	_refresh_scoreboard()

func _process(delta: float) -> void:
	var preparing := is_instance_valid(preparation_runtime) and preparation_runtime.is_active()
	_setup_layer.visible = preparing
	if preparing:
		_process_setup_inputs()
	if not _round_active:
		return
	var limit := CompetitiveMatchCatalog.round_seconds(_config)
	if limit <= 0.0:
		return
	_time_remaining = maxf(0.0, _time_remaining - delta)
	_refresh_scoreboard()
	if _time_remaining > 0.0:
		return
	_resolve_time_limit()

func current_config() -> Dictionary:
	return CompetitiveMatchCatalog.sanitize(_config)

func resolved_arena_rules() -> Dictionary:
	return CompetitiveMatchCatalog.resolved_arena_rules(_config)

func arena_title() -> String:
	return CompetitiveMatchCatalog.arena_label(_config)

func set_config_for_test(config: Dictionary) -> void:
	_config = CompetitiveMatchCatalog.sanitize(config)
	_save_config()
	_refresh_setup()
	_refresh_scoreboard()

func begin_series(player_one_loadout: Dictionary, player_two_loadout: Dictionary) -> void:
	_scores = [0, 0]
	_round_number = 1
	_series_active = true
	_round_active = false
	_sudden_death = false
	_player_names[0] = _character_name(player_one_loadout, "P1")
	_player_names[1] = _character_name(player_two_loadout, "P2")
	_save_config()
	_refresh_scoreboard()

func start_round(player_one: FighterController, player_two: FighterController) -> void:
	_player_one = player_one
	_player_two = player_two
	_round_active = true
	_sudden_death = false
	_time_remaining = CompetitiveMatchCatalog.round_seconds(_config)
	_refresh_scoreboard()

func stop_round() -> void:
	_round_active = false
	_refresh_scoreboard()

func record_round(winner_index: int, reason: String = "KO") -> Dictionary:
	_round_active = false
	var clean_winner := clampi(winner_index, 1, 2)
	_scores[clean_winner - 1] += 1
	var target := CompetitiveMatchCatalog.target_wins(_config)
	var match_over := _scores[clean_winner - 1] >= target
	var completed_round := _round_number
	if not match_over:
		_round_number += 1
	_save_config()
	_refresh_scoreboard()
	return {
		"winner_index": clean_winner,
		"winner_name": _player_names[clean_winner - 1],
		"reason": reason,
		"round_number": completed_round,
		"match_over": match_over,
		"target_wins": target,
		"score_p1": _scores[0],
		"score_p2": _scores[1]
	}

func reset_series() -> void:
	_series_active = false
	_round_active = false
	_scores = [0, 0]
	_round_number = 1
	_sudden_death = false
	_player_one = null
	_player_two = null
	_refresh_scoreboard()

func score_snapshot() -> Dictionary:
	return {
		"series_active": _series_active,
		"round_active": _round_active,
		"round_number": _round_number,
		"score_p1": _scores[0],
		"score_p2": _scores[1],
		"target_wins": CompetitiveMatchCatalog.target_wins(_config),
		"time_remaining": _time_remaining,
		"sudden_death": _sudden_death
	}

func _process_setup_inputs() -> void:
	if Input.is_action_just_pressed(&"match_prev_field"):
		_field_index = wrapi(_field_index - 1, 0, CompetitiveMatchCatalog.FIELD_ORDER.size())
		_refresh_setup()
	elif Input.is_action_just_pressed(&"match_next_field"):
		_field_index = wrapi(_field_index + 1, 0, CompetitiveMatchCatalog.FIELD_ORDER.size())
		_refresh_setup()
	if Input.is_action_just_pressed(&"match_prev_value"):
		_cycle_value(-1)
	elif Input.is_action_just_pressed(&"match_next_value"):
		_cycle_value(1)

func _cycle_value(direction: int) -> void:
	var field_id := CompetitiveMatchCatalog.FIELD_ORDER[_field_index]
	var options := CompetitiveMatchCatalog.options_for(field_id)
	if options.is_empty():
		return
	var current := StringName(_config.get(String(field_id), options[0]))
	var index := options.find(current)
	if index < 0:
		index = 0
	_config[String(field_id)] = options[wrapi(index + direction, 0, options.size())]
	_config = CompetitiveMatchCatalog.sanitize(_config)
	_save_config()
	_refresh_setup()
	_refresh_scoreboard()

func _resolve_time_limit() -> void:
	if not is_instance_valid(_player_one) or not is_instance_valid(_player_two):
		_round_active = false
		return
	var comparison := _compare_fighters(_player_one, _player_two)
	if comparison == 0:
		_sudden_death = true
		_time_remaining = SUDDEN_DEATH_SECONDS
		_refresh_scoreboard()
		return
	_round_active = false
	round_timeout.emit(comparison, "TEMPO")

func _compare_fighters(player_one: FighterController, player_two: FighterController) -> int:
	var p1_health := player_one.health / maxf(1.0, player_one.build.max_health())
	var p2_health := player_two.health / maxf(1.0, player_two.build.max_health())
	if absf(p1_health - p2_health) > 0.001:
		return 1 if p1_health > p2_health else 2
	var p1_posture := player_one.posture / maxf(1.0, player_one.build.max_posture())
	var p2_posture := player_two.posture / maxf(1.0, player_two.build.max_posture())
	if absf(p1_posture - p2_posture) > 0.001:
		return 1 if p1_posture > p2_posture else 2
	if absf(player_one.stamina - player_two.stamina) > 0.01:
		return 1 if player_one.stamina > player_two.stamina else 2
	return 0

func _character_name(loadout: Dictionary, fallback: String) -> String:
	var preset_id := StringName(loadout.get("preset_id", &"adaptive_staff"))
	var build := BuildProfile.prototype_preset(preset_id)
	return build.character_name.to_upper() if build.character_name.strip_edges() != "" else fallback

func _build_setup_panel() -> void:
	_setup_layer = CanvasLayer.new()
	_setup_layer.layer = 214
	_setup_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_setup_layer)
	_setup_panel = PanelContainer.new()
	_setup_panel.offset_left = 340.0
	_setup_panel.offset_top = 82.0
	_setup_panel.offset_right = 940.0
	_setup_panel.offset_bottom = 166.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.038, 0.065, 0.97)
	style.border_color = Color(0.92, 0.72, 0.28, 0.90)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	_setup_panel.add_theme_stylebox_override("panel", style)
	_setup_layer.add_child(_setup_panel)
	_setup_label = Label.new()
	_setup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_setup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_setup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_setup_label.add_theme_font_size_override("font_size", 12)
	_setup_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	_setup_panel.add_child(_setup_label)

func _build_scoreboard() -> void:
	_score_layer = CanvasLayer.new()
	_score_layer.layer = 36
	add_child(_score_layer)
	_score_label = Label.new()
	_score_label.offset_left = 405.0
	_score_label.offset_top = 170.0
	_score_label.offset_right = 875.0
	_score_label.offset_bottom = 218.0
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 15)
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	_score_layer.add_child(_score_label)

func _refresh_setup() -> void:
	if not is_instance_valid(_setup_label):
		return
	var field_id := CompetitiveMatchCatalog.FIELD_ORDER[_field_index]
	var lines: Array[String] = []
	for candidate in CompetitiveMatchCatalog.FIELD_ORDER:
		var prefix := "▶ " if candidate == field_id else "   "
		lines.append("%s%s: %s" % [
			prefix,
			CompetitiveMatchCatalog.field_label(candidate),
			CompetitiveMatchCatalog.value_label(candidate, StringName(_config.get(String(candidate), &"")))
		])
	_setup_label.text = "CONFIGURAÇÃO DA PARTIDA  •  Q/E categoria  •  Z/X opção\n%s" % "    |    ".join(lines)

func _refresh_scoreboard() -> void:
	if not is_instance_valid(_score_label):
		return
	_score_layer.visible = _series_active
	if not _series_active:
		_score_label.text = ""
		return
	var time_label := "∞"
	var limit := CompetitiveMatchCatalog.round_seconds(_config)
	if limit > 0.0:
		time_label = "%02d" % ceili(_time_remaining)
	if _sudden_death:
		time_label = "PRORROGAÇÃO %02d" % ceili(_time_remaining)
	_score_label.text = "ROUND %d  •  %s %d — %d %s  •  %s  •  %s" % [
		_round_number,
		_player_names[0], _scores[0], _scores[1], _player_names[1],
		time_label,
		CompetitiveMatchCatalog.value_label(&"series_id", StringName(_config["series_id"]))
	]

func _register_inputs() -> void:
	_add_key_action(&"match_prev_field", KEY_Q)
	_add_key_action(&"match_next_field", KEY_E)
	_add_key_action(&"match_prev_value", KEY_Z)
	_add_key_action(&"match_next_value", KEY_X)
	_add_joy_button(&"match_prev_field", JOY_BUTTON_LEFT_SHOULDER, 0)
	_add_joy_button(&"match_next_field", JOY_BUTTON_RIGHT_SHOULDER, 0)
	_add_joy_axis(&"match_prev_value", JOY_AXIS_TRIGGER_LEFT, 1.0, 0)
	_add_joy_axis(&"match_next_value", JOY_AXIS_TRIGGER_RIGHT, 1.0, 0)

func _add_key_action(action_id: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_id, event)

func _add_joy_button(action_id: StringName, button_index: JoyButton, device: int) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventJoypadButton and existing.button_index == button_index and existing.device == device:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.device = device
	InputMap.action_add_event(action_id, event)

func _add_joy_axis(action_id: StringName, axis: JoyAxis, axis_value: float, device: int) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventJoypadMotion and existing.axis == axis and is_equal_approx(existing.axis_value, axis_value) and existing.device == device:
			return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	event.device = device
	InputMap.action_add_event(action_id, event)

func _save_config() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"config": CompetitiveMatchCatalog.sanitize(_config),
		"scores": _scores,
		"round_number": _round_number
	}, "\t"))

func _load_config() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var root: Dictionary = parsed
	var loaded: Variant = root.get("config", {})
	if loaded is Dictionary:
		_config = CompetitiveMatchCatalog.sanitize(loaded)
