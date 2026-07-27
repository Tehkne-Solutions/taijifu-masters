class_name MatchHistoryRuntime
extends Node

signal result_finished

const RESULT_SECONDS := 3.4
const FILTER_FIELDS: Array[StringName] = [&"character_id", &"arena_id", &"result_id", &"curation_id"]
const RESULT_OPTIONS: Array[StringName] = [&"all", &"p1_win", &"p2_win", &"ko", &"time", &"sudden_death"]

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")
@onready var statistics_runtime: SeriesStatisticsRuntime = get_node("../SeriesStatisticsRuntime")
@onready var replay_runtime: SeriesReplayRuntime = get_node("../SeriesReplayRuntime")

var _active := false
var _result_mode := false
var _token := 0
var _filter_field_index := 0
var _filters: Dictionary = {"character_id": &"all", "arena_id": &"all", "result_id": &"all", "curation_id": &"all"}
var _selected_index := 0
var _visible_records: Array[Dictionary] = []
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
	if Input.is_action_just_pressed(&"history_toggle") and not _result_mode:
		if _active:
			close()
		elif preparation_runtime.is_active():
			open_history()
	if not _active or _result_mode:
		return
	if not preparation_runtime.is_active():
		close()
		return
	if Input.is_action_just_pressed(&"history_next_filter"):
		_filter_field_index = wrapi(_filter_field_index + 1, 0, FILTER_FIELDS.size())
		_refresh_history()
	if Input.is_action_just_pressed(&"history_prev_value"):
		_cycle_filter_value(-1)
	elif Input.is_action_just_pressed(&"history_next_value"):
		_cycle_filter_value(1)
	if Input.is_action_just_pressed(&"history_prev_record"):
		_selected_index = wrapi(_selected_index - 1, 0, maxi(1, _visible_records.size()))
		_refresh_history()
	elif Input.is_action_just_pressed(&"history_next_record"):
		_selected_index = wrapi(_selected_index + 1, 0, maxi(1, _visible_records.size()))
		_refresh_history()
	if Input.is_action_just_pressed(&"history_reset_filters"):
		_filters = {"character_id": &"all", "arena_id": &"all", "result_id": &"all", "curation_id": &"all"}
		_selected_index = 0
		_refresh_history()
	if Input.is_action_just_pressed(&"history_favorite"):
		_toggle_selected_favorite()
	for index in range(MatchHistoryLedger.TAG_OPTIONS.size()):
		if Input.is_action_just_pressed(StringName("history_tag_%d" % (index + 1))):
			_toggle_selected_tag(MatchHistoryLedger.TAG_OPTIONS[index])
	if Input.is_action_just_pressed(&"history_replay") and not _visible_records.is_empty():
		var selected := _visible_records[clampi(_selected_index, 0, _visible_records.size() - 1)].duplicate(true)
		close()
		replay_runtime.play(selected)

func open_history() -> void:
	_result_mode = false
	_active = true
	_selected_index = 0
	_canvas.visible = true
	_title.text = "HISTÓRICO LOCAL DE CONFRONTOS"
	_refresh_history()

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
	_footer.text = "Histórico salvo • abra F3 para rever, favoritar e classificar a série."
	var running_headless := DisplayServer.get_name() == "headless" or OS.has_feature("server")
	if running_headless:
		call_deferred("_finish_result", token)
		return
	await get_tree().create_timer(RESULT_SECONDS, true, false, true).timeout
	_finish_result(token)

func skip_result_for_test() -> void:
	if _result_mode:
		_finish_result(_token)

func set_filters_for_test(filters: Dictionary) -> void:
	_filters = {
		"character_id": StringName(filters.get("character_id", &"all")),
		"arena_id": StringName(filters.get("arena_id", &"all")),
		"result_id": StringName(filters.get("result_id", &"all")),
		"curation_id": StringName(filters.get("curation_id", &"all"))
	}
	_selected_index = 0
	_refresh_history()

func current_filters() -> Dictionary:
	return _filters.duplicate(true)

func filtered_count() -> int:
	return statistics_runtime.filtered_matches(_filters, 0).size()

func selected_record() -> Dictionary:
	if _visible_records.is_empty():
		return {}
	return _visible_records[clampi(_selected_index, 0, _visible_records.size() - 1)].duplicate(true)

func toggle_favorite_for_test(match_id: String) -> bool:
	return statistics_runtime.history.toggle_favorite(match_id)

func toggle_tag_for_test(match_id: String, tag_id: StringName) -> Array[StringName]:
	return statistics_runtime.history.toggle_tag(match_id, tag_id)

func build_history_report() -> String:
	var aggregate := statistics_runtime.aggregate_history(_filters)
	_visible_records = statistics_runtime.filtered_matches(_filters, 12)
	_selected_index = clampi(_selected_index, 0, maxi(0, _visible_records.size() - 1))
	var lines: Array[String] = []
	lines.append("[center][font_size=18][b]FILTROS[/b][/font_size][/center]")
	lines.append("[center]%s[/center]" % _filter_summary())
	lines.append("[center][font_size=20][b]RESUMO FILTRADO[/b][/font_size][/center]")
	lines.append("[center]Séries %d • Rounds %d • Média %.1f rounds • %.1fs por round • %d destaques • %d favoritas[/center]" % [
		int(aggregate.get("series", 0)), int(aggregate.get("rounds", 0)),
		float(aggregate.get("average_rounds", 0.0)), float(aggregate.get("average_round_seconds", 0.0)),
		int(aggregate.get("highlights", 0)), int(aggregate.get("favorites", 0))
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
	lines.append("[color=#f4d477][font_size=18][b]SÉRIES ENCONTRADAS[/b][/font_size][/color]")
	if _visible_records.is_empty():
		lines.append("[color=#8b99ad]Nenhuma série corresponde aos filtros.[/color]")
	else:
		for index in range(_visible_records.size()):
			var prefix := "[color=#ffd36b]▶[/color]" if index == _selected_index else " "
			lines.append("%s %s" % [prefix, _history_line(_visible_records[index])])
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
	lines.append("[color=#8ecff0][b]ROUNDS E DESTAQUES[/b][/color]")
	for round_value in record.get("rounds", []):
		if round_value is Dictionary:
			var round_data: Dictionary = round_value
			lines.append("• Round %d — P%d • %s • %.1fs • %d momentos" % [
				int(round_data.get("round_number", 1)), int(round_data.get("winner_index", 1)),
				String(round_data.get("reason", "KO")), float(round_data.get("duration_seconds", 0.0)),
				(round_data.get("highlights", []) as Array).size()
			])
	return "\n".join(lines)

func _refresh_history() -> void:
	if not is_instance_valid(_report):
		return
	_report.text = build_history_report()
	_footer.text = "F3 fecha • Tab filtro • H/Y valor • Page Up/Down série • Enter replay • B favorita • Ctrl+1 Técnica • Ctrl+2 Revanche • Ctrl+3 Torneio • Ctrl+4 Destaque • Backspace limpa"

func _cycle_filter_value(direction: int) -> void:
	var field_id := FILTER_FIELDS[_filter_field_index]
	var options := _filter_options(field_id)
	var current := StringName(_filters.get(String(field_id), &"all"))
	var index := options.find(current)
	if index < 0:
		index = 0
	_filters[String(field_id)] = options[wrapi(index + direction, 0, options.size())]
	_selected_index = 0
	_refresh_history()

func _filter_options(field_id: StringName) -> Array[StringName]:
	match field_id:
		&"character_id":
			var characters: Array[StringName] = [&"all"]
			characters.append_array(BattleLoadoutCatalog.CHARACTER_ORDER)
			return characters
		&"arena_id":
			var arenas: Array[StringName] = [&"all"]
			arenas.append_array(CompetitiveMatchCatalog.ARENA_ORDER)
			return arenas
		&"result_id": return RESULT_OPTIONS.duplicate()
		&"curation_id": return MatchHistoryLedger.CURATION_FILTERS.duplicate()
		_: return [&"all"]

func _filter_summary() -> String:
	var parts: Array[String] = []
	for index in range(FILTER_FIELDS.size()):
		var field_id := FILTER_FIELDS[index]
		var marker := "▶" if index == _filter_field_index else " "
		parts.append("%s %s: %s" % [marker, _filter_field_label(field_id), _filter_value_label(field_id, StringName(_filters.get(String(field_id), &"all")))])
	return "    |    ".join(parts)

func _filter_field_label(field_id: StringName) -> String:
	match field_id:
		&"character_id": return "PERSONAGEM"
		&"arena_id": return "ARENA"
		&"result_id": return "RESULTADO"
		&"curation_id": return "CURADORIA"
		_: return String(field_id).to_upper()

func _filter_value_label(field_id: StringName, value_id: StringName) -> String:
	if value_id == &"all":
		return "TODOS"
	match field_id:
		&"character_id": return CharacterVisualCatalog.display_name(value_id).to_upper()
		&"arena_id": return CompetitiveMatchCatalog.value_label(&"arena_id", value_id)
		&"result_id":
			return {
				&"p1_win": "VITÓRIA P1", &"p2_win": "VITÓRIA P2", &"ko": "COM KO",
				&"time": "COM TEMPO", &"sudden_death": "COM PRORROGAÇÃO"
			}.get(value_id, String(value_id).to_upper())
		&"curation_id": return _tag_label(value_id) if value_id != &"favorites" else "FAVORITAS"
		_: return String(value_id).to_upper()

func _toggle_selected_favorite() -> void:
	var selected := selected_record()
	if selected.is_empty():
		return
	statistics_runtime.history.toggle_favorite(String(selected.get("match_id", "")))
	_refresh_history()

func _toggle_selected_tag(tag_id: StringName) -> void:
	var selected := selected_record()
	if selected.is_empty():
		return
	statistics_runtime.history.toggle_tag(String(selected.get("match_id", "")), tag_id)
	_refresh_history()

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
	var highlight_count := 0
	for round_value in record.get("rounds", []):
		if round_value is Dictionary:
			highlight_count += ((round_value as Dictionary).get("highlights", []) as Array).size()
	var favorite := "★ " if bool(record.get("favorite", false)) else ""
	var tags: Array[String] = []
	for value in record.get("tags", []):
		tags.append(_tag_label(StringName(value)))
	var tag_suffix := " • [%s]" % ", ".join(tags) if not tags.is_empty() else ""
	return "%s%s %d — %d %s • vencedor P%d • %s • %d rounds • %d destaques%s" % [
		favorite, p1, int(record.get("score_p1", 0)), int(record.get("score_p2", 0)), p2,
		int(record.get("winner_index", 0)), CompetitiveMatchCatalog.arena_label(config),
		(record.get("rounds", []) as Array).size(), highlight_count, tag_suffix
	]

func _tag_label(tag_id: StringName) -> String:
	return {
		&"technical": "TÉCNICA", &"rematch": "REVANCHE", &"tournament": "TORNEIO", &"highlight": "DESTAQUE"
	}.get(tag_id, String(tag_id).to_upper())

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
	_panel.offset_left = 70.0
	_panel.offset_top = 30.0
	_panel.offset_right = 1210.0
	_panel.offset_bottom = 696.0
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
	_title.add_theme_font_size_override("font_size", 23)
	_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.44))
	column.add_child(_title)
	_report = RichTextLabel.new()
	_report.custom_minimum_size = Vector2(1080.0, 540.0)
	_report.bbcode_enabled = true
	_report.fit_content = false
	_report.scroll_active = true
	_report.add_theme_font_size_override("normal_font_size", 13)
	_report.add_theme_font_size_override("bold_font_size", 14)
	column.add_child(_report)
	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_theme_font_size_override("font_size", 11)
	_footer.add_theme_color_override("font_color", Color(0.70, 0.80, 0.92))
	column.add_child(_footer)
	_canvas.visible = false

func _register_inputs() -> void:
	_add_key_action(&"history_toggle", KEY_F3)
	_add_key_action(&"history_next_filter", KEY_TAB)
	_add_key_action(&"history_prev_value", KEY_H)
	_add_key_action(&"history_next_value", KEY_Y)
	_add_key_action(&"history_prev_record", KEY_PAGEUP)
	_add_key_action(&"history_next_record", KEY_PAGEDOWN)
	_add_key_action(&"history_replay", KEY_ENTER)
	_add_key_action(&"history_reset_filters", KEY_BACKSPACE)
	_add_key_action(&"history_favorite", KEY_B)
	for index in range(4):
		_add_key_action(StringName("history_tag_%d" % (index + 1)), KEY_1 + index, true)

func _add_key_action(action_id: StringName, keycode: Key, ctrl_pressed: bool = false) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode and existing.ctrl_pressed == ctrl_pressed:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.ctrl_pressed = ctrl_pressed
	InputMap.action_add_event(action_id, event)
