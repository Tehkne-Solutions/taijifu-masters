class_name FirstPlayableCombatTelemetryRuntime
extends Node

var _root: Node
var _fighter: MasteredWeaponFighterController
var _opponent: MasteredWeaponFighterController
var _combo: FirstPlayableComboRuntime
var _telemetry: MatchTelemetry
var _prev_combo_hits := 0
var _prev_flow := 0.0
var _prev_code := ""
var _prev_climax := false
var _prev_form := ""

func _ready() -> void:
	process_priority = 20
	_root = get_parent()

func _process(_delta: float) -> void:
	_resolve_runtime()
	if not is_instance_valid(_telemetry) or not is_instance_valid(_combo):
		return
	_capture_combo_state()

func _resolve_runtime() -> void:
	if not is_instance_valid(_root):
		return
	if not is_instance_valid(_telemetry):
		var telemetry_candidate: Variant = _root.get("_telemetry")
		if telemetry_candidate is MatchTelemetry:
			_telemetry = telemetry_candidate as MatchTelemetry
	if not is_instance_valid(_combo):
		var combo_candidate := _root.get_node_or_null("FirstPlayableComboRuntime")
		if combo_candidate is FirstPlayableComboRuntime:
			_combo = combo_candidate as FirstPlayableComboRuntime
	if not is_instance_valid(_fighter):
		var fighter_candidate: Variant = _root.get("player_one")
		if fighter_candidate is MasteredWeaponFighterController:
			_fighter = fighter_candidate as MasteredWeaponFighterController
			if not _fighter.technique_executed.is_connected(_on_player_technique_executed):
				_fighter.technique_executed.connect(_on_player_technique_executed)
			if not _fighter.impact_resolved.is_connected(_on_player_impact_resolved):
				_fighter.impact_resolved.connect(_on_player_impact_resolved)
	if not is_instance_valid(_opponent):
		var opponent_candidate: Variant = _root.get("player_two")
		if opponent_candidate is MasteredWeaponFighterController:
			_opponent = opponent_candidate as MasteredWeaponFighterController
			if not _opponent.technique_executed.is_connected(_on_opponent_technique_executed):
				_opponent.technique_executed.connect(_on_opponent_technique_executed)
			if not _opponent.impact_resolved.is_connected(_on_opponent_impact_resolved):
				_opponent.impact_resolved.connect(_on_opponent_impact_resolved)

func _on_player_technique_executed(
	_fighter_node: MasteredWeaponFighterController,
	technique: TechniqueData,
	_variant_id: StringName
) -> void:
	_record_technique(&"p1", technique)

func _on_opponent_technique_executed(
	_fighter_node: MasteredWeaponFighterController,
	technique: TechniqueData,
	_variant_id: StringName
) -> void:
	_record_technique(&"p2", technique)

func _record_technique(profile_id: StringName, technique: TechniqueData) -> void:
	if not is_instance_valid(_telemetry) or not is_instance_valid(technique):
		return
	var family := StringName(technique.path)
	_telemetry.record_route(profile_id, family, technique.total_seconds())
	_telemetry.record_event(profile_id, &"technique_started", technique.technique_id)
	_telemetry.record_event(profile_id, &"family_started", family)
	_telemetry.record_combat_metric(profile_id, &"techniques_started", 1.0)
	_telemetry.record_combat_metric(profile_id, StringName("%s_started" % technique.path), 1.0)
	if technique.has_element():
		_telemetry.record_combat_metric(profile_id, &"elemental_techniques_started", 1.0)

func _on_opponent_impact_resolved(
	_target: MasteredWeaponFighterController,
	attacker: FighterController,
	technique: TechniqueData,
	result_id: StringName,
	damage_applied: float,
	posture_applied: float,
	_intensity: float,
	_world_position: Vector2
) -> void:
	if attacker != _fighter:
		return
	_record_impact(&"p1", technique, result_id, damage_applied, posture_applied)

func _on_player_impact_resolved(
	_target: MasteredWeaponFighterController,
	attacker: FighterController,
	technique: TechniqueData,
	result_id: StringName,
	damage_applied: float,
	posture_applied: float,
	_intensity: float,
	_world_position: Vector2
) -> void:
	if attacker != _opponent:
		return
	_record_impact(&"p2", technique, result_id, damage_applied, posture_applied)

func _record_impact(
	profile_id: StringName,
	technique: TechniqueData,
	result_id: StringName,
	damage_applied: float,
	posture_applied: float
) -> void:
	if not is_instance_valid(_telemetry) or not is_instance_valid(technique):
		return
	_telemetry.record_event(profile_id, &"impact", result_id, 1.0)
	_telemetry.record_event(profile_id, &"technique_result", StringName("%s:%s" % [String(technique.technique_id), String(result_id)]), 1.0)
	_telemetry.record_combat_metric(profile_id, StringName("outcome_%s" % String(result_id)), 1.0)
	_telemetry.record_combat_metric(profile_id, &"damage_dealt", damage_applied)
	_telemetry.record_combat_metric(profile_id, &"posture_damage_dealt", posture_applied)
	if result_id == &"hit" or result_id == &"posture_break":
		_telemetry.record_combat_metric(profile_id, &"confirmed_hits", 1.0)
	if result_id == &"posture_break":
		_telemetry.record_combat_metric(profile_id, &"posture_breaks", 1.0)

func _capture_combo_state() -> void:
	var combo_hits := int(_combo.get("_combo_hits"))
	var flow := float(_combo.get("_flow"))
	var code_families: Array = _combo.get("_code_families")
	var code_parts: Array[String] = []
	for family in code_families:
		code_parts.append(String(family))
	var code := ">".join(code_parts)
	var climax := bool(_combo.get("_climax_active"))
	var form_name := String(_combo.get("_pending_form_name"))

	if combo_hits != _prev_combo_hits:
		_telemetry.record_combat_peak(&"p1", &"max_combo", float(combo_hits))
		_prev_combo_hits = combo_hits
	if absf(flow - _prev_flow) >= 0.5:
		_telemetry.record_combat_peak(&"p1", &"max_flow", flow)
		_prev_flow = flow
	if code != _prev_code:
		if code != "":
			_telemetry.record_event(&"p1", &"martial_code", StringName(code))
			_telemetry.record_combat_metric(&"p1", &"code_steps", 1.0)
		_prev_code = code
	if climax and not _prev_climax:
		_telemetry.record_event(&"p1", &"climax_started", StringName(form_name))
		_telemetry.record_combat_metric(&"p1", &"climax_started", 1.0)
		_prev_form = form_name
	elif not climax and _prev_climax:
		_telemetry.record_event(&"p1", &"climax_resolved", StringName(_prev_form))
		_telemetry.record_combat_metric(&"p1", &"climax_resolved", 1.0)
		_prev_form = ""
	_prev_climax = climax

func presentation_signature() -> Dictionary:
	return {
		"telemetry_schema": "v4",
		"route_seconds_from_techniques": true,
		"both_fighters_instrumented": true,
		"martial_flow_metrics": true,
		"impact_outcomes": true,
		"combo_peak": true,
		"flow_peak": true,
		"climax_events": true,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
