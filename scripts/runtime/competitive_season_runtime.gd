class_name CompetitiveSeasonRuntime
extends Node

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")
@onready var statistics_runtime: SeriesStatisticsRuntime = get_node("../SeriesStatisticsRuntime")

var ledger := CompetitiveSeasonLedger.new()
var _active := false
var _selected_index := 0
var _editing_mode: StringName = &""
var _editing_season_id := ""
var _canvas: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _name_input: LineEdit
var _report: RichTextLabel
var _footer: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ledger.load_from_disk()
	_register_inputs()
	_build_interface()
	_sync_selection_to_active()
	_refresh()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"season_toggle") and _editing_mode == &"":
		if _active:
			close()
		elif preparation_runtime.is_active():
			open()
	if not _active:
		return
	if not preparation_runtime.is_active():
		close()
		return
	if _editing_mode != &"":
		return
	if Input.is_action_just_pressed(&"season_prev"):
		_selected_index = wrapi(_selected_index - 1, 0, maxi(1, ledger.seasons().size()))
		_refresh()
	elif Input.is_action_just_pressed(&"season_next"):
		_selected_index = wrapi(_selected_index + 1, 0, maxi(1, ledger.seasons().size()))
		_refresh()
	if Input.is_action_just_pressed(&"season_activate"):
		_activate_selected()
	if Input.is_action_just_pressed(&"season_create"):
		_begin_edit(&"create", "", "")
	if Input.is_action_just_pressed(&"season_rename"):
		var selected := selected_season()
		if not selected.is_empty():
			_begin_edit(&"rename", String(selected.get("season_id", "")), String(selected.get("name", "")))
	if Input.is_action_just_pressed(&"season_close"):
		_close_selected_if_active()

func open() -> void:
	_active = true
	_canvas.visible = true
	_sync_selection_to_active()
	_refresh()

func close() -> void:
	_active = false
	_editing_mode = &""
	_name_input.visible = false
	_canvas.visible = false

func is_active() -> bool:
	return _active

func season_context() -> Dictionary:
	return ledger.active_context()

func active_season_id() -> String:
	return String(ledger.active_context().get("season_id", "season_1"))

func selected_season() -> Dictionary:
	var source := ledger.seasons()
	if source.is_empty():
		return {}
	return source[clampi(_selected_index, 0, source.size() - 1)].duplicate(true)

func create_season_for_test(name: String) -> Dictionary:
	return ledger.create_season(name)

func activate_for_test(season_id: String) -> bool:
	return ledger.activate(season_id)

func season_profile_entries(season_id: String) -> Array[Dictionary]:
	var table: Dictionary = {}
	for record in statistics_runtime.history.filtered({"season_id": season_id}, 0):
		var players: Array = record.get("players", [])
		var winner_index := int(record.get("winner_index", 0))
		var totals: Array = record.get("totals", [])
		for index in range(mini(2, players.size())):
			if not (players[index] is Dictionary):
				continue
			var player: Dictionary = players[index]
			var profile_id := String(player.get("profile_id", "legacy_%s" % String(player.get("character_id", "unknown"))))
			var entry: Dictionary = table.get(profile_id, {
				"profile_id": profile_id,
				"profile_name": String(player.get("profile_name", player.get("character_name", "JOGADOR"))),
				"series": 0,
				"wins": 0,
				"losses": 0,
				"rounds_for": 0,
				"rounds_against": 0,
				"damage": 0.0,
				"parries": 0,
				"posture_breaks": 0,
				"disarms": 0
			})
			entry["series"] = int(entry.get("series", 0)) + 1
			if winner_index == index + 1:
				entry["wins"] = int(entry.get("wins", 0)) + 1
			else:
				entry["losses"] = int(entry.get("losses", 0)) + 1
			for round_value in record.get("rounds", []):
				if not (round_value is Dictionary):
					continue
				var round_data: Dictionary = round_value
				if int(round_data.get("winner_index", 0)) == index + 1:
					entry["rounds_for"] = int(entry.get("rounds_for", 0)) + 1
				else:
					entry["rounds_against"] = int(entry.get("rounds_against", 0)) + 1
			if index < totals.size() and totals[index] is Dictionary:
				var player_totals: Dictionary = totals[index]
				entry["damage"] = float(entry.get("damage", 0.0)) + float(player_totals.get("damage_dealt", 0.0))
				entry["parries"] = int(entry.get("parries", 0)) + int(player_totals.get("parries", 0))
				entry["posture_breaks"] = int(entry.get("posture_breaks", 0)) + int(player_totals.get("posture_breaks", 0))
				entry["disarms"] = int(entry.get("disarms", 0)) + int(player_totals.get("disarms", 0))
			table[profile_id] = entry
	var result: Array[Dictionary] = []
	for value in table.values():
		if value is Dictionary:
			var entry: Dictionary = (value as Dictionary).duplicate(true)
			var series := maxi(1, int(entry.get("series", 0)))
			entry["win_rate"] = float(entry.get("wins", 0)) / float(series)
			entry["round_diff"] = int(entry.get("rounds_for", 0)) - int(entry.get("rounds_against", 0))
			entry["season_points"] = _season_points(entry)
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var points_a := float(a.get("season_points", 0.0))
		var points_b := float(b.get("season_points", 0.0))
		if not is_equal_approx(points_a, points_b):
			return points_a > points_b
		var wins_a := int(a.get("wins", 0))
		var wins_b := int(b.get("wins", 0))
		if wins_a != wins_b:
			return wins_a > wins_b
		return int(a.get("round_diff", 0)) > int(b.get("round_diff", 0))
	)
	for index in range(result.size()):
		result[index]["position"] = index + 1
	return result

func build_report(season: Dictionary) -> String:
	if season.is_empty():
		return "[center]Nenhuma temporada disponível.[/center]"
	var season_id := String(season.get("season_id", "season_1"))
	var filters := {"season_id": season_id}
	var aggregate := statistics_runtime.history.aggregate(filters)
	var entries := season_profile_entries(season_id)
	var active_marker := " • ATIVA" if season_id == active_season_id() else " • ENCERRADA"
	var lines: Array[String] = []
	lines.append("[center][color=#f4d477][font_size=26][b]%s%s[/b][/font_size][/color][/center]" % [String(season.get("name", "TEMPORADA")).to_upper(), active_marker])
	lines.append("[center]%d séries • %d rounds • %d KOs • %d prorrogações • %.1fs por round[/center]\n" % [
		int(aggregate.get("series", 0)), int(aggregate.get("rounds", 0)), int(aggregate.get("ko_rounds", 0)),
		int(aggregate.get("sudden_death_rounds", 0)), float(aggregate.get("average_round_seconds", 0.0))
	])
	if entries.is_empty():
		lines.append("[center][color=#8b99ad]Nenhuma série registrada nesta temporada.[/color][/center]")
		return "\n".join(lines)
	lines.append("[table=9][cell][b]#[/b][/cell][cell][b]PERFIL[/b][/cell][cell][b]PTS[/b][/cell][cell][b]S[/b][/cell][cell][b]V[/b][/cell][cell][b]%[/b][/cell][cell][b]R+/R−[/b][/cell][cell][b]DANO[/b][/cell][cell][b]TÉCNICA[/b][/cell]")
	for entry in entries:
		lines.append("[cell]%d[/cell][cell]%s[/cell][cell]%.0f[/cell][cell]%d[/cell][cell]%d[/cell][cell]%.0f%%[/cell][cell]%d/%d[/cell][cell]%.0f[/cell][cell]%dA • %dQP • %dD[/cell]" % [
			int(entry.get("position", 0)), String(entry.get("profile_name", "JOGADOR")).to_upper(), float(entry.get("season_points", 0.0)),
			int(entry.get("series", 0)), int(entry.get("wins", 0)), float(entry.get("win_rate", 0.0)) * 100.0,
			int(entry.get("rounds_for", 0)), int(entry.get("rounds_against", 0)), float(entry.get("damage", 0.0)),
			int(entry.get("parries", 0)), int(entry.get("posture_breaks", 0)), int(entry.get("disarms", 0))
		])
	lines.append("[/table]")
	return "\n".join(lines)

func _season_points(entry: Dictionary) -> float:
	return 1000.0 \
		+ int(entry.get("wins", 0)) * 40.0 \
		- int(entry.get("losses", 0)) * 12.0 \
		+ int(entry.get("round_diff", 0)) * 5.0 \
		+ int(entry.get("parries", 0)) * 0.6 \
		+ int(entry.get("posture_breaks", 0)) * 1.5 \
		+ int(entry.get("disarms", 0)) * 2.0

func _activate_selected() -> void:
	var selected := selected_season()
	if selected.is_empty():
		return
	ledger.activate(String(selected.get("season_id", "")))
	_refresh()

func _close_selected_if_active() -> void:
	var selected := selected_season()
	if selected.is_empty() or String(selected.get("season_id", "")) != active_season_id():
		return
	ledger.close_active()
	_refresh()

func _begin_edit(mode: StringName, season_id: String, current_name: String) -> void:
	_editing_mode = mode
	_editing_season_id = season_id
	_name_input.text = current_name
	_name_input.visible = true
	_name_input.grab_focus()
	_name_input.select_all()
	_footer.text = "Digite o nome e pressione Enter • Esc cancela"

func _finish_edit(submitted: bool) -> void:
	if submitted:
		if _editing_mode == &"create":
			var created := ledger.create_season(_name_input.text)
			if not created.is_empty():
				_selected_index = maxi(0, ledger.seasons().size() - 1)
		elif _editing_mode == &"rename":
			ledger.rename(_editing_season_id, _name_input.text)
	_editing_mode = &""
	_editing_season_id = ""
	_name_input.visible = false
	_name_input.release_focus()
	_refresh()

func _sync_selection_to_active() -> void:
	var active_id := active_season_id()
	var source := ledger.seasons()
	for index in range(source.size()):
		if String(source[index].get("season_id", "")) == active_id:
			_selected_index = index
			return
	_selected_index = 0

func _refresh() -> void:
	if not is_instance_valid(_report):
		return
	var selected := selected_season()
	_title.text = "TAIJIFU MASTERS • TEMPORADAS"
	_report.text = build_report(selected)
	var season_names: Array[String] = []
	var source := ledger.seasons()
	for index in range(source.size()):
		var season: Dictionary = source[index]
		var marker := "▶" if index == _selected_index else " "
		var active := " [ATIVA]" if String(season.get("season_id", "")) == active_season_id() else ""
		season_names.append("%s %s%s" % [marker, String(season.get("name", "TEMPORADA")), active])
	_footer.text = "%s\nF7 fecha • ↑/↓ temporada • Enter ativa • N cria • R renomeia • C encerra ativa • Tehkné Solutions" % "  |  ".join(season_names)

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 233
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.offset_left = 70.0
	_panel.offset_top = 38.0
	_panel.offset_right = 1210.0
	_panel.offset_bottom = 690.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.018, 0.030, 0.992)
	style.border_color = Color(0.96, 0.72, 0.30, 0.94)
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
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	column.add_child(_title)
	_name_input = LineEdit.new()
	_name_input.max_length = 40
	_name_input.placeholder_text = "Nome da temporada"
	_name_input.visible = false
	_name_input.text_submitted.connect(func(_value: String) -> void: _finish_edit(true))
	_name_input.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_finish_edit(false)
	)
	column.add_child(_name_input)
	_report = RichTextLabel.new()
	_report.custom_minimum_size = Vector2(1080.0, 510.0)
	_report.bbcode_enabled = true
	_report.scroll_active = true
	_report.add_theme_font_size_override("normal_font_size", 13)
	column.add_child(_report)
	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_theme_font_size_override("font_size", 11)
	_footer.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
	column.add_child(_footer)
	_canvas.visible = false

func _register_inputs() -> void:
	_add_key_action(&"season_toggle", KEY_F7)
	_add_key_action(&"season_prev", KEY_UP)
	_add_key_action(&"season_next", KEY_DOWN)
	_add_key_action(&"season_activate", KEY_ENTER)
	_add_key_action(&"season_create", KEY_N)
	_add_key_action(&"season_rename", KEY_R)
	_add_key_action(&"season_close", KEY_C)

func _add_key_action(action_id: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_id, event)
