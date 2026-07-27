class_name MatchHistoryRuntime
extends Node

signal result_finished

const RESULT_SECONDS := 3.4

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")
@onready var statistics_runtime: SeriesStatisticsRuntime = get_node("../SeriesStatisticsRuntime")

var _active := false
var _result_mode := false
var _token := 0
var _canvas: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _report: RichTextLabel
var _footer: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_key_action(&"history_toggle", KEY_F3)
	_build_interface()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"history_toggle") and not _result_mode:
		if _active:
			close()
		elif preparation_runtime.is_active():
			open_history()
	if _active and not _result_mode and not preparation_runtime.is_active():
		close()

func open_history() -> void:
	_result_mode = false
	_active = true
	_canvas.visible = true
	_title.text = "HISTÓRICO LOCAL DE CONFRONTOS"
	_report.text = build_history_report()
	_footer.text = "F3 fecha • até %d séries são mantidas localmente • %s" % [MatchHistoryLedger.MAX_SERIES, MatchHistoryLedger.SAVE_PATH]

func close() -> void:
	_token += 1
	_active = false
	_result_mode = false
	_canvas.visible = false

func is_active() -> bool:
	return _active

func play_result(record: Dictionary) -> void:
	_token += 1
	var token := _token
	_result_mode = true
	_active = true
	_canvas.visible = true
	_title.text = "RELATÓRIO DA SÉRIE"
	_report.text = build_result_report(record)
	_footer.text = "O histórico e as estatísticas foram salvos localmente."
	var running_headless := DisplayServer.get_name() == "headless" or OS.has_feature("server")
	if running_headless:
		call_deferred("_finish_result", token)
		return
	await get_tree().create_timer(RESULT_SECONDS, true, false, true).timeout
	_finish_result(token)

func skip_result_for_test() -> void:
	if _result_mode:
		_finish_result(_token)

func build_history_report() -> String:
	var aggregate := statistics_runtime.aggregate_history()
	var recent := statistics_runtime.recent_matches(8)
	var lines: Array[String] = []
	lines.append("[center][font_size=20][b]RESUMO GERAL[/b][/font_size][/center]")
	lines.append("[center]Séries %d • Rounds %d • Média %.1f rounds • %.1fs por round[/center]" % [
		int(aggregate.get("series", 0)), int(aggregate.get("rounds", 0)),
		float(aggregate.get("average_rounds", 0.0)), float(aggregate.get("average_round_seconds", 0.0))
	])
	lines.append("[center]P1 %d vitórias • P2 %d vitórias • KO %d • Tempo %d • Prorrogação %d[/center]" % [
		int(aggregate.get("p1_wins", 0)), int(aggregate.get("p2_wins", 0)),
		int(aggregate.get("ko_rounds", 0)), int(aggregate.get("time_rounds", 0)),
		int(aggregate.get("sudden_death_rounds", 0))
	])
	lines.append("[center]Dano P1 %.0f • Dano P2 %.0f • Aparos P1 %d • Aparos P2 %d[/center]\n" % [
		float(aggregate.get("damage_p1", 0.0)), float(aggregate.get("damage_p2", 0.0)),
		int(aggregate.get("parries_p1", 0)), int(aggregate.get("parries_p2", 0))
	])
	lines.append("[color=#f4d477][font_size=18][b]ÚLTIMAS SÉRIES[/b][/font_size][/color]")
	if recent.is_empty():
		lines.append("[color=#8b99ad]Nenhuma série concluída até agora.[/color]")
	else:
		for record in recent:
			lines.append(_history_line(record))
	return "\n".join(lines)

func build_result_report(record: Dictionary) -> String:
	var players: Array = record.get("players", [])
	var winner_index := int(record.get("winner_index", 1))
	var winner_name := "P%d" % winner_index
	if players.size() >= winner_index and players[winner_index - 1] is Dictionary:
		winner_name = String((players[winner_index - 1] as Dictionary).get("character_name", winner_name)).to_upper()
	var lines: Array[String] = []
	lines.append("[center][color=#f4d477][font_size=28][b]%s VENCE A SÉRIE[/b][/font_size][/color][/center]" % winner_name)
	lines.append("[center][font_size=22]%d — %d[/font_size][/center]" % [int(record.get("score_p1", 0)), int(record.get("score_p2", 0))])
	var config: Dictionary = record.get("config", {})
	lines.append("[center]%s[/center]\n" % CompetitiveMatchCatalog.config_summary(config))
	var totals: Array = record.get("totals", [])
	if totals.size() >= 2:
		lines.append("[table=3][cell][b]ESTATÍSTICA[/b][/cell][cell][b]P1[/b][/cell][cell][b]P2[/b][/cell]")
		for stat in [
			["Dano causado", "damage_dealt"], ["Dano de postura", "posture_damage"],
			["Acertos", "hits"], ["Aparos", "parries"], ["Quebras de postura", "posture_breaks"],
			["Desarmes", "disarms"], ["Agarrões", "grabs"], ["Interações elementais", "elemental_interactions"]
		]:
			var p1: Dictionary = totals[0] if totals[0] is Dictionary else {}
			var p2: Dictionary = totals[1] if totals[1] is Dictionary else {}
			lines.append("[cell]%s[/cell][cell]%.0f[/cell][cell]%.0f[/cell]" % [String(stat[0]), float(p1.get(String(stat[1]), 0.0)), float(p2.get(String(stat[1]), 0.0))])
		lines.append("[/table]\n")
	lines.append("[color=#8ecff0][b]ROUNDS[/b][/color]")
	for round_value in record.get("rounds", []):
		if round_value is Dictionary:
			var round_data: Dictionary = round_value
			lines.append("• Round %d — P%d • %s • %.1fs" % [
				int(round_data.get("round_number", 1)), int(round_data.get("winner_index", 1)),
				String(round_data.get("reason", "KO")), float(round_data.get("duration_seconds", 0.0))
			])
	return "\n".join(lines)

func _history_line(record: Dictionary) -> String:
	var players: Array = record.get("players", [])
	var p1 := "P1"
	var p2 := "P2"
	if players.size() >= 2:
		if players[0] is Dictionary:
			p1 = String((players[0] as Dictionary).get("character_name", p1)).to_upper()
		if players[1] is Dictionary:
			p2 = String((players[1] as Dictionary).get("character_name", p2)).to_upper()
	var config: Dictionary = record.get("config", {})
	return "• %s %d — %d %s • vencedor P%d • %s • %d rounds" % [
		p1, int(record.get("score_p1", 0)), int(record.get("score_p2", 0)), p2,
		int(record.get("winner_index", 0)), CompetitiveMatchCatalog.arena_label(config),
		(record.get("rounds", []) as Array).size()
	]

func _finish_result(token: int) -> void:
	if token != _token:
		return
	_active = false
	_result_mode = false
	_canvas.visible = false
	result_finished.emit()

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 228
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.offset_left = 130.0
	_panel.offset_top = 48.0
	_panel.offset_right = 1150.0
	_panel.offset_bottom = 680.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.016, 0.030, 0.99)
	style.border_color = Color(0.92, 0.72, 0.28, 0.94)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.44))
	column.add_child(_title)
	_report = RichTextLabel.new()
	_report.custom_minimum_size = Vector2(950.0, 500.0)
	_report.bbcode_enabled = true
	_report.fit_content = false
	_report.scroll_active = true
	_report.add_theme_font_size_override("normal_font_size", 15)
	_report.add_theme_font_size_override("bold_font_size", 16)
	column.add_child(_report)
	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_font_size_override("font_size", 13)
	_footer.add_theme_color_override("font_color", Color(0.70, 0.80, 0.92))
	column.add_child(_footer)
	_canvas.visible = false

func _register_key_action(action_id: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_id, event)
