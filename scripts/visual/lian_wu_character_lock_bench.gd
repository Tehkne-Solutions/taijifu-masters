class_name LianWuCharacterLockBench
extends Node2D

## VM01-A3/A4 deterministic in-engine bench for the recovered Lian Wu Character Lock.
## Tehkné Solutions

const CHARACTER_ID := &"lian_wu"
const REQUIRED_OUTPUT_SIZE := Vector2i(1920, 1080)
const LOGICAL_VIEWPORT_SIZE := Vector2i(1280, 720)
const NATIVE_FACING := 1.0
const ALPHA_THRESHOLD := 0.01

@export_file("*.png") var neutral_texture_path := "res://assets/characters/lian_wu/character_lock/lian_wu_neutral.png"
@export_file("*.png") var combat_stance_texture_path := "res://assets/characters/lian_wu/character_lock/lian_wu_combat_stance.png"
@export var fighter_visual_height := 96.0
@export var show_combat_stance := false

var _fighter: FighterController
var _sprite: Sprite2D
var _neutral: Texture2D
var _combat_stance: Texture2D
var _neutral_alpha_bounds := Rect2i()
var _combat_alpha_bounds := Rect2i()

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
	_neutral_alpha_bounds = _alpha_bounds(_neutral)
	_combat_alpha_bounds = _alpha_bounds(_combat_stance)
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
	if _neutral_alpha_bounds.size == Vector2i.ZERO:
		failures.append("neutral alpha bounds missing")
	if _combat_alpha_bounds.size == Vector2i.ZERO:
		failures.append("combat stance alpha bounds missing")
	var neutral_pivot := _pivot_from_bounds(_neutral_alpha_bounds)
	var combat_pivot := _pivot_from_bounds(_combat_alpha_bounds)
	if absf(neutral_pivot.x - combat_pivot.x) > 2.0:
		failures.append("neutral/combat source pivot x differs by more than 2px")
	if absf(neutral_pivot.y - combat_pivot.y) > 2.0:
		failures.append("neutral/combat feet baseline differs by more than 2px")
	return {
		"schema": "tehkne/taijifu-character-lock-bench/v2",
		"signature": "Tehkné Solutions",
		"character_id": String(CHARACTER_ID),
		"required_output_size": REQUIRED_OUTPUT_SIZE,
		"logical_viewport_size": LOGICAL_VIEWPORT_SIZE,
		"pivot_policy": "alpha_bounds_bottom_center",
		"neutral_alpha_bounds": _neutral_alpha_bounds,
		"combat_alpha_bounds": _combat_alpha_bounds,
		"neutral_source_pivot": neutral_pivot,
		"combat_source_pivot": combat_pivot,
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
	var bounds := _combat_alpha_bounds if show_combat_stance else _neutral_alpha_bounds
	if not is_instance_valid(texture) or bounds.size == Vector2i.ZERO:
		_sprite.visible = false
		return
	_sprite.texture = texture
	var visual_height := maxf(1.0, float(bounds.size.y))
	var scale_factor := fighter_visual_height / visual_height
	var source_pivot := _pivot_from_bounds(bounds)
	_sprite.scale = Vector2.ONE * scale_factor
	# Align the actual opaque silhouette bottom-center to FighterController origin.
	_sprite.position = -source_pivot * scale_factor
	_sprite.visible = true

func _alpha_bounds(texture: Texture2D) -> Rect2i:
	if not is_instance_valid(texture):
		return Rect2i()
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2i()
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= ALPHA_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _pivot_from_bounds(bounds: Rect2i) -> Vector2:
	if bounds.size == Vector2i.ZERO:
		return Vector2.ZERO
	return Vector2(
		float(bounds.position.x) + float(bounds.size.x - 1) * 0.5,
		float(bounds.position.y + bounds.size.y - 1)
	)
