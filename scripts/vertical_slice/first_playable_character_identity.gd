class_name FirstPlayableCharacterIdentity
extends Node2D

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")
const CAMERA_COMPOSITION := preload("res://scripts/vertical_slice/first_playable_camera_composition.gd")
const COMBO_RUNTIME := preload("res://scripts/vertical_slice/first_playable_combo_runtime.gd")
const COMBAT_TELEMETRY_RUNTIME := preload("res://scripts/vertical_slice/first_playable_combat_telemetry_runtime.gd")
const ADAPTIVE_MASTER_RUNTIME := preload("res://scripts/vertical_slice/first_playable_adaptive_master_runtime.gd")
const MASTER_MARTIAL_PLANNER := preload("res://scripts/vertical_slice/first_playable_master_martial_planner.gd")
const MASTER_PURSUIT_RUNTIME := preload("res://scripts/vertical_slice/first_playable_master_pursuit_runtime.gd")
const MARTIAL_HUD_RUNTIME := preload("res://scripts/vertical_slice/first_playable_martial_hud_runtime.gd")
const COMBAT_FEEDBACK_RUNTIME := preload("res://scripts/vertical_slice/first_playable_combat_feedback_runtime.gd")
const AI_WATCHDOG_RUNTIME := preload("res://scripts/runtime/first_playable_ai_watchdog_runtime.gd")
const LIAN_WU_PRESENTER := preload("res://scripts/vertical_slice/first_playable_lot01_presenter.gd")
const TRAINING_RIVAL_PRESENTER := preload("res://scripts/vertical_slice/training_rival_lot01_presenter.gd")
const VISUAL_SCALE := Vector2(1.28, 1.28)

var _fighter: FighterController

func _ready() -> void:
	_fighter = get_parent() as FighterController
	z_index = 4
	scale = VISUAL_SCALE
	_install_camera_composition()
	_install_first_playable_runtime()
	call_deferred("_install_real_asset_presenter")

func _install_camera_composition() -> void:
	if not is_instance_valid(_fighter) or _fighter.player_index != 1:
		return
	var match_root := _fighter.get_parent()
	if match_root == null or match_root.has_node("FightCameraComposition"):
		return
	var composition := CAMERA_COMPOSITION.new() as FirstPlayableCameraComposition
	composition.name = "FightCameraComposition"
	match_root.add_child.call_deferred(composition)

func _install_first_playable_runtime() -> void:
	if not is_instance_valid(_fighter) or _fighter.player_index != 1:
		return
	var match_root := _fighter.get_parent()
	if match_root == null:
		return
	if not match_root.has_node("FirstPlayableComboRuntime"):
		var combo := COMBO_RUNTIME.new() as FirstPlayableComboRuntime
		combo.name = "FirstPlayableComboRuntime"
		match_root.add_child.call_deferred(combo)
	if not match_root.has_node("FirstPlayableCombatTelemetryRuntime"):
		var telemetry_runtime := COMBAT_TELEMETRY_RUNTIME.new() as FirstPlayableCombatTelemetryRuntime
		telemetry_runtime.name = "FirstPlayableCombatTelemetryRuntime"
		match_root.add_child.call_deferred(telemetry_runtime)
	if not match_root.has_node("FirstPlayableAdaptiveMasterRuntime"):
		var adaptive_runtime := ADAPTIVE_MASTER_RUNTIME.new() as FirstPlayableAdaptiveMasterRuntime
		adaptive_runtime.name = "FirstPlayableAdaptiveMasterRuntime"
		match_root.add_child.call_deferred(adaptive_runtime)
	if not match_root.has_node("FirstPlayableMasterMartialPlanner"):
		var planner_runtime := MASTER_MARTIAL_PLANNER.new()
		planner_runtime.name = "FirstPlayableMasterMartialPlanner"
		match_root.add_child.call_deferred(planner_runtime)
	if not match_root.has_node("FirstPlayableMasterPursuitRuntime"):
		var pursuit_runtime := MASTER_PURSUIT_RUNTIME.new()
		pursuit_runtime.name = "FirstPlayableMasterPursuitRuntime"
		match_root.add_child.call_deferred(pursuit_runtime)
	if not match_root.has_node("FirstPlayableMartialHudRuntime"):
		var martial_hud := MARTIAL_HUD_RUNTIME.new()
		martial_hud.name = "FirstPlayableMartialHudRuntime"
		match_root.add_child.call_deferred(martial_hud)
	if not match_root.has_node("FirstPlayableCombatFeedbackRuntime"):
		var feedback_runtime := COMBAT_FEEDBACK_RUNTIME.new()
		feedback_runtime.name = "FirstPlayableCombatFeedbackRuntime"
		match_root.add_child.call_deferred(feedback_runtime)
	if not match_root.has_node("FirstPlayableAiWatchdogRuntime"):
		var ai_watchdog := AI_WATCHDOG_RUNTIME.new() as FirstPlayableAiWatchdogRuntime
		ai_watchdog.name = "FirstPlayableAiWatchdogRuntime"
		match_root.add_child.call_deferred(ai_watchdog)

func _install_real_asset_presenter() -> void:
	if not is_instance_valid(_fighter) or not is_instance_valid(_fighter.build):
		return
	if _fighter.has_node("FirstPlayableRealAssetPresenter"):
		return
	_receive_creator_battle_handoff()
	var presenter: Node2D
	match _fighter.build.character_id:
		&"lian_wu":
			presenter = LIAN_WU_PRESENTER.new() as FirstPlayableLot01Presenter
		&"training_rival":
			presenter = TRAINING_RIVAL_PRESENTER.new() as TrainingRivalLot01Presenter
		_:
			return
	presenter.name = "FirstPlayableRealAssetPresenter"
	_fighter.add_child(presenter)

func _receive_creator_battle_handoff() -> void:
	if not is_instance_valid(_fighter) or _fighter.player_index != 1:
		return
	var handoff := FirstPlayableSession.creator_battle_handoff_signature()
	_fighter.set_meta("creator_battle_handoff", handoff)
	if not bool(handoff.get("preset_selected", false)):
		return
	print("C62_8_CREATOR_BATTLE_HANDOFF=PASS preset=%s" % String(handoff.get("preset_id", "")))
	print("C62_8_CREATOR_VISUAL_ACTIVATION=BLOCKED blocker=%s" % String(handoff.get("visual_blocker", "")))
	print("C62_8_ANIMATED_FALLBACK=PRESERVED presenter=lian_wu_first_playable")

func creator_battle_handoff_signature() -> Dictionary:
	if not is_instance_valid(_fighter) or _fighter.player_index != 1:
		return {}
	if _fighter.has_meta("creator_battle_handoff"):
		var value = _fighter.get_meta("creator_battle_handoff")
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}
	return FirstPlayableSession.creator_battle_handoff_signature()

func presentation_signature() -> Dictionary:
	return {
		"visual_policy": POLICY.DIRECTION,
		"character_read": POLICY.CHARACTER_READ,
		"visual_scale": VISUAL_SCALE.x,
		"fighter_first_readability": true,
		"camera_composition": true,
		"combo_runtime": true,
		"combat_telemetry_v4": true,
		"adaptive_master_runtime": true,
		"master_martial_planner": true,
		"master_pursuit_runtime": true,
		"martial_hud_runtime": true,
		"combat_feedback_runtime": true,
		"ai_watchdog_runtime": true,
		"real_asset_handoff": true,
		"lian_wu_presenter": true,
		"training_rival_presenter": true,
		"creator_battle_handoff": true,
		"production_default_modular_cutover": true,
		"creator_visual_activation": false,
		"creator_visual_blocker": FirstPlayableSession.CREATOR_VISUAL_BLOCKER,
		"static_creator_sprite_regression_allowed": false,
		"procedural_character_renderer": false,
		"procedural_fallback_until_real_assets": false,
		"canonical_visual_cutover_required": true,
		"collision_changes": false,
		"signature": "Tehkné Solutions"
	}

# C50 intentionally contains no _draw() fallback.
# Production fighters must render through canonical SpriteFrames presenters only.
# P0.2 promotes the production modular graph over LOT01 for player one whenever
# the modular asset contract can be resolved; LOT01 remains fail-closed evidence.
# Tehkné Solutions
