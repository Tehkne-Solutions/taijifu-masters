class_name FirstPlayablePack04ReactionRuntime
extends Node

## Semantic bridge for PACK 04 combat reactions.
## Observes already-resolved combat outcomes and publishes a canonical visual
## reaction state. Until the approved PACK 04 release is materialized, every new
## reaction state remains explicitly on an existing-art fallback.
## This runtime never changes damage, frame data, collision or world physics.
## Tehkné Solutions

const RUNTIME_ID := "first_playable_pack04_reaction_runtime_v1"
const PACK_ID := "PACK_04_COMBAT_REACTIONS_AND_MOTION"
const EXPECTED_RELEASE_TAG := "assets-pack-04-v1.0.0"
const PACK04_ART_AVAILABLE := false

const META_SEMANTIC_STATE := &"pack04_reaction_semantic_state"
const META_VISUAL_OVERRIDE := &"pack04_reaction_visual_override"
const META_FALLBACK_ACTIVE := &"pack04_reaction_fallback_active"
const META_VISUAL_SOURCE := &"pack04_reaction_visual_source"

const BLOCK_RECOIL_SECONDS := 0.14
const PARRY_SECONDS := 0.18
const POSTURE_BREAK_SECONDS := 0.20
const KNOCKBACK_SECONDS := 0.14
const NEUTRAL_RECOVERY_SECONDS := 0.18
const EXISTING_HIT_SECONDS := 0.18

const REQUIRED_STATES: Array[StringName] = [
	&"block_recoil",
	&"parry",
	&"posture_break",
	&"knockback",
	&"neutral_recovery",
]

const FALLBACK_VISUALS := {
	&"block_recoil": &"guard",
	&"parry": &"guard",
	&"posture_break": &"hit",
	&"knockback": &"hit",
	&"neutral_recovery": &"idle",
}

const RESULT_SEQUENCES := {
	&"hit": [&"knockback", &"neutral_recovery"],
	&"blocked": [&"block_recoil", &"neutral_recovery"],
	&"parried": [&"parry", &"neutral_recovery"],
	&"posture_break": [&"posture_break", &"knockback", &"neutral_recovery"],
	&"evaded": [],
}

var _fighter: FirstPlayableCombatFighterController
var _steps: Array[Dictionary] = []
var _step_index := -1
var _step_timer := 0.0
var _semantic_state: StringName = &""
var _visual_override: StringName = &""
var _visual_source := "none"
var _fallback_active := false
var _last_result_id: StringName = &"none"
var _transition_count := 0
var _connected := false

func _ready() -> void:
	process_priority = -20
	_fighter = get_parent() as FirstPlayableCombatFighterController
	if not is_instance_valid(_fighter):
		push_error("PACK04_REACTION_RUNTIME=BLOCKED reason=invalid_fighter_parent")
		return
	if not _fighter.impact_resolved.is_connected(_on_impact_resolved):
		_fighter.impact_resolved.connect(_on_impact_resolved)
	_connected = true
	_clear_state()
	print("PACK04_REACTION_RUNTIME=ARMED fighter=p%d art_available=false release=%s" % [
		_fighter.player_index,
		EXPECTED_RELEASE_TAG,
	])

func _exit_tree() -> void:
	if is_instance_valid(_fighter) and _connected and _fighter.impact_resolved.is_connected(_on_impact_resolved):
		_fighter.impact_resolved.disconnect(_on_impact_resolved)
	_clear_fighter_metadata()

func _process(delta: float) -> void:
	if not is_instance_valid(_fighter):
		return
	if _step_index < 0 or _step_index >= _steps.size():
		return

	# Gameplay remains authoritative. Once the physical recovery lock has ended
	# and a new discrete action is accepted, any visual reaction tail must yield.
	if _fighter.first_playable_visual_action_override_active():
		_clear_state()
		return

	_step_timer = maxf(0.0, _step_timer - delta)
	if _step_timer <= 0.0:
		_advance_step()

func semantic_state() -> StringName:
	return _semantic_state

func visual_override() -> StringName:
	return _visual_override

func fallback_active() -> bool:
	return _fallback_active

func art_available() -> bool:
	return PACK04_ART_AVAILABLE

func runtime_signature() -> Dictionary:
	return {
		"runtime": RUNTIME_ID,
		"pack_id": PACK_ID,
		"expected_release_tag": EXPECTED_RELEASE_TAG,
		"connected": _connected,
		"required_states": REQUIRED_STATES.duplicate(),
		"required_state_count": REQUIRED_STATES.size(),
		"result_sequences": _sequence_signature(),
		"fallback_visuals": _fallback_signature(),
		"pack04_art_available": PACK04_ART_AVAILABLE,
		"pack04_art_status": "blocked_release_not_materialized",
		"semantic_state": String(_semantic_state),
		"visual_override": String(_visual_override),
		"visual_source": _visual_source,
		"fallback_active": _fallback_active,
		"last_result_id": String(_last_result_id),
		"transition_count": _transition_count,
		"physics_changes": false,
		"damage_changes": false,
		"frame_data_changes": false,
		"collision_changes": false,
		"ai_changes": false,
		"world_translation_owner": "fighter_physics",
		"signature": "Tehkné Solutions",
	}

func _on_impact_resolved(
	target: MasteredWeaponFighterController,
	_attacker: FighterController,
	_technique: TechniqueData,
	result_id: StringName,
	_damage_applied: float,
	_posture_applied: float,
	_intensity: float,
	_world_position: Vector2
) -> void:
	if target != _fighter:
		return
	_begin_result(result_id)

func _begin_result(result_id: StringName) -> void:
	_last_result_id = result_id
	_steps.clear()
	_step_index = -1
	_step_timer = 0.0

	match result_id:
		&"hit":
			# Existing approved HIT remains the contact read. PACK 04 begins with
			# the travel/recovery tail; no new HIT art is requested.
			_steps.append(_existing_step(&"hit", EXISTING_HIT_SECONDS))
			_steps.append(_pack04_step(&"knockback", KNOCKBACK_SECONDS))
			_steps.append(_pack04_step(&"neutral_recovery", NEUTRAL_RECOVERY_SECONDS))
		&"blocked":
			_steps.append(_pack04_step(&"block_recoil", BLOCK_RECOIL_SECONDS))
			_steps.append(_pack04_step(&"neutral_recovery", NEUTRAL_RECOVERY_SECONDS))
		&"parried":
			_steps.append(_pack04_step(&"parry", PARRY_SECONDS))
			_steps.append(_pack04_step(&"neutral_recovery", NEUTRAL_RECOVERY_SECONDS))
		&"posture_break":
			_steps.append(_pack04_step(&"posture_break", POSTURE_BREAK_SECONDS))
			_steps.append(_pack04_step(&"knockback", KNOCKBACK_SECONDS))
			_steps.append(_pack04_step(&"neutral_recovery", NEUTRAL_RECOVERY_SECONDS))
		&"evaded":
			_clear_state()
			return
		_:
			_clear_state()
			return

	_step_index = 0
	_enter_current_step()

func _existing_step(visual_state: StringName, duration: float) -> Dictionary:
	return {
		"semantic": &"",
		"visual": visual_state,
		"duration": duration,
		"source": "existing_approved_state",
		"fallback": false,
	}

func _pack04_step(state: StringName, duration: float) -> Dictionary:
	return {
		"semantic": state,
		"visual": FALLBACK_VISUALS.get(state, &"idle"),
		"duration": duration,
		"source": "pack04_missing_asset_fallback",
		"fallback": true,
	}

func _enter_current_step() -> void:
	if _step_index < 0 or _step_index >= _steps.size():
		_clear_state()
		return
	var step := _steps[_step_index]
	_semantic_state = StringName(step.get("semantic", &""))
	_visual_override = StringName(step.get("visual", &""))
	_step_timer = maxf(0.0, float(step.get("duration", 0.0)))
	_visual_source = String(step.get("source", "none"))
	_fallback_active = bool(step.get("fallback", false))
	_transition_count += 1
	_publish_metadata()

func _advance_step() -> void:
	_step_index += 1
	if _step_index >= _steps.size():
		_clear_state()
		return
	_enter_current_step()

func _clear_state() -> void:
	_steps.clear()
	_step_index = -1
	_step_timer = 0.0
	_semantic_state = &""
	_visual_override = &""
	_visual_source = "none"
	_fallback_active = false
	_publish_metadata()

func _publish_metadata() -> void:
	if not is_instance_valid(_fighter):
		return
	_fighter.set_meta(META_SEMANTIC_STATE, String(_semantic_state))
	_fighter.set_meta(META_VISUAL_OVERRIDE, String(_visual_override))
	_fighter.set_meta(META_FALLBACK_ACTIVE, _fallback_active)
	_fighter.set_meta(META_VISUAL_SOURCE, _visual_source)

func _clear_fighter_metadata() -> void:
	if not is_instance_valid(_fighter):
		return
	for key in [META_SEMANTIC_STATE, META_VISUAL_OVERRIDE, META_FALLBACK_ACTIVE, META_VISUAL_SOURCE]:
		if _fighter.has_meta(key):
			_fighter.remove_meta(key)

func _sequence_signature() -> Dictionary:
	var result := {}
	for result_id in RESULT_SEQUENCES.keys():
		var values: Array = RESULT_SEQUENCES[result_id]
		var names: Array[String] = []
		for value in values:
			names.append(String(value))
		result[String(result_id)] = names
	return result

func _fallback_signature() -> Dictionary:
	var result := {}
	for state in FALLBACK_VISUALS.keys():
		result[String(state)] = String(FALLBACK_VISUALS[state])
	return result

# Tehkné Solutions
