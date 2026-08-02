class_name LianWuCharacterLockBench
extends Node2D

## VM01-A3 deterministic in-engine bench for the recovered Lian Wu Character Lock.
## Tehkné Solutions

const CHARACTER_ID := &"lian_wu"
const REQUIRED_VIEWPORT := Vector2i(1920, 1080)
const PIVOT_NORMALIZED := Vector2(0.5, 0.92)
const NATIVE_FACING := 1.0

@export_file("*.png") var neutral_texture_path := "res://assets/characters/lian_wu/character_lock/lian_wu_neutral.png"
@export_file("*.png") var combat_stance_texture_path := "res://assets/characters/lian_wu/character_lock/lian_wu_combat_stance.png"
@export var fighter_visual_height := 96.0
@export var show_combat_stance := false

var _fighter: FighterController
var _sprite: Sprite2D
var _neutral: Texture2D
var _combat_stance: Texture2D

func _ready() -> void:
	_fighter = get_parent() as FighterController
	_sprite = Sprite2D.new()
	_sprite.name = "LianWuCharacterLockSprite"
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.z_index = 4
	add_child(_sprite)
	_neutral = _load_texture(neutral_texture_path)
	_combat_stance = _load_texture(combat_stance_texture_path)
	_apply_pose()

func _process(_delta: float) -> void:
	if not is_instance_valid(_fighter) or not is_instance_valid(_sprite):
		return
	_sprite.flip_h = _fighter.facing < 0.0

func set_combat_stance(enabled: bool) -> void:
	show_combat_stance = enabled
	_apply_pose()

func bench_report() -> Dictionary:
	var failures: Array[String] = []
	if not is_instance_valid(_fighter):
		failures.append("bench must be a child of FighterController")
	if not is_instance_valid(_neutral):
		failures.append("neutral texture missing")
	if not is_instance_valid(_combat_stance):
		failures.append("combat stance texture missing")
	if is_instance_valid(_neutral) and _neutral.get_size() != Vector2(1024, 1024):
		failures.append("neutral canvas must be 1024x1024")
	if is_instance_valid(_combat_stance) and _combat_stance.get_size() != Vector2(1024, 1024):
		failures.append("combat stance canvas must be 1024x1024")
	return {
		"schema": "tehkne/taijifu-character-lock-bench/v1",
		"signature": "Tehkné Solutions",
		"character_id": String(CHARACTER_ID),
		"required_viewport": REQUIRED_VIEWPORT,
		"pivot_normalized": PIVOT_NORMALIZED,
		"native_facing": "right",
		"neutral_loaded": is_instance_valid(_neutral),
		"combat_stance_loaded": is_instance_valid(_combat_stance),
		"flip_runtime_bound": is_instance_valid(_fighter),
		"fighter_visual_height": fighter_visual_height,
		"failures": failures,
		"status": "pass" if failures.is_empty() else "blocked"
	}

func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _apply_pose() -> void:
	if not is_instance_valid(_sprite):
		return
	var texture := _combat_stance if show_combat_stance else _neutral
	if not is_instance_valid(texture):
		_sprite.visible = false
		return
	_sprite.texture = texture
	var size := texture.get_size()
	var opaque_visual_height := maxf(1.0, size.y * 0.89)
	var scale_factor := fighter_visual_height / opaque_visual_height
	_sprite.scale = Vector2.ONE * scale_factor
	# Sprite2D centered=false makes the canonical normalized pivot explicit.
	_sprite.position = Vector2(
		-size.x * PIVOT_NORMALIZED.x * scale_factor,
		-size.y * PIVOT_NORMALIZED.y * scale_factor
	)
	_sprite.visible = true
