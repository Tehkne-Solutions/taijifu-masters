extends Node

signal theme_applied(root_name: String)
signal transition_started(screen_name: String)
signal transition_finished(screen_name: String)

const GOLD := Color(0.86, 0.66, 0.24, 1.0)
const GOLD_BRIGHT := Color(1.0, 0.82, 0.38, 1.0)
const PARCHMENT := Color(0.91, 0.84, 0.66, 1.0)
const INK := Color(0.08, 0.055, 0.035, 1.0)
const WOOD := Color(0.18, 0.10, 0.055, 0.98)
const WOOD_HOVER := Color(0.28, 0.16, 0.075, 1.0)
const STONE := Color(0.075, 0.085, 0.09, 0.98)
const STONE_LIGHT := Color(0.13, 0.14, 0.145, 1.0)
const DANGER := Color(0.46, 0.12, 0.08, 1.0)

var _theme: Theme
var _scan_timer := 0.0
var _styled_roots: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_theme = _build_theme()
	_connect_navigation_signals()
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = 0.2
	_scan_and_style()

func _connect_navigation_signals() -> void:
	var menu := get_node_or_null("/root/MainMenuRuntime")
	if menu != null:
		if menu.has_signal("menu_opened"):
			menu.menu_opened.connect(func(): call_deferred("_animate_named_layer", "TaijifuMainMenu"))
	var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
	if profile != null and profile.has_signal("profile_opened"):
		profile.profile_opened.connect(func(): call_deferred("_animate_profile_layer"))
	var collection := get_node_or_null("/root/CosmeticCollectionRuntime")
	if collection != null and collection.has_signal("collection_opened"):
		collection.collection_opened.connect(func(): call_deferred("_animate_collection_layer"))

func _scan_and_style() -> void:
	for child in get_tree().root.get_children():
		if child is CanvasLayer:
			_style_canvas_layer(child)

func _style_canvas_layer(layer: CanvasLayer) -> void:
	var key := str(layer.get_instance_id())
	if _styled_roots.has(key):
		_style_new_descendants(layer)
		return
	_styled_roots[key] = true
	_style_new_descendants(layer)
	theme_applied.emit(layer.name)

func _style_new_descendants(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			_style_control(child)
		_style_new_descendants(child)

func _style_control(control: Control) -> void:
	if control.has_meta("taijifu_medieval_styled"):
		return
	control.set_meta("taijifu_medieval_styled", true)
	if control is Button:
		_style_button(control)
	elif control is PanelContainer or control is Panel:
		control.add_theme_stylebox_override("panel", _panel_style())
	elif control is Label:
		_style_label(control)
	elif control is ScrollContainer:
		control.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.025, 0.022, 0.75), 2))

func _style_button(button: Button) -> void:
	button.theme = _theme
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.44, 0.36, 1.0))
	button.add_theme_font_size_override("font_size", max(15, button.get_theme_font_size("font_size")))
	button.focus_entered.connect(_on_button_focus.bind(button))
	button.focus_exited.connect(_on_button_unfocus.bind(button))
	button.mouse_entered.connect(_on_button_focus.bind(button))
	button.mouse_exited.connect(_on_button_unfocus.bind(button))

func _style_label(label: Label) -> void:
	if label.get_theme_font_size("font_size") >= 24:
		label.add_theme_color_override("font_color", GOLD_BRIGHT)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
	else:
		label.add_theme_color_override("font_color", PARCHMENT)

func _on_button_focus(button: Button) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.018, 1.018), 0.10)

func _on_button_unfocus(button: Button) -> void:
	if not is_instance_valid(button):
		return
	var tween := button.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.10)

func _build_theme() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _button_style(WOOD, GOLD, 2))
	theme.set_stylebox("hover", "Button", _button_style(WOOD_HOVER, GOLD_BRIGHT, 3))
	theme.set_stylebox("focus", "Button", _button_style(WOOD_HOVER, GOLD_BRIGHT, 4))
	theme.set_stylebox("pressed", "Button", _button_style(Color(0.12, 0.065, 0.035, 1.0), GOLD_BRIGHT, 3))
	theme.set_stylebox("disabled", "Button", _button_style(Color(0.09, 0.075, 0.06, 0.85), Color(0.3, 0.27, 0.22, 1.0), 1))
	theme.set_constant("outline_size", "Button", 1)
	theme.set_color("font_outline_color", "Button", INK)
	return theme

func _button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	return style

func _panel_style(background: Color = STONE, border_width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = GOLD
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.68)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	return style

func _animate_named_layer(layer_name: String) -> void:
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.name == layer_name:
			_animate_layer(child, layer_name)
			return

func _animate_profile_layer() -> void:
	var profile := get_node_or_null("/root/PlayerProgressionProfileRuntime")
	if profile != null:
		var layer: CanvasLayer = profile.get("_layer")
		if is_instance_valid(layer):
			_animate_layer(layer, "profile")

func _animate_collection_layer() -> void:
	var collection := get_node_or_null("/root/CosmeticCollectionRuntime")
	if collection != null:
		var layer: CanvasLayer = collection.get("_layer")
		if is_instance_valid(layer):
			_animate_layer(layer, "collection")

func _animate_layer(layer: CanvasLayer, screen_name: String) -> void:
	if not is_instance_valid(layer):
		return
	transition_started.emit(screen_name)
	for child in layer.get_children():
		if child is CanvasItem:
			child.modulate.a = 0.0
			var tween := child.create_tween()
			tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(child, "modulate:a", 1.0, 0.22)
	await get_tree().create_timer(0.24, true).timeout
	transition_finished.emit(screen_name)

func theme_snapshot() -> Dictionary:
	return {
		"palette": ["gold", "parchment", "wood", "stone"],
		"button_states": ["normal", "hover", "focus", "pressed", "disabled"],
		"transition_duration": 0.22,
		"gamepad_focus": true
	}
