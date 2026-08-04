class_name CanonicalArenaParallax
extends Node2D

const ARENA_ROOT := "res://assets/pack_03_stages/mountain_dojo_night"
const BACKGROUND := ARENA_ROOT + "/background.png"
const MIDGROUND := ARENA_ROOT + "/midground.png"
const FOREGROUND := ARENA_ROOT + "/foreground.png"

var _camera: Camera2D
var _camera_origin := Vector2.ZERO
var _layers: Array[Sprite2D] = []

func _ready() -> void:
	name = "CanonicalArenaParallax"
	z_index = -20
	_camera = get_parent().get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(_camera):
		_camera_origin = _camera.global_position
	_build_layer(BACKGROUND, "Background", -20, 0.18)
	_build_layer(MIDGROUND, "Midground", -12, 0.48)
	_build_layer(FOREGROUND, "Foreground", 3, 1.0)

func _load_texture_from_png(path: String) -> Texture2D:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.new()
	var err := image.load(absolute_path)
	if err != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _build_layer(path: String, layer_name: String, layer_z: int, ratio: float) -> void:
	var texture := _load_texture_from_png(path)
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = layer_name
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.z_index = layer_z
	sprite.set_meta("parallax_ratio", ratio)
	add_child(sprite)
	_layers.append(sprite)

func _process(_delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	var camera_delta := _camera.global_position - _camera_origin
	for sprite in _layers:
		var ratio := float(sprite.get_meta("parallax_ratio", 1.0))
		sprite.position = Vector2(camera_delta.x * (1.0 - ratio), camera_delta.y * (1.0 - ratio))

func canonical_ready() -> bool:
	return _layers.size() == 3

func presentation_signature() -> Dictionary:
	return {
		"arena_id": &"mountain_dojo_night",
		"canonical_layers": _layers.size(),
		"background_ratio": 0.18,
		"midground_ratio": 0.48,
		"foreground_ratio": 1.0,
		"procedural_placeholder": false,
		"visible_grid": false,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
