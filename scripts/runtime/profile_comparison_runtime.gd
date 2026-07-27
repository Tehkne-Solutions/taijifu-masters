class_name ProfileComparisonRuntime
extends Node

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")
@onready var statistics_runtime: SeriesStatisticsRuntime = get_node("../SeriesStatisticsRuntime")
@onready var season_runtime: CompetitiveSeasonRuntime = get_node("../CompetitiveSeasonRuntime")

var _active := false
var _selected_index := 0
var _selected_ids: Array[String] = []
var _season_only := false
var _comparison_mode := false
var _entries: Array[Dictionary] = []
var _canvas: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _report: RichTextLabel
var _footer: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	_build_interface()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"profile_compare_toggle"):
		if _active:
			close()
		elif preparation_runtime.is_active():
			open()
	if not _active:
		return
	if not preparation_runtime.is_active():
		close()
		return
	if Input.is_action_just_pressed(&"profile_compare_prev"):
		_selected_index = wrapi(_selected_index - 1, 0, maxi(1, _entries.size()))
		_comparison_mode = false
		_refresh()
	elif Input.is_action_just_pressed(&"profile_compare_next"):
		_selected_index = wrapi(_selected_index + 1, 0, maxi(1, _entries.size()))
		_comparison_mode = false
		_refresh()
	if Input.is_action_just_pressed(&"profile_compare_select"):
		_toggle_selected_profile()
	if Input.is_action_just_pressed(&"profile_compare_open"):
		_comparison_mode = _selected_ids.size() == 2
		_refresh()
	if Input.is_action_just_pressed(&"profile_compare_scope"):
		_season_only = not _season_only
		_selected_index = 0
		_comparison_mode = false
		_refresh()

func open() -> void:
	_active = true
	_canvas.visible = true
	_selected_index = 0
	_comparison_mode = false
	_refresh()

func close() -> void:
	_active = false
	_canvas.visible = false

func is_active() -> bool:
	return _active

func comparison_ids() -> Array[String]:
	return _selected_ids.duplicate()

func profile_entries(season_id: String = "") -> Array[Dictionary]:
	var filters: Dictionary = {}
	if season_id != "":
		filters["season_id"] = season_id
	var table: Dictionary = {}
	for record in statistics_runtime.history.filtered(filters, 0):
		var players: Array = record.get("players", [])
		var totals: Array = record.get("totals", [])
		var winner_index := int(record.get("winner_index", 0))
		for index in range(mini(2, players.size())):
			if not (players[index] is Dictionary):
				continue
			var player: Dictionary = players[index]
			var character_id := StringName(player.get("character_id", &"unknown"))
			var profile_id := String(player.get("profile_id", "legacy_%s" % String(character_id)))
			var entry: Dictionary = table.get(profile_id, {
				"profile_id": profile_id,
				"profile_name": String(player.get("profile_name", player.get("character_name", "JOGADOR"))),
				"series": 0,
				"wins": 0,
				"losses": 0,
				"rounds": 0,
				"round_wins": 0,
				"ko_wins": 0,
				"damage": 0.0,
				"parries": 0,
				"posture_breaks": 0,
				"disarms": 0,
				"character_counts": {}
			})
			entry["series"] = int(entry.get("series", 0)) + 1
			if winner_index == index + 1:
				entry["wins"] = int(entry.get("wins", 0)) + 1
			else:
				entry["losses"] = int(entry.get("losses", 0)) + 1
			var counts: Dictionary = entry.get("character_counts", {})
			counts[String(character_id)] = int(counts.get(String(character_id), 0)) + 1
			entry["character_counts"] = counts
			for round_value in record.get("rounds", []):
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
			table[profile_id] = entry
	var result: Array[Dictionary] = []
	for value in table.values():
		if value is Dictionary:
			var entry: Dictionary = (value as Dictionary).duplicate(true)
			var series := maxi(1, int(entry.get("series", 0)))
			entry["win_rate"] = float(entry.get("wins", 0)) / float(series)
			entry["main_character_id"] = _main_character(entry.get("character_counts", {}) as Dictionary)
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var wins_a := int(a.get("wins", 0))
		var wins_b := int(b.get("wins", 0))
		if wins_a != wins_b:
			return wins_a > wins_b
		return float(a.get("win_rate", 0.0)) > float(b.get("win_rate", 0.0))
	)
	return result

func profile_summary(profile_id: String, season_id: String = "") -> Dictionary:
	for entry in profile_entries(season_id):
		if String(entry.get("profile_id", "")) == profile_id:
			return entry.duplicate(true)
	return {}

func head_to_head(profile_a: String, profile_b: String, season_id: String = "") -> Dictionary:
	var result := {"series": 0, "wins_a": 0, "wins_b": 0, "rounds_a": 0, "rounds_b": 0}
	var filters: Dictionary = {}
	if season_id != "":
		filters["season_id"] = season_id
	for record in statistics_runtime.history.filtered(filters, 0):
		var players: Array = record.get("players", [])
		if players.size() < 2 or not (players[0] is Dictionary) or not (players[1] is Dictionary):
			continue
		var p1_id := String((players[0] as Dictionary).get("profile_id", ""))
		var p2_id := String((players[1] as Dictionary).get("profile_id", ""))
		var a_index := 0
		var b_index := 0
		if p1_id == profile_a and p2_id == profile_b:
			a_index = 1
			b_index = 2
		elif p1_id == profile_b and p2_id == profile_a:
			a_index = 2
			b_index = 1
		else:
			continue
		result["series"] = int(result.get("series", 0)) + 1
		var winner := int(record.get("winner_index", 0))
		if winner == a_index:
			result["wins_a"] = int(result.get("wins_a", 0)) + 1
		elif winner == b_index:
			result["wins_b"] = int(result.get("wins_b", 0)) + 1
		for round_value in record.get("rounds", []):
			if not (round_value is Dictionary):
				continue
			var round_winner := int((round_value as Dictionary).get("winner_index", 0))
			if round_winner == a_index:
				result["rounds_a"] = int(result.get("rounds_a", 0)) + 1
			elif round_winner == b_index:
				result["rounds_b"] = int(result.get("rounds_b", 0)) + 1
	return result

func build_comparison_report(profile_a: String, profile_b: String, season_id: String = "") -> String:
	var a := profile_summary(profile_a, season_id)
	var b := profile_summary(profile_b, season_id)
	if a.is_empty() or b.is_empty():
		return "[center]Selecione dois perfis com séries registradas.[/center]"
	var direct := head_to_head(profile_a, profile_b, season_id)
	var scope := "TEMPORADA ATIVA" if season_id != "" else "HISTÓRICO COMPLETO"
	var lines: Array[String] = []
	lines.append("[center][color=#cfa7ff][font_size=26][b]COMPARAÇÃO DE PERFIS • %s[/b][/font_size][/color][/center]" % scope)
	lines.append("[center][font_size=20]%s  ×  %s[/font_size][/center]\n" % [String(a.get("profile_name", "A")).to_upper(), String(b.get("profile_name", "B")).to_upper()])
	lines.append("[table=4][cell][b]MÉTRICA[/b][/cell][cell][b]PERFIL A[/b][/cell][cell][b]PERFIL B[/b][/cell][cell][b]Δ B−A[/b][/cell]")
	for metric in [
		["Séries", "series", 0], ["Vitórias", "wins", 0], ["Derrotas", "losses", 0],
		["Taxa de vitória", "win_rate", 1], ["Rounds vencidos", "round_wins", 0], ["Vitórias por KO", "ko_wins", 0],
		["Dano", "damage", 0], ["Aparos", "parries", 0], ["Quebras de postura", "posture_breaks", 0], ["Desarmes", "disarms", 0]
	]:
		var key := String(metric[1])
		var decimals := int(metric[2])
		var value_a := float(a.get(key, 0.0))
		var value_b := float(b.get(key, 0.0))
		if key == "win_rate":
			value_a *= 100.0
			value_b *= 100.0
		lines.append("[cell]%s[/cell][cell]%s[/cell][cell]%s[/cell][cell]%s[/cell]" % [
			String(metric[0]), _number(value_a, decimals), _number(value_b, decimals), _signed(value_b - value_a, decimals)
		])
	lines.append("[/table]\n")
	lines.append("[center][color=#70e0a0][b]CONFRONTO DIRETO[/b][/color] • %d séries • %d—%d vitórias • %d—%d rounds[/center]" % [
		int(direct.get("series", 0)), int(direct.get("wins_a", 0)), int(direct.get("wins_b", 0)),
		int(direct.get("rounds_a", 0)), int(direct.get("rounds_b", 0))
	])
	lines.append("[center]Principais personagens: %s × %s[/center]" % [
		CharacterVisualCatalog.display_name(StringName(a.get("main_character_id", &"unknown"))).to_upper(),
		CharacterVisualCatalog.display_name(StringName(b.get("main_character_id", &"unknown"))).to_upper()
	])
	return "\n".join(lines)

func _toggle_selected_profile() -> void:
	if _entries.is_empty():
		return
	var profile_id := String(_entries[clampi(_selected_index, 0, _entries.size() - 1)].get("profile_id", ""))
	if profile_id in _selected_ids:
		_selected_ids.erase(profile_id)
	else:
		if _selected_ids.size() >= 2:
			_selected_ids.pop_front()
		_selected_ids.append(profile_id)
	_comparison_mode = false
	_refresh()

func _refresh() -> void:
	var season_id := season_runtime.active_season_id() if _season_only else ""
	_entries = profile_entries(season_id)
	_selected_index = clampi(_selected_index, 0, maxi(0, _entries.size() - 1))
	_title.text = "TAIJIFU MASTERS • COMPARAÇÃO DE PERFIS"
	if _comparison_mode and _selected_ids.size() == 2:
		_report.text = build_comparison_report(_selected_ids[0], _selected_ids[1], season_id)
	else:
		var lines: Array[String] = []
		var scope := "TEMPORADA ATIVA" if _season_only else "HISTÓRICO COMPLETO"
		lines.append("[center][color=#cfa7ff][font_size=22][b]SELECIONE DOIS PERFIS • %s[/b][/font_size][/color][/center]\n" % scope)
		if _entries.is_empty():
			lines.append("[center][color=#8b99ad]Nenhum perfil com séries registradas.[/color][/center]")
		else:
			for index in range(_entries.size()):
				var entry: Dictionary = _entries[index]
				var profile_id := String(entry.get("profile_id", ""))
				var cursor := "[color=#ffd36b]▶[/color]" if index == _selected_index else " "
				var marker := "[color=#b98cff][C][/color]" if profile_id in _selected_ids else "   "
				lines.append("%s %s [b]%s[/b] • %dV/%dS • %.0f%% • %s" % [
					cursor, marker, String(entry.get("profile_name", "JOGADOR")).to_upper(), int(entry.get("wins", 0)),
					int(entry.get("series", 0)), float(entry.get("win_rate", 0.0)) * 100.0,
					CharacterVisualCatalog.display_name(StringName(entry.get("main_character_id", &"unknown"))).to_upper()
				])
		_report.text = "\n".join(lines)
	_footer.text = "F6 fecha • ↑/↓ perfil • C marca • V compara • A alterna histórico/temporada • Tehkné Solutions"

func _main_character(counts: Dictionary) -> StringName:
	var selected := &"unknown"
	var best := -1
	for key in counts.keys():
		var count := int(counts[key])
		if count > best:
			best = count
			selected = StringName(key)
	return selected

func _number(value: float, decimals: int) -> String:
	return "%.1f" % value if decimals > 0 else "%.0f" % value

func _signed(value: float, decimals: int) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%.1f" % [prefix, value] if decimals > 0 else "%s%.0f" % [prefix, value]

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 232
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.offset_left = 80.0
	_panel.offset_top = 42.0
	_panel.offset_right = 1200.0
	_panel.offset_bottom = 682.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.016, 0.030, 0.992)
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
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
	column.add_child(_footer)
	_canvas.visible = false

func _register_inputs() -> void:
	_add_key_action(&"profile_compare_toggle", KEY_F6)
	_add_key_action(&"profile_compare_prev", KEY_UP)
	_add_key_action(&"profile_compare_next", KEY_DOWN)
	_add_key_action(&"profile_compare_select", KEY_C)
	_add_key_action(&"profile_compare_open", KEY_V)
	_add_key_action(&"profile_compare_scope", KEY_A)

func _add_key_action(action_id: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_id, event)
