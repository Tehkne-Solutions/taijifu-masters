class_name FirstPlayableCharacterIdentity
extends Node2D

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")
const CAMERA_COMPOSITION := preload("res://scripts/vertical_slice/first_playable_camera_composition.gd")
const COMBO_RUNTIME := preload("res://scripts/vertical_slice/first_playable_combo_runtime.gd")
const COMBAT_TELEMETRY_RUNTIME := preload("res://scripts/vertical_slice/first_playable_combat_telemetry_runtime.gd")
const ADAPTIVE_MASTER_RUNTIME := preload("res://scripts/vertical_slice/first_playable_adaptive_master_runtime.gd")
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
	queue_redraw()

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

func _install_real_asset_presenter() -> void:
	if not is_instance_valid(_fighter) or not is_instance_valid(_fighter.build):
		return
	if _fighter.has_node("FirstPlayableRealAssetPresenter"):
		return
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

func _process(_delta: float) -> void:
	if is_instance_valid(_fighter):
		queue_redraw()

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
		"real_asset_handoff": true,
		"lian_wu_presenter": true,
		"training_rival_presenter": true,
		"procedural_fallback_until_real_assets": true,
		"procedural_is_fallback_only": true,
		"lian_wu_recovered_identity": true,
		"lian_wu_chibi_silhouette": true,
		"lian_wu_single_sheathed_katana": true,
		"rejected_turnaround_promoted": false,
		"collision_changes": false,
		"signature": "Tehkné Solutions"
	}

func _draw() -> void:
	if not is_instance_valid(_fighter) or not is_instance_valid(_fighter.build):
		return
	match _fighter.build.character_id:
		&"lian_wu":
			_draw_lian_wu()
		&"training_rival":
			_draw_training_rival()

func _draw_lian_wu() -> void:
	var facing := _fighter.facing
	var alpha := 0.52 if _fighter._dodge_timer > 0.0 else 1.0
	var ink := Color(POLICY.LIAN_WU_INK, alpha)
	var robe := Color(POLICY.LIAN_WU_ROBE, alpha)
	var water_blue := Color(POLICY.LIAN_WU_WATER, alpha)
	var gold := Color(POLICY.LIAN_WU_GOLD, alpha)
	var hair := Color(POLICY.LIAN_WU_HAIR, alpha)
	var skin := Color(POLICY.LIAN_WU_SKIN, alpha)
	var scabbard := Color(POLICY.LIAN_WU_SCABBARD, alpha)

	draw_circle(Vector2(0, -43), 17.0, skin)
	draw_circle(Vector2(0, -50), 18.5, hair)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, -55), Vector2(-6, -67), Vector2(5, -72), Vector2(13, -61), Vector2(10, -48), Vector2(-12, -47)
	]), hair)
	draw_circle(Vector2(3, -72), 7.0, hair)
	draw_line(Vector2(1, -68), Vector2(12, -64), water_blue, 4.0)
	draw_line(Vector2(4, -67), Vector2(-7, -62), water_blue, 3.0)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, -30), Vector2(17, -30), Vector2(20, 1), Vector2(12, 15), Vector2(-12, 15), Vector2(-20, 1)
	]), robe)
	draw_polyline(PackedVector2Array([Vector2(-14, -28), Vector2(1, -15), Vector2(15, -29)]), water_blue, 4.0)
	draw_line(Vector2(-18, -2), Vector2(18, -2), water_blue, 5.0)
	draw_circle(Vector2(0, -3), 3.6, gold)
	draw_circle(Vector2(-17 * facing, -25), 6.0, gold)
	draw_line(Vector2(-14, 10), Vector2(-9, 22), ink, 5.0)
	draw_line(Vector2(14, 10), Vector2(9, 22), ink, 5.0)
	draw_line(Vector2(-9, 20), Vector2(-11, 29), ink, 6.0)
	draw_line(Vector2(9, 20), Vector2(11, 29), ink, 6.0)

	var hip := Vector2(-8 * facing, 3)
	var tip := Vector2(-39 * facing, 27)
	draw_line(hip, tip, scabbard, 7.0)
	draw_line(tip, tip + Vector2(-4 * facing, 3), gold, 4.0)
	draw_line(hip + Vector2(1 * facing, -2), hip + Vector2(-11 * facing, 7), gold, 4.0)

	if _fighter._attack_phase != FighterController.AttackPhase.NONE:
		draw_line(Vector2(10 * facing, -18), Vector2(56 * facing, -30), Color(0.84, 0.94, 1.0, alpha), 4.0)
		draw_line(Vector2(7 * facing, -17), Vector2(17 * facing, -20), gold, 5.0)

	draw_arc(Vector2(0, 23), 18.0, 0.15, PI - 0.15, 18, Color(0.20, 0.70, 1.0, 0.62 * alpha), 2.0)

func _draw_training_rival() -> void:
	var facing := _fighter.facing
	var alpha := 0.52 if _fighter._dodge_timer > 0.0 else 1.0
	var armor := Color(POLICY.RIVAL_ARMOR, alpha)
	var ember := Color(POLICY.RIVAL_EMBER, alpha)
	var metal := Color(POLICY.RIVAL_METAL, alpha)
	var brass := Color(POLICY.RIVAL_BRASS, alpha)

	draw_colored_polygon(
		PackedVector2Array([Vector2(-17, -35), Vector2(17, -35), Vector2(20, 8), Vector2(-20, 8)]),
		armor
	)
	draw_circle(Vector2(-15 * facing, -29), 9.0, metal)
	draw_line(Vector2(-15, -4), Vector2(15, -4), brass, 6.0)
	draw_line(Vector2(-12, 6), Vector2(12, 6), ember, 3.0)

	draw_circle(Vector2(29 * facing, -13), 10.0, metal)
	draw_circle(Vector2(-25 * facing, -5), 9.0, metal.darkened(0.12))
	draw_arc(Vector2(29 * facing, -13), 12.0, -0.9, 0.9, 12, ember, 3.0)

	var pulse := 14.0 + sin(Time.get_ticks_msec() * 0.008) * 2.0
	draw_arc(Vector2(0, 17), pulse, PI + 0.25, TAU - 0.25, 16, Color(POLICY.RIVAL_EMBER, 0.72 * alpha), 3.0)

# Tehkné Solutions
