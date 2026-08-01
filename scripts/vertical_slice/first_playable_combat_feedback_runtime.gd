extends Node

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")
const FEEDBACK_LIFETIME := 0.72
const COMBO_RESET_SECONDS := 1.10

var _root: Node
var _p1: MasteredWeaponFighterController
var _p2: MasteredWeaponFighterController
var _layer: CanvasLayer
var _center_label: Label
var _p1_label: Label
var _p2_label: Label
var _combo_labels: Dictionary = {}
var _combo_counts: Dictionary = {"p1": 0, "p2": 0}
var _combo_timers: Dictionary = {"p1": 0.0, "p2": 0.0}

func _ready() -> void:
	process_priority = 35
	_root = get_parent()
	_build_feedback_layer()

func _process(delta: float) -> void:
	_resolve_fighters()
	for profile_id in ["p1", "p2"]:
		_combo_timers[profile_id] = maxf(0.0, float(_combo_timers.get(profile_id, 0.0)) - delta)
		if float(_combo_timers.get(profile_id, 0.0)) <= 0.0 and int(_combo_counts.get(profile_id, 0)) > 0:
			_combo_counts[profile_id] = 0
			_update_combo_label(profile_id)

func _resolve_fighters() -> void:
	if not is_instance_valid(_root):
		return
	if not is_instance_valid(_p1):
		var p1_candidate: Variant = _root.get("player_one")
		if p1_candidate is MasteredWeaponFighterController:
			_p1 = p1_candidate as MasteredWeaponFighterController
			_connect_fighter(_p1)
	if not is_instance_valid(_p2):
		var p2_candidate: Variant = _root.get("player_two")
		if p2_candidate is MasteredWeaponFighterController:
			_p2 = p2_candidate as MasteredWeaponFighterController
			_connect_fighter(_p2)

func _connect_fighter(fighter: MasteredWeaponFighterController) -> void:
	if not fighter.impact_resolved.is_connected(_on_impact_resolved):
		fighter.impact_resolved.connect(_on_impact_resolved)

func _on_impact_resolved(
	_target: MasteredWeaponFighterController,
	attacker: FighterController,
	technique: TechniqueData,
	result_id: StringName,
	_damage_applied: float,
	_posture_applied: float,
	_intensity: float,
	_world_position: Vector2
) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(technique):
		return
	var profile_id := "p1" if attacker.player_index == 1 else "p2"
	var technique_name := technique.display_name.to_upper()
	match result_id:
		&"hit":
			_register_combo(profile_id)
			_show_side_feedback(profile_id, "%s\nHIT" % technique_name, POLICY.GOLD)
		&"posture_break":
			_register_combo(profile_id)
			_show_side_feedback(profile_id, "%s\nQUEBRA DE POSTURA" % technique_name, POLICY.EMBER)
			_show_center_feedback("QUEBRA DE POSTURA", POLICY.EMBER, 1.14)
		&"blocked":
			_break_combo(profile_id)
			_show_side_feedback(profile_id, "%s\nBLOQUEADO" % technique_name, POLICY.BONE)
		&"evaded":
			_break_combo(profile_id)
			_show_side_feedback(profile_id, "%s\nESQUIVADO" % technique_name, POLICY.JADE)
			_show_center_feedback("ESQUIVA", POLICY.JADE, 1.0)
		&"parried":
			_break_combo(profile_id)
			_show_side_feedback(profile_id, "%s\nPARRY" % technique_name, POLICY.ROUTE_TAI)
			_show_center_feedback("PARRY", POLICY.ROUTE_TAI, 1.08)

func _register_combo(profile_id: String) -> void:
	_combo_counts[profile_id] = int(_combo_counts.get(profile_id, 0)) + 1
	_combo_timers[profile_id] = COMBO_RESET_SECONDS
	_update_combo_label(profile_id)

func _break_combo(profile_id: String) -> void:
	_combo_counts[profile_id] = 0
	_combo_timers[profile_id] = 0.0
	_update_combo_label(profile_id)

func _build_feedback_layer() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "CombatFeedbackLayer"
	_layer.layer = 12
	add_child(_layer)

	_center_label = _make_label("CenterImpact", Vector2(390.0, 248.0), Vector2(500.0, 84.0), 30)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_layer.add_child(_center_label)

	_p1_label = _make_label("P1Impact", Vector2(34.0, 188.0), Vector2(360.0, 76.0), 15)
	_p1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_layer.add_child(_p1_label)

	_p2_label = _make_label("P2Impact", Vector2(886.0, 188.0), Vector2(360.0, 76.0), 15)
	_p2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layer.add_child(_p2_label)

	var p1_combo := _make_label("P1Combo", Vector2(34.0, 272.0), Vector2(260.0, 54.0), 22)
	p1_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_layer.add_child(p1_combo)
	_combo_labels["p1"] = p1_combo

	var p2_combo := _make_label("P2Combo", Vector2(986.0, 272.0), Vector2(260.0, 54.0), 22)
	p2_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layer.add_child(p2_combo)
	_combo_labels["p2"] = p2_combo

func _make_label(node_name: String, label_position: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = label_position
	label.size = label_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", POLICY.BONE)
	label.add_theme_color_override("font_shadow_color", Color(POLICY.INK.r, POLICY.INK.g, POLICY.INK.b, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.text = ""
	label.modulate.a = 0.0
	return label

func _show_side_feedback(profile_id: String, text: String, color: Color) -> void:
	var label := _p1_label if profile_id == "p1" else _p2_label
	_show_transient(label, text, color, 1.0)

func _show_center_feedback(text: String, color: Color, scale_factor: float) -> void:
	_show_transient(_center_label, text, color, scale_factor)

func _show_transient(label: Label, text: String, color: Color, scale_factor: float) -> void:
	if not is_instance_valid(label):
		return
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.modulate.a = 1.0
	label.scale = Vector2.ONE * scale_factor
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, FEEDBACK_LIFETIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "scale", Vector2.ONE, FEEDBACK_LIFETIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _update_combo_label(profile_id: String) -> void:
	var label: Label = _combo_labels.get(profile_id)
	if not is_instance_valid(label):
		return
	var count := int(_combo_counts.get(profile_id, 0))
	if count <= 1:
		label.text = ""
		label.modulate.a = 0.0
		return
	label.text = "%d COMBO" % count
	label.add_theme_color_override("font_color", POLICY.GOLD)
	label.modulate.a = 1.0

func presentation_signature() -> Dictionary:
	return {
		"impact_feedback_runtime": true,
		"technique_name_on_impact": true,
		"hit_feedback": true,
		"blocked_feedback": true,
		"evaded_feedback": true,
		"parry_feedback": true,
		"posture_break_feedback": true,
		"combo_counter_per_side": true,
		"feedback_is_visual_only": true,
		"damage_changes": false,
		"frame_data_changes": false,
		"ai_changes": false,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
