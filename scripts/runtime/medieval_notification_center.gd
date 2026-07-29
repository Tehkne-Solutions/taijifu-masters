extends Node

const MAX_ENTRIES := 12
const BASE_BATTLE_TITLE := "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"

@onready var _hud: CanvasLayer = get_node("../HUD")
@onready var _source_label: Label = get_node("../HUD/CenterInfo")

var _root: Control
var _toggle_button: Button
var _panel: PanelContainer
var _history_label: RichTextLabel
var _empty_label: Label
var _toast: PanelContainer
var _toast_label: Label
var _entries: Array[String] = []
var _last_source_text := ""
var _battle_mode := false
var _panel_open := false
var _toast_sequence := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	_build_interface()
	_last_source_text = _source_label.text

func _process(_delta: float) -> void:
	if not is_instance_valid(_source_label):
		return
	var current := _source_label.text.strip_edges()
	if current == _last_source_text:
		return
	_last_source_text = current
	_capture_source_message(current)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_notification_center"):
		_set_panel_open(not _panel_open)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and _panel_open:
		_set_panel_open(false)
		get_viewport().set_input_as_handled()

func _capture_source_message(message: String) -> void:
	if message.is_empty():
		return
	if message == BASE_BATTLE_TITLE:
		_battle_mode = true
		_source_label.visible = false
		return
	if not _battle_mode:
		_source_label.visible = true
		return
	_source_label.visible = false
	_push_notification(message)

func _push_notification(message: String) -> void:
	var normalized := message.replace("\n", " • ").strip_edges()
	if normalized.is_empty():
		return
	if not _entries.is_empty() and _entries[0] == normalized:
		_show_toast(normalized)
		return
	_entries.push_front(normalized)
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)
	_refresh_history()
	_show_toast(normalized)

func _build_interface() -> void:
	_root = Control.new()
	_root.name = "MedievalNotificationCenter"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_root)

	_toggle_button = Button.new()
	_toggle_button.anchor_left = 1.0
	_toggle_button.anchor_right = 1.0
	_toggle_button.offset_left = -112.0
	_toggle_button.offset_top = 178.0
	_toggle_button.offset_right = -18.0
	_toggle_button.offset_bottom = 216.0
	_toggle_button.text = "SINOS 0"
	_toggle_button.tooltip_text = "Abrir o registro de acontecimentos [N]"
	_toggle_button.focus_mode = Control.FOCUS_NONE
	_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_button.add_theme_font_size_override("font_size", 11)
	_toggle_button.add_theme_color_override("font_color", Color(0.95, 0.84, 0.56))
	_toggle_button.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.075, 0.035, 0.96), Color(0.62, 0.43, 0.19)))
	_toggle_button.add_theme_stylebox_override("hover", _button_style(Color(0.19, 0.12, 0.055, 0.98), Color(0.88, 0.66, 0.28)))
	_toggle_button.pressed.connect(_on_toggle_pressed)
	_root.add_child(_toggle_button)

	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -368.0
	_panel.offset_top = 224.0
	_panel.offset_right = -18.0
	_panel.offset_bottom = 602.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "CRÔNICAS DA BATALHA"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.48))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "FECHAR"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 10)
	close_button.pressed.connect(func() -> void: _set_panel_open(false))
	header.add_child(close_button)

	var divider := HSeparator.new()
	column.add_child(divider)

	_history_label = RichTextLabel.new()
	_history_label.bbcode_enabled = true
	_history_label.scroll_active = true
	_history_label.custom_minimum_size = Vector2(0.0, 262.0)
	_history_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_label.add_theme_font_size_override("normal_font_size", 12)
	_history_label.add_theme_color_override("default_color", Color(0.88, 0.82, 0.68))
	column.add_child(_history_label)

	_empty_label = Label.new()
	_empty_label.text = "Nenhum acontecimento registrado."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 12)
	_empty_label.add_theme_color_override("font_color", Color(0.64, 0.58, 0.47))
	column.add_child(_empty_label)

	var clear_button := Button.new()
	clear_button.text = "LIMPAR CRÔNICAS"
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.pressed.connect(_clear_history)
	column.add_child(clear_button)

	_toast = PanelContainer.new()
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -250.0
	_toast.offset_top = 176.0
	_toast.offset_right = 250.0
	_toast.offset_bottom = 222.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_stylebox_override("panel", _toast_style())
	_root.add_child(_toast)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 13)
	_toast_label.add_theme_color_override("font_color", Color(0.98, 0.89, 0.66))
	_toast.add_child(_toast_label)

	_panel.visible = false
	_toast.visible = false
	_refresh_history()

func _on_toggle_pressed() -> void:
	_set_panel_open(not _panel_open)

func _set_panel_open(open: bool) -> void:
	_panel_open = open
	_panel.visible = open
	_toggle_button.text = ("FECHAR" if open else "SINOS %d" % _entries.size())

func _clear_history() -> void:
	_entries.clear()
	_refresh_history()

func _refresh_history() -> void:
	if not is_instance_valid(_history_label):
		return
	var lines: Array[String] = []
	for index in range(_entries.size()):
		var marker := "◆" if index == 0 else "•"
		var color := "#f4cf78" if index == 0 else "#c9b78e"
		lines.append("[color=%s]%s %s[/color]" % [color, marker, _entries[index]])
	_history_label.text = "\n\n".join(lines)
	_empty_label.visible = _entries.is_empty()
	_history_label.visible = not _entries.is_empty()
	if is_instance_valid(_toggle_button) and not _panel_open:
		_toggle_button.text = "SINOS %d" % _entries.size()

func _show_toast(message: String) -> void:
	_toast_sequence += 1
	var sequence := _toast_sequence
	_toast_label.text = message
	_toast.visible = true
	await get_tree().create_timer(1.35, true, false, true).timeout
	if sequence == _toast_sequence:
		_toast.visible = false

func _register_input() -> void:
	if InputMap.has_action(&"toggle_notification_center"):
		return
	InputMap.add_action(&"toggle_notification_center", 0.5)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_N
	InputMap.action_add_event(&"toggle_notification_center", event)

func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.047, 0.024, 0.985)
	style.border_color = Color(0.66, 0.46, 0.21, 0.98)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 10
	return style

func _toast_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.067, 0.028, 0.96)
	style.border_color = Color(0.82, 0.61, 0.25, 0.98)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style
