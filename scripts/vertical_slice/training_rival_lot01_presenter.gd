class_name TrainingRivalLot01Presenter
extends Node2D

const LOT_ROOT := "res://assets/tgap/training_rival/first_playable_lot_01"
const SPRITE_FRAMES_PATH := LOT_ROOT + "/training_rival_first_playable_frames.tres"

var _fighter: FighterController
var _sprite: AnimatedSprite2D
var _active_animation: StringName = &""
var _using_real_assets := false

func _ready() -> void:
	_fighter = get_parent() as FighterController
	z_index = 5
	_try_activate_real_assets()

func _process(_delta: float) -> void:
	if not _using_real_assets or not is_instance_valid(_fighter):
		return
	_sprite.flip_h = _fighter.facing > 0.0
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
		return
	var frames := load(SPRITE_FRAMES_PATH) as SpriteFrames
	if frames == null or not _has_required_animations(frames):
		push_warning("Rival Lot 01 encontrado, mas contrato de animações está incompleto")
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "TrainingRivalLot01AnimatedSprite"
	_sprite.sprite_frames = frames
	_sprite.centered = true
	_sprite.position = Vector2(0.0, -34.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_using_real_assets = true
	_active_animation = &"idle"
	_sprite.play(_active_animation)

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
	if _fighter._hitstun_timer > 0.0:
		return &"hit"
	if _fighter._dodge_timer > 0.0:
		return &"dodge"
	if _fighter._attack_phase != FighterController.AttackPhase.NONE:
		return &"attack_light"
	if _fighter.is_guarding:
		return &"guard"
	if not _fighter.is_on_floor():
		if _fighter.velocity.y < -80.0:
			return &"airborne"
		return &"fall"
	if absf(_fighter.velocity.x) > 20.0:
		return &"run"
	return &"idle"

# Tehkné Solutions
