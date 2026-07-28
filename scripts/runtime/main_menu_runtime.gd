extends Node

signal menu_opened
signal preparation_requested(mode_id: String, options: Dictionary)
signal menu_closed
signal hub_navigation_requested(section_id: String)

const DEFAULT_MODE := "arena_loot"
const COLORS := {
	"ink": Color("1c1712"),
	"wood": Color("2f2118"),
	"wood_light": Color("473326"),
	"bronze": Color("a77b45"),
	"gold": Color("d5b06b"),
	"parchment": Color("ead8b6"),
	"muted": Color("b9a78e"),
	"shadow": Color(0.03, 0.02, 0.015, 0.94),
	"selected": Color("6d4f2f")
}

var _layer: CanvasLayer
var _selected_mode := DEFAULT_MODE
var _series_format := 3
var _options_panel: VBoxContainer
var _start_button: Button
var _mode_buttons: Dictionary = {}
var _hidden_for_hub := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("open_main_menu")

func open_main_menu() -> void:
	_close_existing()
	_pause_preparation()
	_hidden_for_hub = false
	_layer = CanvasLayer.new()
	_layer.name = "TaijifuMainMenu"
	_layer.layer = 400
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_layer)

	var shade := ColorRect.new()
	shade.color = COLORS.shadow
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.add_child(shade)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 42)
	frame.add_theme_constant_override("margin_top", 28)
	frame.add_theme_constant_override("margin_right", 42)
	frame.add_theme_constant_override("margin_bottom", 28)
	shade.add_child(frame)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	frame.add_child(root)
	root.add_child(_build_identity_panel())
	root.add_child(_build_mode_panel())
	_select_mode(DEFAULT_MODE)
	menu_opened.emit()

func _build_identity_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 620)
	panel.add_theme_stylebox_override("panel", _panel_style(COLORS.wood, COLORS.bronze, 3, 18))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var crest := Label.new()
	crest.text = "✦"
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", 30)
	crest.add_theme_color_override("font_color", COLORS.gold)
	box.add_child(crest)
	box.add_child(_label("TAIJIFU", 38, COLORS.parchment))
	box.add_child(_label("MASTERS", 22, COLORS.gold))
	box.add_child(_separator())

	var pitch := _label("Domine o corpo. Controle o fluxo. Conquiste a arena.", 16, COLORS.muted)
	pitch.custom_minimum_size = Vector2(300, 68)
	box.add_child(pitch)
	box.add_child(_label("SALA DOS MESTRES", 17, COLORS.gold))

	for section in [
		{"id":"profile", "label":"PERFIL E PROGRESSÃO", "hint":"Nível, vitórias e domínio"},
		{"id":"shop", "label":"LOJA DE TREINO", "hint":"Recompensas e melhorias"},
		{"id":"collection", "label":"COLEÇÃO", "hint":"Estandartes, auras e molduras"}
	]:
		var button := _menu_button(String(section.label), String(section.hint))
		var section_id := String(section.id)
		button.pressed.connect(func(): _open_hub_section(section_id))
		box.add_child(button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var footer := _label("TAI • JI • FU", 14, COLORS.bronze)
	box.add_child(footer)
	return panel

func _build_mode_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(760, 620)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("17130f"), COLORS.bronze, 2, 18))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var navigation := VBoxContainer.new()
	navigation.add_theme_constant_override("separation", 10)
	margin.add_child(navigation)
	navigation.add_child(_label("ESCOLHA SUA PROVA", 26, COLORS.parchment))
	navigation.add_child(_label("Cada modo testa uma face diferente do caminho do mestre.", 14, COLORS.muted))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation.add_child(grid)
	var mode_runtime := get_node_or_null("/root/GameModeRuntime")
	if mode_runtime != null:
		for mode_id in mode_runtime.available_modes():
			var config: Dictionary = mode_runtime.MODES[mode_id]
			var selected := String(mode_id)
			var button := _mode_card(String(config.get("label", mode_id)), String(config.get("description", "")))
			button.pressed.connect(func(): _select_mode(selected))
			grid.add_child(button)
			_mode_buttons[selected] = button

	_options_panel = VBoxContainer.new()
	_options_panel.add_theme_constant_override("separation", 8)
	navigation.add_child(_options_panel)
	_start_button = Button.new()
	_start_button.text = "ENTRAR NA PREPARAÇÃO"
	_start_button.custom_minimum_size = Vector2(0, 54)
	_start_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_start_button.add_theme_font_size_override("font_size", 18)
	_start_button.add_theme_color_override("font_color", COLORS.ink)
	_start_button.add_theme_stylebox_override("normal", _panel_style(COLORS.gold, COLORS.parchment, 2, 10))
	_start_button.add_theme_stylebox_override("hover", _panel_style(COLORS.parchment, COLORS.gold, 2, 10))
	_start_button.add_theme_stylebox_override("pressed", _panel_style(COLORS.bronze, COLORS.gold, 2, 10))
	_start_button.pressed.connect(_start_selected_mode)
	navigation.add_child(_start_button)
	return panel

func _menu_button(title: String, hint: String) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [title, hint]
	button.custom_minimum_size = Vector2(300, 58)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", COLORS.parchment)
	button.add_theme_stylebox_override("normal", _panel_style(COLORS.wood_light, COLORS.bronze, 1, 8))
	button.add_theme_stylebox_override("hover", _panel_style(COLORS.selected, COLORS.gold, 2, 8))
	return button

func _mode_card(title: String, description: String) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [title.to_upper(), description]
	button.custom_minimum_size = Vector2(340, 90)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", COLORS.parchment)
	button.add_theme_stylebox_override("normal", _panel_style(Color("241b15"), Color("6f5336"), 1, 10))
	button.add_theme_stylebox_override("hover", _panel_style(COLORS.wood_light, COLORS.gold, 2, 10))
	button.add_theme_stylebox_override("disabled", _panel_style(COLORS.selected, COLORS.gold, 3, 10))
	return button

func _open_hub_section(section_id: String) -> void:
	var hub := get_node_or_null("/root/MainMenuHubRuntime")
	if hub != null and hub.has_method("open_section") and hub.open_section(section_id):
		hub_navigation_requested.emit(section_id)

func hide_for_hub() -> void:
	_hidden_for_hub = true
	if is_instance_valid(_layer): _layer.visible = false

func restore_from_hub() -> void:
	_hidden_for_hub = false
	if is_instance_valid(_layer): _layer.visible = true
	else: open_main_menu()

func _select_mode(mode_id: String) -> void:
	var mode_runtime := get_node_or_null("/root/GameModeRuntime")
	if mode_runtime == null or not mode_runtime.MODES.has(mode_id): return
	_selected_mode = mode_id
	for id in _mode_buttons:
		var button: Button = _mode_buttons[id]
		button.disabled = String(id) == mode_id
	_build_mode_options()

func _build_mode_options() -> void:
	for child in _options_panel.get_children(): child.queue_free()
	var mode_runtime := get_node_or_null("/root/GameModeRuntime")
	if mode_runtime == null: return
	var config: Dictionary = mode_runtime.MODES[_selected_mode]
	_options_panel.add_child(_label("PROVA SELECIONADA • %s" % String(config.get("label", "MODO")).to_upper(), 16, COLORS.gold))
	if _selected_mode == "roguelite_series":
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for format in [3, 5]:
			var button := Button.new()
			button.text = "MELHOR DE %d" % format
			button.process_mode = Node.PROCESS_MODE_ALWAYS
			var chosen := int(format)
			button.disabled = _series_format == chosen
			button.pressed.connect(func(): _series_format = chosen; _build_mode_options())
			row.add_child(button)
		_options_panel.add_child(row)
	else:
		var detail := "Arena completa com tropas, pickups, raridades e sinergias."
		if _selected_mode == "competitive_duel": detail = "Sem tropas ou progressão. Vitória definida apenas pela técnica."
		elif _selected_mode == "training": detail = "Gravação, fantasmas, maestria e certificações em primeiro plano."
		elif _selected_mode == "champion_challenge": detail = "Tropas neutras e campeão ativo, com recursos estratégicos limitados."
		_options_panel.add_child(_label(detail, 14, COLORS.muted))

func _start_selected_mode() -> void:
	var mode_runtime := get_node_or_null("/root/GameModeRuntime")
	if mode_runtime == null or not mode_runtime.apply_mode(_selected_mode): return
	if _selected_mode == "roguelite_series":
		var series := get_node_or_null("/root/CompleteSeriesModeRuntime")
		if series != null: series.start_series(_series_format)
	preparation_requested.emit(_selected_mode, {"series_format": _series_format})
	_open_preparation()
	_close_existing()
	menu_closed.emit()

func return_to_menu() -> void:
	get_tree().paused = false
	open_main_menu()

func _pause_preparation() -> void:
	var scene := get_tree().current_scene
	if scene == null: return
	var preparation := scene.get_node_or_null("BattlePreparationRuntime")
	if preparation != null and preparation.has_method("close"): preparation.close()

func _open_preparation() -> void:
	var scene := get_tree().current_scene
	if scene == null: return
	var preparation := scene.get_node_or_null("BattlePreparationRuntime")
	if preparation != null and preparation.has_method("open"): preparation.open()

func _close_existing() -> void:
	if is_instance_valid(_layer): _layer.queue_free()
	_layer = null
	_mode_buttons.clear()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _separator() -> HSeparator:
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", 8)
	return line

func _panel_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func selected_mode() -> String: return _selected_mode
func selected_series_format() -> int: return _series_format
func is_menu_open() -> bool: return is_instance_valid(_layer) and not _hidden_for_hub
