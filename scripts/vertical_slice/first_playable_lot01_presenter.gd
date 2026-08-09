class_name FirstPlayableLot01Presenter
extends Node2D

const LOT_ROOT := "res://assets/tgap/pack_01_lian_wu/first_playable_lot_01"
const SPRITE_FRAMES_PATH := LOT_ROOT + "/lian_wu_first_playable_frames.tres"
const MODULAR_FIGHTER_PRESENTER := preload("res://scripts/vertical_slice/first_playable_modular_fighter_presenter.gd")
const CANONICAL_CANVAS_SIZE := Vector2(1024.0, 1024.0)
const CANONICAL_BASELINE_Y := 969.0
const TARGET_VISUAL_HEIGHT := 132.0
const CANONICAL_ALPHA_HEIGHT := 900.0
const CANONICAL_SCALE := TARGET_VISUAL_HEIGHT / CANONICAL_ALPHA_HEIGHT
const BASELINE_OFFSET_Y := -(CANONICAL_BASELINE_Y - CANONICAL_CANVAS_SIZE.y * 0.5) * CANONICAL_SCALE
const HIT_VISUAL_SECONDS := 0.18

var _fighter: FighterController
var _sprite: AnimatedSprite2D
var _active_animation: StringName = &""
var _using_real_assets := false
var _last_health := -1.0
var _hit_visual_timer := 0.0

func _ready() -> void:
	_fighter = get_parent() as FighterController
	if is_instance_valid(_fighter):
		_last_health = _fighter.health
	z_index = 5
	_try_activate_real_assets()
	# C65 starts only from an already valid canonical LOT01. The modular creator
	# presenter overlays this node after complete BASE-01 assembly; if anything
	# fails, this presenter stays available as the production fallback.
	call_deferred("_install_modular_creator_overlay")

func _process(delta: float) -> void:
	if not _using_real_assets or not is_instance_valid(_fighter):
		return
	if _last_health >= 0.0 and _fighter.health < _last_health - 0.001 and _fighter.health > 0.0:
		_hit_visual_timer = HIT_VISUAL_SECONDS
	_last_health = _fighter.health
	_hit_visual_timer = maxf(0.0, _hit_visual_timer - delta)
	_sprite.flip_h = _fighter.facing < 0.0
	var next_animation := _resolve_animation()
	if next_animation != _active_animation:
		_active_animation = next_animation
		_sprite.play(_active_animation)

func using_real_assets() -> bool:
	return _using_real_assets

func expected_sprite_frames_path() -> String:
	return SPRITE_FRAMES_PATH

func _try_activate_real_assets() -> void:
	if not ResourceLoader.exists(SPRITE_FRAMES_PATH):
		print("V2_LIAN_CANONICAL_PRESENTER=BLOCKED missing_spriteframes")
		return
	var frames := load(SPRITE_FRAMES_PATH) as SpriteFrames
	if frames == null or not _has_required_animations(frames):
		push_warning("Lot 01 encontrado, mas contrato de animações está incompleto")
		print("V2_LIAN_CANONICAL_PRESENTER=BLOCKED incomplete_animation_contract")
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Lot01AnimatedSprite"
	_sprite.sprite_frames = frames
	_sprite.centered = true
	_sprite.scale = Vector2.ONE * CANONICAL_SCALE
	_sprite.position = Vector2(0.0, BASELINE_OFFSET_Y)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_using_real_assets = true
	_hide_legacy_visual_surfaces()
	_active_animation = &"idle"
	_sprite.play(_active_animation)
	print("V2_LIAN_CANONICAL_PRESENTER=PASS")
	print("V2_LIAN_CANONICAL_SCALE=%.6f" % CANONICAL_SCALE)
	print("V2_LIAN_CANONICAL_BASELINE=PASS")
	print("V2_LIAN_LEGACY_ATLAS=HIDDEN")

func _install_modular_creator_overlay() -> void:
	if not _using_real_assets or not is_instance_valid(_fighter):
		return
	if _fighter.player_index != 1 or not FirstPlayableSession.has_creator_preset():
		return
	if _fighter.has_node("FirstPlayableModularFighterPresenter"):
		return
	var modular := MODULAR_FIGHTER_PRESENTER.new() as FirstPlayableModularFighterPresenter
	modular.name = "FirstPlayableModularFighterPresenter"
	_fighter.add_child(modular)

func _hide_legacy_visual_surfaces() -> void:
	if not is_instance_valid(_fighter):
		return
	# FirstPlayableIdentity is the old character-identity surface. The fighter scene
	# also owns a ProvisionalSpritePresenter atlas at `SpritePresenter`; once the
	# canonical LOT01 is valid both legacy surfaces must be hidden or the character
	# renders twice. Only CanvasItem visibility changes here: controller, collision,
	# outcome, weapon trail and combat state remain untouched.
	for node_name in ["FirstPlayableIdentity", "SpritePresenter"]:
		var surface := _fighter.get_node_or_null(node_name) as CanvasItem
		if surface != null:
			surface.visible = false

func _has_required_animations(frames: SpriteFrames) -> bool:
	for animation_name in [
		&"idle", &"run", &"jump_start", &"airborne", &"fall",
		&"attack_light", &"guard", &"dodge", &"hit", &"ko"
	]:
		if not frames.has_animation(animation_name):
			return false
		if frames.get_frame_count(animation_name) <= 0:
			return false
	return true

func _resolve_animation() -> StringName:
	if _fighter.health <= 0.0:
		return &"ko"
	if _hit_visual_timer > 0.0:
		return &"hit"
	if _fighter._dodge_timer > 0.0:
		return &"dodge"
	if _fighter._attack_phase != FighterController.AttackPhase.NONE:
		return &"attack_light"
	if _fighter._is_blocking:
		return &"guard"
	if not _fighter.is_on_floor():
		if _fighter.velocity.y < -80.0:
			return &"airborne"
		return &"fall"
	if absf(_fighter.velocity.x) > 20.0:
		return &"run"
	return &"idle"

# Tehkné Solutions