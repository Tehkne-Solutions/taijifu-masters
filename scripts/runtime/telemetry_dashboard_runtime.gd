class_name TelemetryDashboardRuntime
extends Node

@onready var intelligence_runtime: PrototypeIntelligenceRuntime = get_node("../PrototypeIntelligenceRuntime")
@onready var hud: CanvasLayer = get_node("../HUD")

var _panel: PanelContainer
var _content: VBoxContainer
var _last_report: Dictionary = {}
var _last_saved_path := ""
var _auto_hide_timer := 0.0
var _pinned := false

func _ready() -> void:
	_register_toggle_action()
	_build_panel()
	intelligence_runtime.round_report_ready.connect(_on_round_report_ready)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"toggle_telemetry_dashboard"):
		if _last_report.is_empty():
			return
		_pinned = not _panel.visible
		_panel.visible = not _panel.visible
		if _panel.visible:
			_auto_hide_timer = 0.0

	if _auto_hide_timer > 0.0 and not _pinned:
		_auto_hide_timer = maxf(0.0, _auto_hide_timer - delta)
		if _auto_hide_timer <= 0.0:
			_panel.visible = false

func _on_round_report_ready(report: Dictionary, saved_path: String) -> void:
	_last_report = report.duplicate(true)
	_last_saved_path = saved_path
	_pinned = false
	_render_report()
	_panel.visible = true
	_auto_hide_timer = 2.05

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "TelemetryRoundPanel"
	_panel.offset_left = 160.0
	_panel.offset_top = 178.0
	_panel.offset_right = 1120.0
	_panel.offset_bottom = 618.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.96)
	style.border_color = Color(0.34, 0.57, 0.80, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	margin.add_child(_content)
	hud.add_child(_panel)

func _render_report() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var round_index := int(_last_report.get("round_index", 0))
	var duration_seconds := float(_last_report.get("duration_msec", 0)) / 1000.0
	var winner := String(_last_report.get("winner_profile_id", ""))
	var title := _make_label(
		"RELATÓRIO DO FLUXO • ROUND %d • %.1fs • VENCEDOR %s" % [
			round_index,
			duration_seconds,
			winner.to_upper() if winner != "" else "INDEFINIDO"
		],
		20,
		Color(0.95, 0.84, 0.48)
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var separator := HSeparator.new()
	_content.add_child(separator)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(columns)

	var players: Dictionary = _last_report.get("players", {})
	columns.add_child(_create_player_column(&"p1", players.get("p1", {}), winner == "p1"))
	columns.add_child(_create_player_column(&"p2", players.get("p2", {}), winner == "p2"))

	var footer := _make_label(
		"F2 mantém/abre o último relatório • JSON: %s" % (
			_last_saved_path.get_file() if _last_saved_path != "" else "não salvo"
		),
		11,
		Color(0.66, 0.72, 0.82)
	)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(footer)

func _create_player_column(profile_id: StringName, metrics_variant: Variant, is_winner: bool) -> VBoxContainer:
	var metrics: Dictionary = metrics_variant if metrics_variant is Dictionary else {}
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(425.0, 300.0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)

	var player_color := Color(0.54, 0.82, 1.0) if profile_id == &"p1" else Color(1.0, 0.64, 0.48)
	var heading := _make_label(
		"%s%s" % [String(profile_id).to_upper(), " • VITÓRIA" if is_winner else ""],
		17,
		player_color
	)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	var routes: Dictionary = metrics.get("route_seconds", {"tai": 0.0, "ji": 0.0, "fu": 0.0})
	var total_route := maxf(
		0.1,
		float(routes.get("tai", 0.0)) + float(routes.get("ji", 0.0)) + float(routes.get("fu", 0.0))
	)
	column.add_child(_route_bar("TAI", float(routes.get("tai", 0.0)), total_route, Color(0.28, 0.66, 1.0)))
	column.add_child(_route_bar("JI", float(routes.get("ji", 0.0)), total_route, Color(1.0, 0.40, 0.22)))
	column.add_child(_route_bar("FU", float(routes.get("fu", 0.0)), total_route, Color(0.68, 0.38, 1.0)))

	var counters: Dictionary = metrics.get("counters", {})
	var techniques := _counter_sum(counters, "technique_started:")
	var defended := (
		float(counters.get("technique_experienced:blocked", 0.0))
		+ float(counters.get("technique_experienced:parried", 0.0))
		+ float(counters.get("technique_experienced:evaded", 0.0))
	)
	var grabs := float(counters.get("grab_started", 0.0))
	var escapes := float(counters.get("grab_escaped", 0.0))
	var elements := _counter_sum(counters, "element_cast:")
	var interactions := _counter_sum(counters, "elemental_interaction:")

	var stats := _make_label(
		"TÉCNICAS %d   DEFESAS %d   AGARRÕES %d\nFUGAS %d   ELEMENTOS %d   INTERAÇÕES %d" % [
			roundi(techniques),
			roundi(defended),
			roundi(grabs),
			roundi(escapes),
			roundi(elements),
			roundi(interactions)
		],
		12,
		Color(0.84, 0.86, 0.91)
	)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(stats)

	var diagnosis := _diagnose_style(routes, counters)
	var diagnosis_label := _make_label("LEITURA: %s" % diagnosis, 13, player_color.lightened(0.12))
	diagnosis_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diagnosis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(diagnosis_label)
	return column

func _route_bar(route_label: String, seconds: float, total: float, route_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := _make_label(route_label, 12, route_color)
	label.custom_minimum_size = Vector2(34.0, 18.0)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = total
	bar.value = seconds
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(285.0, 16.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(route_color, 0.86)
	fill_style.set_corner_radius_all(5)
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.10, 0.12, 0.17, 0.92)
	background_style.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.add_theme_stylebox_override("background", background_style)
	row.add_child(bar)

	var seconds_label := _make_label("%.1fs" % seconds, 11, Color(0.76, 0.79, 0.85))
	seconds_label.custom_minimum_size = Vector2(48.0, 18.0)
	seconds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(seconds_label)
	return row

func _diagnose_style(routes: Dictionary, counters: Dictionary) -> String:
	var dominant_route := "FU"
	var dominant_seconds := -1.0
	for route_id in ["tai", "ji", "fu"]:
		var seconds := float(routes.get(route_id, 0.0))
		if seconds > dominant_seconds:
			dominant_seconds = seconds
			dominant_route = route_id.to_upper()

	var grabs := float(counters.get("grab_started", 0.0))
	var elements := _counter_sum(counters, "element_cast:")
	var defended := (
		float(counters.get("technique_experienced:blocked", 0.0))
		+ float(counters.get("technique_experienced:parried", 0.0))
		+ float(counters.get("technique_experienced:evaded", 0.0))
	)
	if grabs >= 2.0:
		return "%s • CONTROLADOR DE CONTATO" % dominant_route
	if elements >= 3.0:
		return "%s • TECELÃO DE CONDIÇÕES" % dominant_route
	if defended >= 3.0:
		return "%s • LEITOR ADAPTATIVO" % dominant_route
	return "%s • ESTRATÉGIA EM FORMAÇÃO" % dominant_route

func _counter_sum(counters: Dictionary, prefix: String) -> float:
	var total := 0.0
	for key_variant in counters.keys():
		var key := String(key_variant)
		if key.begins_with(prefix):
			total += float(counters[key_variant])
	return total

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _register_toggle_action() -> void:
	if not InputMap.has_action(&"toggle_telemetry_dashboard"):
		InputMap.add_action(&"toggle_telemetry_dashboard")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F2
	for existing in InputMap.action_get_events(&"toggle_telemetry_dashboard"):
		if existing is InputEventKey and existing.physical_keycode == KEY_F2:
			return
	InputMap.action_add_event(&"toggle_telemetry_dashboard", event)
