class_name FirstPlayableCombatGuide
extends Control

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor_top = 1.0
	offset_left = 22.0
	offset_top = -92.0
	offset_right = -22.0
	offset_bottom = -18.0
	_build()

func _build() -> void:
	var panel := PanelContainer.new()
	panel.name = "CombatGuidePanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(POLICY.INK, 0.78)
	panel_style.border_color = Color(POLICY.GOLD, 0.34)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(5)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var row := HBoxContainer.new()
	row.name = "CombatGuideRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	_add_chip(row, "A/D", "MOVER", POLICY.BONE)
	_add_chip(row, "W", "PULAR", POLICY.ROUTE_TAI)
	_add_chip(row, "F", "GOLPE", POLICY.GOLD)
	_add_chip(row, "G", "IMPULSO", POLICY.ROUTE_JI)
	_add_chip(row, "E", "AGARRAR", POLICY.EMBER)
	_add_chip(row, "Q", "ESQUIVA", POLICY.JADE)
	_add_chip(row, "R", "GUARDA", POLICY.BONE)

func _add_chip(parent: HBoxContainer, key_text: String, action_text: String, accent: Color) -> void:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	parent.add_child(chip)

	var key := Label.new()
	key.custom_minimum_size = Vector2(34.0, 28.0)
	key.text = key_text
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 12)
	key.add_theme_color_override("font_color", POLICY.INK)
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = accent
	key_style.set_corner_radius_all(3)
	key.add_theme_stylebox_override("normal", key_style)
	chip.add_child(key)

	var action := Label.new()
	action.text = action_text
	action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action.add_theme_font_size_override("font_size", 10)
	action.add_theme_color_override("font_color", Color(POLICY.BONE, 0.92))
	chip.add_child(action)

func presentation_signature() -> Dictionary:
	return {
		"persistent_compact_controls": true,
		"primary_attack_visible": true,
		"movement_visible": true,
		"jump_visible": true,
		"defense_visible": true,
		"stick_fighter_readability": true,
		"site_panel": false,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
