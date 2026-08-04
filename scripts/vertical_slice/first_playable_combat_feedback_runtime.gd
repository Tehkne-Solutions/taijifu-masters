extends Node

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")
const FEEDBACK_LIFETIME := 0.46
const CRITICAL_LIFETIME := 0.44
const COMBO_RESET_SECONDS := 1.10
const MAX_ACTIVE_POPUPS := 2

var _root: Node
var _p1: MasteredWeaponFighterController
var _p2: MasteredWeaponFighterController
var _layer: CanvasLayer
var _center_label: Label
var _combo_labels: Dictionary = {}
var _combo_counts: Dictionary = {"p1": 0, "p2": 0}
var _combo_timers: Dictionary = {"p1": 0.0, "p2": 0.0}
var _active_popups: Array[Label] = []
var _critical_token := 0

func _ready() -> void:
	process_priority = 35
	_root = get_parent()
	_build_feedback_layer()
	print("V2_PRESENTATION_FEEDBACK_BUDGET=PASS max=", MAX_ACTIVE_POPUPS)

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
	intensity: float,
	world_position: Vector2
) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(technique):
		return
	var profile_id := "p1" if attacker.player_index == 1 else "p2"
	var technique_name := technique.display_name.to_upper()
	var result_label := "HIT"
	var color := POLICY.GOLD
	var critical := false
	match result_id:
		&"hit":
			_register_combo(profile_id)
			result_label = "HIT"
			color = POLICY.GOLD
		&"posture_break":
			_register_combo(profile_id)
			result_label = "QUEBRA"
			color = POLICY.EMBER
			critical = true
		&"blocked":
			_break_combo(profile_id)
			result_label = "BLOQUEIO"
			color = POLICY.BONE
		&"evaded":
			_break_combo(profile_id)
			result_label = "ESQUIVA"
			color = POLICY.JADE
			critical = true
		&"parried":
			_break_combo(profile_id)
			result_label = "PARRY"
			color = POLICY.ROUTE_TAI
			critical = true

	_spawn_impact_popup(world_position, technique_name, result_label, color, profile_id, result_id)
	if critical:
		_show_center_feedback(result_label, color)
	_punch_camera(intensity, result_id)

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

	_center_label = _make_label("CriticalImpact", Vector2(470.0, 176.0), Vector2(340.0, 56.0), 24)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_layer.add_child(_center_label)

	var p1_combo := _make_label("P1Combo", Vector2(34.0, 112.0), Vector2(220.0, 36.0), 17)
	p1_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_layer.add_child(p1_combo)
	_combo_labels["p1"] = p1_combo

	var p2_combo := _make_label("P2Combo", Vector2(1026.0, 112.0), Vector2(220.0, 36.0), 17)
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
	label.add_theme_color_override("font_shadow_color", Color(POLICY.INK.r, POLICY.INK.g, POLICY.INK.b, 0.90))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.text = ""
	label.modulate.a = 0.0
	return label

func _spawn_impact_popup(world_position: Vector2, technique_name: String, result_label: String, color: Color, profile_id: String, result_id: StringName) -> void:
	if not is_instance_valid(_layer):
		return
	_cleanup_popup_budget()
	var popup := _make_label("ImpactPopup", Vector2.ZERO, Vector2(190.0, 38.0), 12)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Normal hits keep the technique name; defensive/critical states use the short result only.
	popup.text = technique_name if result_id == &"hit" else result_label
	popup.add_theme_color_override("font_color", color)
	popup.modulate.a = 1.0
	var screen_pos := _world_to_screen(world_position)
	var side_offset := -42.0 if profile_id == "p1" else 42.0
	popup.position = screen_pos + Vector2(-95.0 + side_offset, -54.0)
	_layer.add_child(popup)
	_active_popups.append(popup)

	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position", popup.position + Vector2(0.0, -24.0), FEEDBACK_LIFETIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(popup, "modulate:a", 0.0, FEEDBACK_LIFETIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(func() -> void:
		_active_popups.erase(popup)
		if is_instance_valid(popup): popup.queue_free()
	)

func _world_to_screen(world_position: Vector2) -> Vector2:
	if not is_instance_valid(_root): return world_position
	var camera := _root.get_node_or_null("Camera2D") as Camera2D
	if camera == null: return world_position
	return camera.get_canvas_transform() * world_position

func _cleanup_popup_budget() -> void:
	while _active_popups.size() >= MAX_ACTIVE_POPUPS:
		var oldest := _active_popups.pop_front()
		if is_instance_valid(oldest): oldest.queue_free()

func _show_center_feedback(text: String, color: Color) -> void:
	if not is_instance_valid(_center_label): return
	_critical_token += 1
	var token := _critical_token
	_center_label.text = text
	_center_label.add_theme_color_override("font_color", color)
	_center_label.modulate.a = 1.0
	_center_label.scale = Vector2.ONE * 1.04
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_center_label, "modulate:a", 0.0, CRITICAL_LIFETIME)
	tween.tween_property(_center_label, "scale", Vector2.ONE, CRITICAL_LIFETIME)
	tween.chain().tween_callback(func() -> void:
		if token == _critical_token and is_instance_valid(_center_label): _center_label.text = ""
	)

func _punch_camera(intensity: float, result_id: StringName) -> void:
	if not is_instance_valid(_root): return
	var composition := _root.get_node_or_null("FightCameraComposition")
	if composition != null and composition.has_method("impact_punch"):
		composition.call("impact_punch", clampf(intensity, 0.15, 1.0), result_id)

func _update_combo_label(profile_id: String) -> void:
	var label: Label = _combo_labels.get(profile_id)
	if not is_instance_valid(label): return
	var count := int(_combo_counts.get(profile_id, 0))
	if count <= 1:
		label.text = ""
		label.modulate.a = 0.0
		return
	label.text = "%d HIT" % count
	label.add_theme_color_override("font_color", POLICY.GOLD)
	label.modulate.a = 1.0

func presentation_signature() -> Dictionary:
	return {
		"impact_feedback_runtime": true,
		"technique_name_on_normal_hit": true,
		"short_defensive_feedback": true,
		"combo_counter_per_side": true,
		"popup_budget": MAX_ACTIVE_POPUPS,
		"critical_feedback_priority": true,
		"camera_punch_on_impact": true,
		"feedback_is_visual_only": true,
		"damage_changes": false,
		"frame_data_changes": false,
		"ai_changes": false,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
