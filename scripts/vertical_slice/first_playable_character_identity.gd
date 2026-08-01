class_name FirstPlayableCharacterIdentity
extends Node2D

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")
const CAMERA_COMPOSITION := preload("res://scripts/vertical_slice/first_playable_camera_composition.gd")
const LIAN_WU_PRESENTER := preload("res://scripts/vertical_slice/first_playable_lot01_presenter.gd")
const TRAINING_RIVAL_PRESENTER := preload("res://scripts/vertical_slice/training_rival_lot01_presenter.gd")
const VISUAL_SCALE := Vector2(1.28, 1.28)

var _fighter: FighterController

func _ready() -> void:
	_fighter = get_parent() as FighterController
	z_index = 4
	scale = VISUAL_SCALE
	_install_camera_composition()
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
		"real_asset_handoff": true,
		"lian_wu_presenter": true,
		"training_rival_presenter": true,
		"procedural_fallback_until_real_assets": true,
		"procedural_is_fallback_only": true,
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

	draw_colored_polygon(
		PackedVector2Array([Vector2(-14, -35), Vector2(14, -35), Vector2(16, 4), Vector2(0, 14), Vector2(-16, 4)]),
		robe
	)
	draw_polyline(PackedVector2Array([Vector2(-12, -33), Vector2(2, -18), Vector2(13, -33)]), water_blue, 4.0)
	draw_line(Vector2(-16, -1), Vector2(16, -1), water_blue, 5.0)
	draw_line(Vector2(-13, 8), Vector2(13, 8), ink, 2.0)
	draw_circle(Vector2(0, -1), 3.4, gold)

	if _fighter._attack_phase == FighterController.AttackPhase.NONE:
		draw_line(Vector2(-7 * facing, 1), Vector2(-43 * facing, 24), Color(0.06, 0.20, 0.43, alpha), 6.0)
		draw_line(Vector2(-8 * facing, 0), Vector2(-20 * facing, 7), gold, 4.0)
	else:
		draw_line(Vector2(10 * facing, -23), Vector2(58 * facing, -33), Color(0.84, 0.94, 1.0, alpha), 4.0)
		draw_line(Vector2(7 * facing, -22), Vector2(17 * facing, -24), gold, 5.0)

	draw_arc(Vector2(0, 18), 18.0, 0.15, PI - 0.15, 18, Color(0.20, 0.70, 1.0, 0.78 * alpha), 2.5)

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
