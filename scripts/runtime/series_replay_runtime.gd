class_name SeriesReplayRuntime
extends Node

signal replay_finished

const CARD_SECONDS := 1.05
const MAX_HIGHLIGHTS_PER_ROUND := 6

var _active := false
var _cards: Array[Dictionary] = []
var _card_index := 0
var _token := 0
var _canvas: CanvasLayer
var _background: ColorRect
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _body: RichTextLabel
var _progress: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	_build_interface()

func _process(_delta: float) -> void:
	if not _active:
		return
	if Input.is_action_just_pressed(&"replay_next"):
		_show_next_card(_token)
	elif Input.is_action_just_pressed(&"replay_close"):
		_finish(_token)

func play(record: Dictionary) -> void:
	_token += 1
	var token := _token
	_cards = build_cards(record)
	_card_index = 0
	_active = true
	_canvas.visible = true
	if _cards.is_empty():
		_finish(token)
		return
	_show_card(_cards[0])
	var running_headless := DisplayServer.get_name() == "headless" or OS.has_feature("server")
	if running_headless:
		call_deferred("_finish", token)
		return
	_run_auto_sequence(token)

func is_active() -> bool:
	return _active

func skip_for_test() -> void:
	if _active:
		_finish(_token)

func build_cards(record: Dictionary) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var players := _player_names(record)
	var config: Dictionary = record.get("config", {})
	cards.append({
		"title": "REPLAY RESUMIDO",
		"subtitle": "%s VS %s" % [players[0], players[1]],
		"body": "[center]%s\n[font_size=23][b]%d — %d[/b][/font_size][/center]" % [
			CompetitiveMatchCatalog.config_summary(config),
			int(record.get("score_p1", 0)), int(record.get("score_p2", 0))
		]
	})
	for round_value in record.get("rounds", []):
		if not (round_value is Dictionary):
			continue
		var round_data: Dictionary = round_value
		cards.append(_round_card(round_data, players))
	var winner_index := clampi(int(record.get("winner_index", 1)), 1, 2)
	cards.append({
		"title": "DESFECHO DA SÉRIE",
		"subtitle": "%s É O VENCEDOR" % players[winner_index - 1],
		"body": _series_summary(record, players)
	})
	return cards

func _round_card(round_data: Dictionary, players: Array[String]) -> Dictionary:
	var round_number := int(round_data.get("round_number", 1))
	var winner_index := clampi(int(round_data.get("winner_index", 1)), 1, 2)
	var highlights: Array = round_data.get("highlights", [])
	var lines: Array[String] = []
	if highlights.is_empty():
		lines.append("[color=#8b99ad]Nenhum momento especial foi registrado; o resumo estatístico foi preservado.[/color]")
	else:
		var limit := mini(MAX_HIGHLIGHTS_PER_ROUND, highlights.size())
		for index in range(limit):
			if not (highlights[index] is Dictionary):
				continue
			var highlight: Dictionary = highlights[index]
			var player_index := clampi(int(highlight.get("player_index", 1)), 1, 2)
			var time_seconds := float(highlight.get("time_seconds", 0.0))
			var label := String(highlight.get("label", "Momento decisivo"))
			lines.append("[color=#8ecff0]%05.1fs[/color]  [b]%s[/b] — %s" % [time_seconds, players[player_index - 1], label])
	var resources: Array = round_data.get("resources", [])
	if resources.size() >= 2:
		var p1: Dictionary = resources[0] if resources[0] is Dictionary else {}
		var p2: Dictionary = resources[1] if resources[1] is Dictionary else {}
		lines.append("\nVida restante: %s %.0f%% • %s %.0f%%" % [
			players[0], float(p1.get("health_ratio", 0.0)) * 100.0,
			players[1], float(p2.get("health_ratio", 0.0)) * 100.0
		])
	return {
		"title": "ROUND %d" % round_number,
		"subtitle": "%s VENCE • %s • %.1fs" % [
			players[winner_index - 1], String(round_data.get("reason", "KO")),
			float(round_data.get("duration_seconds", 0.0))
		],
		"body": "\n".join(lines)
	}

func _series_summary(record: Dictionary, players: Array[String]) -> String:
	var totals: Array = record.get("totals", [])
	var p1: Dictionary = totals[0] if totals.size() > 0 and totals[0] is Dictionary else {}
	var p2: Dictionary = totals[1] if totals.size() > 1 and totals[1] is Dictionary else {}
	return "[table=3][cell][b]MÉTRICA[/b][/cell][cell][b]%s[/b][/cell][cell][b]%s[/b][/cell]" % [players[0], players[1]] + \
		"[cell]Dano[/cell][cell]%.0f[/cell][cell]%.0f[/cell]" % [float(p1.get("damage_dealt", 0.0)), float(p2.get("damage_dealt", 0.0))] + \
		"[cell]Aparos[/cell][cell]%d[/cell][cell]%d[/cell]" % [int(p1.get("parries", 0)), int(p2.get("parries", 0))] + \
		"[cell]Quebras de postura[/cell][cell]%d[/cell][cell]%d[/cell]" % [int(p1.get("posture_breaks", 0)), int(p2.get("posture_breaks", 0))] + \
		"[cell]Desarmes[/cell][cell]%d[/cell][cell]%d[/cell][/table]" % [int(p1.get("disarms", 0)), int(p2.get("disarms", 0))]

func _player_names(record: Dictionary) -> Array[String]:
	var names: Array[String] = ["P1", "P2"]
	var players: Array = record.get("players", [])
	for index in range(mini(2, players.size())):
		if players[index] is Dictionary:
			names[index] = String((players[index] as Dictionary).get("character_name", names[index])).to_upper()
	return names

func _run_auto_sequence(token: int) -> void:
	while _active and token == _token:
		await get_tree().create_timer(CARD_SECONDS, true, false, true).timeout
		if not _active or token != _token:
			return
		_show_next_card(token)

func _show_next_card(token: int) -> void:
	if token != _token or not _active:
		return
	_card_index += 1
	if _card_index >= _cards.size():
		_finish(token)
		return
	_show_card(_cards[_card_index])

func _show_card(card: Dictionary) -> void:
	_title.text = String(card.get("title", "REPLAY"))
	_subtitle.text = String(card.get("subtitle", ""))
	_body.text = String(card.get("body", ""))
	_progress.text = "%d / %d  •  ESPAÇO avança  •  ESC fecha" % [_card_index + 1, _cards.size()]

func _finish(token: int) -> void:
	if token != _token:
		return
	_active = false
	_canvas.visible = false
	replay_finished.emit()

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 246
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0.004, 0.008, 0.016, 0.965)
	_canvas.add_child(_background)
	_panel = PanelContainer.new()
	_panel.offset_left = 160.0
	_panel.offset_top = 82.0
	_panel.offset_right = 1120.0
	_panel.offset_bottom = 638.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.026, 0.046, 0.99)
	style.border_color = Color(0.92, 0.66, 0.26, 0.94)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	_panel.add_theme_stylebox_override("panel", style)
	_background.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.38))
	column.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.add_theme_color_override("font_color", Color(0.72, 0.90, 1.0))
	column.add_child(_subtitle)
	_body = RichTextLabel.new()
	_body.custom_minimum_size = Vector2(880.0, 360.0)
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.scroll_active = false
	_body.add_theme_font_size_override("normal_font_size", 17)
	_body.add_theme_font_size_override("bold_font_size", 18)
	column.add_child(_body)
	_progress = Label.new()
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress.add_theme_font_size_override("font_size", 13)
	_progress.add_theme_color_override("font_color", Color(0.62, 0.72, 0.86))
	column.add_child(_progress)
	_canvas.visible = false

func _register_inputs() -> void:
	_add_key_action(&"replay_next", KEY_SPACE)
	_add_key_action(&"replay_close", KEY_ESCAPE)

func _add_key_action(action_id: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_id, event)
