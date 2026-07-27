class_name SeriesComparisonRuntime
extends Node

var _active := false
var _canvas: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _report: RichTextLabel
var _footer: Label
var _left: Dictionary = {}
var _right: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ESCAPE, KEY_V]:
		close()
		get_viewport().set_input_as_handled()

func open_comparison(left_record: Dictionary, right_record: Dictionary) -> bool:
	if left_record.is_empty() or right_record.is_empty():
		return false
	_left = left_record.duplicate(true)
	_right = right_record.duplicate(true)
	_report.text = build_report(_left, _right)
	_active = true
	_canvas.visible = true
	return true

func close() -> void:
	_active = false
	_canvas.visible = false

func is_active() -> bool:
	return _active

func comparison_snapshot() -> Dictionary:
	return {"left": _left.duplicate(true), "right": _right.duplicate(true)}

func build_report(left_record: Dictionary, right_record: Dictionary) -> String:
	var left := summarize(left_record)
	var right := summarize(right_record)
	var lines: Array[String] = []
	lines.append("[center][color=#f4d477][font_size=26][b]COMPARAÇÃO ENTRE SÉRIES[/b][/font_size][/color][/center]")
	lines.append("[center]%s  ×  %s[/center]\n" % [String(left.get("label", "SÉRIE A")), String(right.get("label", "SÉRIE B"))])
	lines.append("[table=4][cell][b]MÉTRICA[/b][/cell][cell][b]SÉRIE A[/b][/cell][cell][b]SÉRIE B[/b][/cell][cell][b]Δ B−A[/b][/cell]")
	for metric in [
		["Placar P1", "score_p1", 0], ["Placar P2", "score_p2", 0], ["Rounds", "rounds", 0],
		["Duração", "duration", 1], ["Dano total", "damage", 0], ["Aparos", "parries", 0],
		["Quebras de postura", "posture_breaks", 0], ["Desarmes", "disarms", 0], ["Destaques", "highlights", 0]
	]:
		var key := String(metric[1])
		var decimals := int(metric[2])
		var a := float(left.get(key, 0.0))
		var b := float(right.get(key, 0.0))
		lines.append("[cell]%s[/cell][cell]%s[/cell][cell]%s[/cell][cell]%s[/cell]" % [
			String(metric[0]), _number(a, decimals), _number(b, decimals), _signed(b - a, decimals)
		])
	lines.append("[/table]\n")
	lines.append("[table=3][cell][b]CONTEXTO[/b][/cell][cell][b]SÉRIE A[/b][/cell][cell][b]SÉRIE B[/b][/cell]")
	for context in [["Arena", "arena"], ["Vencedor", "winner"], ["P1", "p1"], ["P2", "p2"], ["Perfil P1", "profile_p1"], ["Perfil P2", "profile_p2"]]:
		lines.append("[cell]%s[/cell][cell]%s[/cell][cell]%s[/cell]" % [String(context[0]), String(left.get(String(context[1]), "—")), String(right.get(String(context[1]), "—"))])
	lines.append("[/table]")
	return "\n".join(lines)

func summarize(record: Dictionary) -> Dictionary:
	var players: Array = record.get("players", [])
	var totals: Array = record.get("totals", [])
	var rounds: Array = record.get("rounds", [])
	var p1: Dictionary = players[0] if players.size() > 0 and players[0] is Dictionary else {}
	var p2: Dictionary = players[1] if players.size() > 1 and players[1] is Dictionary else {}
	var total_p1: Dictionary = totals[0] if totals.size() > 0 and totals[0] is Dictionary else {}
	var total_p2: Dictionary = totals[1] if totals.size() > 1 and totals[1] is Dictionary else {}
	var duration := 0.0
	var highlights := 0
	for round_value in rounds:
		if round_value is Dictionary:
			var round_data: Dictionary = round_value
			duration += float(round_data.get("duration_seconds", 0.0))
			highlights += (round_data.get("highlights", []) as Array).size()
	var winner_index := int(record.get("winner_index", 0))
	var winner := "EMPATE"
	if winner_index == 1:
		winner = String(p1.get("profile_name", p1.get("character_name", "P1")))
	elif winner_index == 2:
		winner = String(p2.get("profile_name", p2.get("character_name", "P2")))
	return {
		"label": "%s %d—%d %s" % [String(p1.get("character_name", "P1")), int(record.get("score_p1", 0)), int(record.get("score_p2", 0)), String(p2.get("character_name", "P2"))],
		"score_p1": int(record.get("score_p1", 0)),
		"score_p2": int(record.get("score_p2", 0)),
		"rounds": rounds.size(),
		"duration": duration,
		"damage": float(total_p1.get("damage_dealt", 0.0)) + float(total_p2.get("damage_dealt", 0.0)),
		"parries": int(total_p1.get("parries", 0)) + int(total_p2.get("parries", 0)),
		"posture_breaks": int(total_p1.get("posture_breaks", 0)) + int(total_p2.get("posture_breaks", 0)),
		"disarms": int(total_p1.get("disarms", 0)) + int(total_p2.get("disarms", 0)),
		"highlights": highlights,
		"arena": CompetitiveMatchCatalog.arena_label(record.get("config", {}) as Dictionary),
		"winner": winner,
		"p1": String(p1.get("character_name", "P1")),
		"p2": String(p2.get("character_name", "P2")),
		"profile_p1": String(p1.get("profile_name", "JOGADOR 1")),
		"profile_p2": String(p2.get("profile_name", "JOGADOR 2"))
	}

func _number(value: float, decimals: int) -> String:
	return "%.1f" % value if decimals > 0 else "%.0f" % value

func _signed(value: float, decimals: int) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%.1f" % [prefix, value] if decimals > 0 else "%s%.0f" % [prefix, value]

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 242
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.offset_left = 80.0
	_panel.offset_top = 40.0
	_panel.offset_right = 1200.0
	_panel.offset_bottom = 680.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.009, 0.015, 0.028, 0.994)
	style.border_color = Color(0.72, 0.52, 1.0, 0.94)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_title = Label.new()
	_title.text = "TAIJIFU MASTERS • COMPARAÇÃO"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(0.84, 0.72, 1.0))
	column.add_child(_title)
	_report = RichTextLabel.new()
	_report.custom_minimum_size = Vector2(1050.0, 520.0)
	_report.bbcode_enabled = true
	_report.scroll_active = true
	_report.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_report)
	_footer = Label.new()
	_footer.text = "V ou Esc fecha • comparação derivada do histórico local • Tehkné Solutions"
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
	column.add_child(_footer)
	_canvas.visible = false
