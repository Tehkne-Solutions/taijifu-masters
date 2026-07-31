extends Node

signal menu_opened
signal preparation_requested(mode_id: String, options: Dictionary)
signal menu_closed
signal hub_navigation_requested(section_id: String)

const DEFAULT_MODE := "competitive_duel"
const COLORS := {
	"ink": Color("0d0b09"),
	"panel": Color("18130f"),
	"hover": Color("2a2119"),
	"gold": Color("d5b06b"),
	"bone": Color("ead8b6"),
	"muted": Color("b9a78e"),
	"shadow": Color(0.02, 0.015, 0.01, 0.94)
}

var _layer: CanvasLayer
var _selected_mode := DEFAULT_MODE
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
	_layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 500)
	panel.add_theme_stylebox_override("panel", _panel_style(COLORS.panel, COLORS.gold, 2, 20))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 38)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	box.add_child(_label("太極", 34, COLORS.gold))
	box.add_child(_label("TAIJIFU MASTERS", 34, COLORS.bone))
	box.add_child(_label("FIRST PLAYABLE", 13, COLORS.muted))
	box.add_child(_button("JOGAR", "Combate direto contra a IA", DEFAULT_MODE, true))
	box.add_child(_button("TREINO", "Pratique movimentos e técnicas", "training", false))

	var options := _button("OPÇÕES", "Controles e acessibilidade", "", false)
	options.pressed.connect(_open_options)
	box.add_child(options)
	box.add_child(_label("TAI • JI • FU", 13, COLORS.muted))
	menu_opened.emit()

func _button(title: String, hint: String, mode_id: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [title, hint]
	button.custom_minimum_size = Vector2(376, 72)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", COLORS.ink if primary else COLORS.bone)
	button.add_theme_stylebox_override("normal", _panel_style(COLORS.gold if primary else COLORS.hover, COLORS.gold, 1, 10))
	button.add_theme_stylebox_override("hover", _panel_style(COLORS.bone if primary else Color("3a2b20"), COLORS.gold, 2, 10))
	if not mode_id.is_empty():
		button.pressed.connect(func(): _start_mode(mode_id))
	return button

func _start_mode(mode_id: String) -> void:
	var runtime := get_node_or_null("/root/GameModeRuntime")
	if runtime == null or not runtime.MODES.has(mode_id) or not runtime.apply_mode(mode_id):
		return
	_selected_mode = mode_id
	preparation_requested.emit(mode_id, {})
	_open_preparation()
	_close_existing()
	menu_closed.emit()

func _open_options() -> void:
	var hub := get_node_or_null("/root/MainMenuHubRuntime")
	if hub != null and hub.has_method("open_section") and hub.open_section("settings"):
		hub_navigation_requested.emit("settings")

func hide_for_hub() -> void:
	_hidden_for_hub = true
	if is_instance_valid(_layer): _layer.visible = false

func restore_from_hub() -> void:
	_hidden_for_hub = false
	if is_instance_valid(_layer): _layer.visible = true
	else: open_main_menu()

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

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func selected_mode() -> String: return _selected_mode
func selected_series_format() -> int: return 3
func is_menu_open() -> bool: return is_instance_valid(_layer) and not _hidden_for_hub

# Tehkné Solutions
