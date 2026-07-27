class_name LocalRankingRuntime
extends Node

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")
@onready var statistics_runtime: SeriesStatisticsRuntime = get_node("../SeriesStatisticsRuntime")

var _active := false
var _canvas: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _report: RichTextLabel
var _footer: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	_build_interface()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"ranking_toggle"):
		if _active:
			close()
		elif preparation_runtime.is_active():
			open()
	if _active and not preparation_runtime.is_active():
		close()

func open() -> void:
	_active = true
	_canvas.visible = true
	_report.text = build_report()

func close() -> void:
	_active = false
	_canvas.visible = false

func is_active() -> bool:
	return _active

func ranking_entries() -> Array[Dictionary]:
	var table: Dictionary = {}
	for record in statistics_runtime.history.filtered({}, 0):
		var players: Array = record.get("players", [])
		var winner_index := int(record.get("winner_index", 0))
		var rounds: Array = record.get("rounds", [])
		var totals: Array = record.get("totals", [])
		for index in range(mini(2, players.size())):
			if not (players[index] is Dictionary):
				continue
			var player: Dictionary = players[index]
			var character_id := StringName(player.get("character_id", &"unknown"))
			var entry: Dictionary = table.get(character_id, _empty_entry(character_id, player))
			entry["series"] = int(entry.get("series", 0)) + 1
			if winner_index == index + 1:
				entry["wins"] = int(entry.get("wins", 0)) + 1
			else:
				entry["losses"] = int(entry.get("losses", 0)) + 1
			for round_value in rounds:
				if not (round_value is Dictionary):
					continue
				var round_data: Dictionary = round_value
				entry["rounds"] = int(entry.get("rounds", 0)) + 1
				if int(round_data.get("winner_index", 0)) == index + 1:
					entry["round_wins"] = int(entry.get("round_wins", 0)) + 1
				if String(round_data.get("reason", "")) == "KO" and int(round_data.get("winner_index", 0)) == index + 1:
					entry["ko_wins"] = int(entry.get("ko_wins", 0)) + 1
			if index < totals.size() and totals[index] is Dictionary:
				var player_totals: Dictionary = totals[index]
				entry["damage"] = float(entry.get("damage", 0.0)) + float(player_totals.get("damage_dealt", 0.0))
				entry["parries"] = int(entry.get("parries", 0)) + int(player_totals.get("parries", 0))
				entry["posture_breaks"] = int(entry.get("posture_breaks", 0)) + int(player_totals.get("posture_breaks", 0))
				entry["disarms"] = int(entry.get("disarms", 0)) + int(player_totals.get("disarms", 0))
			table[character_id] = entry
	var result: Array[Dictionary] = []
	for value in table.values():
		if value is Dictionary:
			var entry: Dictionary = (value as Dictionary).duplicate(true)
			var series := maxi(1, int(entry.get("series", 0)))
			entry["win_rate"] = float(entry.get("wins", 0)) / float(series)
			entry["rating"] = _rating(entry)
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rating_a := float(a.get("rating", 0.0))
		var rating_b := float(b.get("rating", 0.0))
		if not is_equal_approx(rating_a, rating_b):
			return rating_a > rating_b
		return int(a.get("wins", 0)) > int(b.get("wins", 0))
	)
	for index in range(result.size()):
		result[index]["position"] = index + 1
	return result

func build_report() -> String:
	var entries := ranking_entries()
	var lines: Array[String] = []
	lines.append("[center][color=#f4d477][font_size=27][b]RANKING LOCAL[/b][/font_size][/color][/center]")
	lines.append("[center]Pontuação baseada em séries, rounds, KOs, aparos, quebras de postura e desarmes.[/center]\n")
	if entries.is_empty():
		lines.append("[center][color=#8b99ad]Conclua séries competitivas para formar o ranking.[/color][/center]")
		return "\n".join(lines)
	lines.append("[table=9][cell][b]#[/b][/cell][cell][b]LUTADOR[/b][/cell][cell][b]RATING[/b][/cell][cell][b]SÉRIES[/b][/cell][cell][b]V[/b][/cell][cell][b]%[/b][/cell][cell][b]ROUNDS[/b][/cell][cell][b]KO[/b][/cell][cell][b]TÉCNICA[/b][/cell]")
	for entry in entries:
		lines.append("[cell]%d[/cell][cell]%s[/cell][cell]%.0f[/cell][cell]%d[/cell][cell]%d[/cell][cell]%.0f%%[/cell][cell]%d/%d[/cell][cell]%d[/cell][cell]%dA • %dQP • %dD[/cell]" % [
			int(entry.get("position", 0)), String(entry.get("character_name", "DESCONHECIDO")).to_upper(),
			float(entry.get("rating", 1000.0)), int(entry.get("series", 0)), int(entry.get("wins", 0)),
			float(entry.get("win_rate", 0.0)) * 100.0, int(entry.get("round_wins", 0)), int(entry.get("rounds", 0)),
			int(entry.get("ko_wins", 0)), int(entry.get("parries", 0)), int(entry.get("posture_breaks", 0)), int(entry.get("disarms", 0))
		])
	lines.append("[/table]\n")
	var leader: Dictionary = entries[0]
	lines.append("[center][color=#70e0a0][b]LÍDER ATUAL: %s • %.0f pontos[/b][/color][/center]" % [String(leader.get("character_name", "")).to_upper(), float(leader.get("rating", 0.0))])
	return "\n".join(lines)

func _rating(entry: Dictionary) -> float:
	var wins := int(entry.get("wins", 0))
	var losses := int(entry.get("losses", 0))
	var round_wins := int(entry.get("round_wins", 0))
	var rounds := int(entry.get("rounds", 0))
	var round_losses := maxi(0, rounds - round_wins)
	return 1000.0 \
		+ wins * 36.0 \
		- losses * 14.0 \
		+ (round_wins - round_losses) * 4.0 \
		+ int(entry.get("ko_wins", 0)) * 5.0 \
		+ int(entry.get("parries", 0)) * 0.8 \
		+ int(entry.get("posture_breaks", 0)) * 1.8 \
		+ int(entry.get("disarms", 0)) * 2.5

func _empty_entry(character_id: StringName, player: Dictionary) -> Dictionary:
	return {
		"character_id": character_id,
		"character_name": String(player.get("character_name", CharacterVisualCatalog.display_name(character_id))),
		"series": 0,
		"wins": 0,
		"losses": 0,
		"rounds": 0,
		"round_wins": 0,
		"ko_wins": 0,
		"damage": 0.0,
		"parries": 0,
		"posture_breaks": 0,
		"disarms": 0
	}

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 234
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.offset_left = 95.0
	_panel.offset_top = 48.0
	_panel.offset_right = 1185.0
	_panel.offset_bottom = 678.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.017, 0.030, 0.992)
	style.border_color = Color(0.42, 0.88, 0.66, 0.94)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	_title = Label.new()
	_title.text = "TAIJIFU MASTERS • RANKING"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 23)
	_title.add_theme_color_override("font_color", Color(0.66, 1.0, 0.82))
	column.add_child(_title)
	_report = RichTextLabel.new()
	_report.custom_minimum_size = Vector2(1020.0, 500.0)
	_report.bbcode_enabled = true
	_report.scroll_active = true
	_report.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_report)
	_footer = Label.new()
	_footer.text = "F8 fecha • ranking recalculado a partir de user://match_history.json • Tehkné Solutions"
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_color_override("font_color", Color(0.70, 0.82, 0.92))
	column.add_child(_footer)
	_canvas.visible = false

func _register_input() -> void:
	if not InputMap.has_action(&"ranking_toggle"):
		InputMap.add_action(&"ranking_toggle", 0.5)
	for existing in InputMap.action_get_events(&"ranking_toggle"):
		if existing is InputEventKey and existing.physical_keycode == KEY_F8:
			return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F8
	InputMap.action_add_event(&"ranking_toggle", event)
