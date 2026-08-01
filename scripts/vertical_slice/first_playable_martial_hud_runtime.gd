extends Node

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")

var _root: Node
var _combo: FirstPlayableComboRuntime
var _layer: CanvasLayer
var _strip: Label
var _legacy_hidden := false

func _ready() -> void:
	process_priority = 40
	_root = get_parent()
	_build_strip()

func _process(_delta: float) -> void:
	_resolve_combo()
	_hide_legacy_panel()
	_update_strip()

func _resolve_combo() -> void:
	if is_instance_valid(_combo) or not is_instance_valid(_root):
		return
	var candidate := _root.get_node_or_null("FirstPlayableComboRuntime")
	if candidate is FirstPlayableComboRuntime:
		_combo = candidate as FirstPlayableComboRuntime

func _build_strip() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "MartialHudLayer"
	_layer.layer = 11
	add_child(_layer)
	_strip = Label.new()
	_strip.name = "MartialCodeStrip"
	_strip.position = Vector2(340.0, 108.0)
	_strip.size = Vector2(600.0, 34.0)
	_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_strip.add_theme_font_size_override("font_size", 12)
	_strip.add_theme_color_override("font_color", POLICY.BONE)
	_strip.add_theme_color_override("font_shadow_color", Color(POLICY.INK.r, POLICY.INK.g, POLICY.INK.b, 0.92))
	_strip.add_theme_constant_override("shadow_offset_x", 1)
	_strip.add_theme_constant_override("shadow_offset_y", 2)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(POLICY.INK.r, POLICY.INK.g, POLICY.INK.b, 0.56)
	style.border_color = Color(POLICY.GOLD.r, POLICY.GOLD.g, POLICY.GOLD.b, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_strip.add_theme_stylebox_override("normal", style)
	_layer.add_child(_strip)

func _hide_legacy_panel() -> void:
	if _legacy_hidden or not is_instance_valid(_root):
		return
	var hud := _root.get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	var old_panel := hud.get_node_or_null("MartialFlowPanel") as Control
	if old_panel:
		old_panel.visible = false
		_legacy_hidden = true

func _update_strip() -> void:
	if not is_instance_valid(_strip):
		return
	if not is_instance_valid(_combo):
		_strip.text = ""
		return
	var hits := int(_combo.get("_combo_hits"))
	var flow := int(round(float(_combo.get("_flow"))))
	var code_variant: Variant = _combo.get("_code_families")
	var code: Array[StringName] = []
	if code_variant is Array:
		for family in code_variant:
			code.append(StringName(family))
	var parts: Array[String] = []
	for family in code:
		parts.append(_family_label(family))
	var code_text := "—" if parts.is_empty() else " › ".join(parts)
	var resonance := _resonance_for(code)
	var segments: Array[String] = []
	if hits > 1:
		segments.append("%d COMBO" % hits)
	segments.append(code_text)
	segments.append("FLUXO %d%%" % flow)
	if not resonance.is_empty():
		segments.append(resonance)
	_strip.text = "   •   ".join(segments)
	_strip.add_theme_color_override("font_color", POLICY.GOLD if flow >= 60 else POLICY.BONE)

func _resonance_for(code: Array[StringName]) -> String:
	if code.is_empty():
		return ""
	var tail: Array[String] = []
	var start := maxi(0, code.size() - 2)
	for index in range(start, code.size()):
		tail.append(String(code[index]))
	var prefix := ">".join(tail)
	var matches: Array[String] = []
	var recipes := {
		"tai>ji>tai": "FOGO",
		"ji>ji>fu": "TERRA",
		"fu>tai>fu": "ÁGUA",
		"tai>fu>tai": "AR",
	}
	for key in recipes.keys():
		if String(key).begins_with(prefix):
			matches.append(String(recipes[key]))
	return matches[0] if matches.size() == 1 else ("INSTÁVEL" if matches.size() > 1 else "")

func _family_label(family: StringName) -> String:
	match family:
		&"tai": return "TAI"
		&"ji": return "JI"
		&"fu": return "FU"
		_: return "—"

func presentation_signature() -> Dictionary:
	return {
		"compact_martial_strip": true,
		"legacy_debug_panel_hidden": true,
		"combo_visible_when_relevant": true,
		"martial_code_visible": true,
		"flow_visible": true,
		"resonance_visible": true,
		"single_line_fight_ui": true,
		"site_like_panel": false,
		"logic_changes": false,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
