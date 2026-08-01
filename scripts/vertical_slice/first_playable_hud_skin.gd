class_name FirstPlayableHudSkin
extends RefCounted

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")
const INK := POLICY.INK
const INK_SOFT := POLICY.INK_SOFT
const JADE := POLICY.JADE
const EMBER := POLICY.EMBER
const GOLD := POLICY.GOLD
const BONE := POLICY.BONE

static func apply(root: Node) -> void:
	var hud := root.get_node_or_null("../HUD") as CanvasLayer
	if hud == null:
		return
	_layout_fight_hud(hud)
	_style_shades(hud)
	_style_labels(hud)
	_style_bars(hud)
	_style_panels(hud)
	_style_buttons(hud)

static func presentation_signature() -> Dictionary:
	return {
		"direction": POLICY.UI_READ,
		"visual_policy": POLICY.DIRECTION,
		"fighter_identity_colors": 2,
		"resource_bar_roles": 3,
		"ornamental_panels": true,
		"compact_fight_hud": true,
		"persistent_help_removed": true,
		"qa_controls_collapsed": true,
		"generic_dark_strip_removed": true,
		"site_like_panels": false,
		"purple_tech_glow": false,
		"logic_changes": false,
		"signature": "Tehkné Solutions"
	}

static func _layout_fight_hud(hud: CanvasLayer) -> void:
	var top := hud.get_node_or_null("TopShade") as ColorRect
	if top:
		top.position = Vector2.ZERO
		top.size = Vector2(1280, 116)

	var bottom := hud.get_node_or_null("BottomShade") as ColorRect
	if bottom:
		bottom.visible = false

	var controls := hud.get_node_or_null("Controls") as Label
	if controls:
		controls.visible = false

	var difficulty := hud.get_node_or_null("DifficultyInfo") as Label
	if difficulty:
		difficulty.visible = false

	var p1 := hud.get_node_or_null("PlayerOne") as Label
	if p1:
		p1.position = Vector2(24, 10)
		p1.size = Vector2(354, 38)
	var p2 := hud.get_node_or_null("PlayerTwo") as Label
	if p2:
		p2.position = Vector2(902, 10)
		p2.size = Vector2(354, 38)

	_set_rect(hud, "P1Health", Rect2(24, 50, 354, 16))
	_set_rect(hud, "P1Posture", Rect2(24, 72, 354, 9))
	_set_rect(hud, "P1Stamina", Rect2(24, 87, 354, 7))
	_set_rect(hud, "P2Health", Rect2(902, 50, 354, 16))
	_set_rect(hud, "P2Posture", Rect2(902, 72, 354, 9))
	_set_rect(hud, "P2Stamina", Rect2(902, 87, 354, 7))

	var center := hud.get_node_or_null("CenterInfo") as Label
	if center:
		center.position = Vector2(470, 8)
		center.size = Vector2(340, 58)
	var state := hud.get_node_or_null("StateInfo") as Label
	if state:
		state.position = Vector2(470, 67)
		state.size = Vector2(340, 28)

static func _set_rect(hud: CanvasLayer, path: String, rect: Rect2) -> void:
	var control := hud.get_node_or_null(path) as Control
	if control == null:
		return
	control.position = rect.position
	control.size = rect.size

static func _style_shades(hud: CanvasLayer) -> void:
	var top := hud.get_node_or_null("TopShade") as ColorRect
	if top:
		top.color = Color(INK, 0.76)

static func _style_labels(hud: CanvasLayer) -> void:
	_set_label(hud, "PlayerOne", Color(0.62, 0.88, 0.76), 18)
	_set_label(hud, "PlayerTwo", Color(0.98, 0.62, 0.40), 18)
	_set_label(hud, "CenterInfo", GOLD, 24)
	_set_label(hud, "StateInfo", BONE, 11)
	_set_label(hud, "DifficultyInfo", GOLD.lightened(0.08), 11)
	_set_label(hud, "Controls", Color(0.82, 0.82, 0.78), 11)

static func _set_label(hud: CanvasLayer, path: String, color: Color, size: int) -> void:
	var label := hud.get_node_or_null(path) as Label
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.78))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", size)

static func _style_bars(hud: CanvasLayer) -> void:
	_style_bar(hud.get_node_or_null("P1Health") as ProgressBar, JADE)
	_style_bar(hud.get_node_or_null("P1Posture") as ProgressBar, GOLD)
	_style_bar(hud.get_node_or_null("P1Stamina") as ProgressBar, Color(0.50, 0.70, 0.76))
	_style_bar(hud.get_node_or_null("P2Health") as ProgressBar, EMBER)
	_style_bar(hud.get_node_or_null("P2Posture") as ProgressBar, GOLD)
	_style_bar(hud.get_node_or_null("P2Stamina") as ProgressBar, Color(0.66, 0.55, 0.72))

static func _style_bar(bar: ProgressBar, fill: Color) -> void:
	if bar == null:
		return
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.016, 0.018, 0.018, 0.94)
	background.border_color = Color(0.46, 0.38, 0.24, 0.72)
	background.set_border_width_all(1)
	background.set_corner_radius_all(2)
	var progress := StyleBoxFlat.new()
	progress.bg_color = fill
	progress.border_color = fill.lightened(0.20)
	progress.set_border_width_all(1)
	progress.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", progress)

static func _style_panels(hud: CanvasLayer) -> void:
	for panel_path in ["ResultOverlay/Panel", "PauseOverlay/Panel"]:
		var panel := hud.get_node_or_null(panel_path) as PanelContainer
		if panel == null:
			continue
		var style := StyleBoxFlat.new()
		style.bg_color = INK_SOFT
		style.border_color = Color(GOLD, 0.74)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.shadow_color = Color(0, 0, 0, 0.62)
		style.shadow_size = 14
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 18
		style.content_margin_bottom = 18
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
		button.add_theme_stylebox_override("normal", _button_box(Color(0.10, 0.105, 0.10, 0.98), Color(GOLD, 0.48)))
		button.add_theme_stylebox_override("hover", _button_box(Color(0.16, 0.17, 0.15, 0.99), GOLD))
		button.add_theme_stylebox_override("pressed", _button_box(Color(0.10, 0.25, 0.20, 0.99), JADE))
		button.add_theme_stylebox_override("focus", _button_box(Color(0.14, 0.14, 0.13, 0.99), Color(GOLD, 0.94)))

static func _button_box(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

# Tehkné Solutions
