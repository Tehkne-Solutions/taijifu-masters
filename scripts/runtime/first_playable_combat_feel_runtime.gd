class_name FirstPlayableCombatFeelRuntime
extends Node

const REARM_SECONDS := 0.18
const ACTION_TAI: StringName = &"first_playable_tai"
const ACTION_JI: StringName = &"first_playable_ji"
const ACTION_FU: StringName = &"first_playable_fu"

var _fighter: FighterController
var _combo: FirstPlayableComboRuntime
var _last_phase := FighterController.AttackPhase.NONE
var _rearm_timer := 0.0

func _ready() -> void:
	process_priority = -10

func _physics_process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not (scene is FirstPlayableController):
		_fighter = null
		_combo = null
		_rearm_timer = 0.0
		_last_phase = FighterController.AttackPhase.NONE
		return

	_resolve_runtime(scene)
	if not is_instance_valid(_fighter) or not is_instance_valid(_combo):
		return

	_rearm_timer = maxf(0.0, _rearm_timer - delta)
	var phase := _fighter._attack_phase
	if _last_phase != FighterController.AttackPhase.NONE and phase == FighterController.AttackPhase.NONE:
		_rearm_timer = REARM_SECONDS
	_last_phase = phase

	if phase != FighterController.AttackPhase.NONE or _rearm_timer > 0.0:
		if not _combo._queue.is_empty():
			_combo._queue.clear()
		if _attack_family_pressed():
			_combo._set_readout("RITMO  •  COMPLETE O GOLPE")

func _resolve_runtime(scene: FirstPlayableController) -> void:
	if not is_instance_valid(_fighter):
		var candidate: Variant = scene.get("player_one")
		if candidate is FighterController:
			_fighter = candidate as FighterController
	if not is_instance_valid(_combo):
		for child in scene.get_children():
			if child is FirstPlayableComboRuntime:
				_combo = child as FirstPlayableComboRuntime
				break

func _attack_family_pressed() -> bool:
	return (
		Input.is_action_just_pressed(ACTION_TAI)
		or Input.is_action_just_pressed(ACTION_JI)
		or Input.is_action_just_pressed(ACTION_FU)
	)

func presentation_signature() -> Dictionary:
	return {
		"anti_mash": true,
		"buffer_during_attack": false,
		"post_recovery_rearm_seconds": REARM_SECONDS,
		"requires_attack_completion": true,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
