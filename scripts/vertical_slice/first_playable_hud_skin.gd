class_name FirstPlayableHudSkin
extends RefCounted

const INK := Color(0.035, 0.04, 0.055, 0.96)
const INK_SOFT := Color(0.065, 0.075, 0.095, 0.92)
const JADE := Color(0.18, 0.66, 0.58, 1.0)
const EMBER := Color(0.90, 0.28, 0.16, 1.0)
const GOLD := Color(0.93, 0.72, 0.28, 1.0)
const BONE := Color(0.92, 0.88, 0.78, 1.0)

static func apply(root: Node) -> void:
	var hud := root.get_node_or_null("../HUD") as CanvasLayer
	if hud == null:
		return
	_style_shades(hud)
	_style_labels(hud)
	_style_bars(hud)
	_style_panels(hud)
	_style_buttons(hud)

static func presentation_signature() -> Dictionary:
	return {
		"direction": &"martial_fantasy_ink",
		"fighter_identity_colors": 2,
		"resource_bar_roles": 3,
		"ornamental_panels": true,
		"generic_dark_strip_removed": true,
		"purple_tech_glow": false,
		"logic_changes": false,
		"signature": "Tehkné Solutions"
	}

static func _style_shades(hud: CanvasLayer) -> void:
	var top := hud.get_node_or_null("TopShade") as ColorRect
	var bottom := hud.get_node_or_null("BottomShade") as ColorRect
	if top:
		top.color = Color(INK, 0.84)
	if bottom:
		bottom.color = Color(INK, 0.72)

static func _style_labels(hud: CanvasLayer) -> void:
	_set_label(hud, "PlayerOne", Color(0.58, 0.90, 0.86), 17)
	_set_label(hud, "PlayerTwo", Color(1.0, 0.64, 0.46), 17)
	_set_label(hud, "CenterInfo", GOLD, 27)
	_set_label(hud, "StateInfo", BONE, 11)
	_set_label(hud, "DifficultyInfo", GOLD.lightened(0.08), 11)
	_set_label(hud, "Controls", Color(0.82, 0.82, 0.78), 11)

static func _set_label(hud: CanvasLayer, path: String, color: Color, size: int) -> void:
	var label := hud.get_node_or_null(path) as Label
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", size)

static func _style_bars(hud: CanvasLayer) -> void:
	_style_bar(hud.get_node_or_null("P1Health") as ProgressBar, JADE)
	_style_bar(hud.get_node_or_null("P1Posture") as ProgressBar, GOLD)
	_style_bar(hud.get_node_or_null("P1Stamina") as ProgressBar, Color(0.52, 0.76, 0.88))
	_style_bar(hud.get_node_or_null("P2Health") as ProgressBar, EMBER)
	_style_bar(hud.get_node_or_null("P2Posture") as ProgressBar, GOLD)
	_style_bar(hud.get_node_or_null("P2Stamina") as ProgressBar, Color(0.70, 0.60, 0.86))

static func _style_bar(bar: ProgressBar, fill: Color) -> void:
	if bar == null:
		return
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.028, 0.035, 0.94)
	background.border_color = Color(0.52, 0.43, 0.28, 0.62)
	background.set_border_width_all(1)
	background.corner_radius_top_left = 3
	background.corner_radius_top_right = 3
	background.corner_radius_bottom_left = 3
	background.corner_radius_bottom_right = 3
	var progress := StyleBoxFlat.new()
	progress.bg_color = fill
	progress.border_color = fill.lightened(0.28)
	progress.set_border_width_all(1)
	progress.corner_radius_top_left = 3
	progress.corner_radius_top_right = 3
	progress.corner_radius_bottom_left = 3
	progress.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", progress)

static func _style_panels(hud: CanvasLayer) -> void:
	for panel_path in ["ResultOverlay/Panel", "PauseOverlay/Panel"]:
		var panel := hud.get_node_or_null(panel_path) as PanelContainer
		if panel == null:
			continue
		var style := StyleBoxFlat.new()
		style.bg_color = INK_SOFT
		style.border_color = Color(GOLD, 0.72)
		style.set_border_width_all(2)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.shadow_color = Color(0, 0, 0, 0.58)
		style.shadow_size = 18
		style.content_margin_left = 28
		style.content_margin_right = 28
		style.content_margin_top = 22
		style.content_margin_bottom = 22
		panel.add_theme_stylebox_override("panel", style)

static func _style_buttons(hud: CanvasLayer) -> void:
	for node in hud.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		button.add_theme_color_override("font_color", BONE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_font_size_override("font_size", maxi(11, button.get_theme_font_size("font_size")))
		button.add_theme_stylebox_override("normal", _button_box(Color(0.12, 0.13, 0.15, 0.96), Color(GOLD, 0.55)))
		button.add_theme_stylebox_override("hover", _button_box(Color(0.18, 0.20, 0.21, 0.98), GOLD))
		button.add_theme_stylebox_override("pressed", _button_box(Color(0.10, 0.28, 0.25, 0.98), JADE))
		button.add_theme_stylebox_override("focus", _button_box(Color(0.15, 0.16, 0.18, 0.98), Color(GOLD, 0.95)))

static func _button_box(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 6
	box.corner_radius_bottom_left = 6
	box.corner_radius_bottom_right = 6
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

# Tehkné Solutions