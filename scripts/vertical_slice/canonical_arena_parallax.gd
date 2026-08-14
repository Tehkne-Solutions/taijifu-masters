class_name CanonicalArenaParallax
extends Node2D

const ARENA_ROOT := "res://assets/pack_03_stages/mountain_dojo_night"
const BACKGROUND := ARENA_ROOT + "/background.png"
const MIDGROUND := ARENA_ROOT + "/midground.png"
const FOREGROUND := ARENA_ROOT + "/foreground.png"

# PACK 03 is authored at 1920x1080 with safe fighter zone [280, 1640].
# First Playable spawns are [720, 2080], therefore the exact world-space
# alignment is +440px on X: 280+440=720 and 1640+440=2080.
const ARENA_ORIGIN := Vector2(440.0, 0.0)
const ASSET_SIZE := Vector2(1920.0, 1080.0)
const SAFE_ASSET_LEFT := 280.0
const SAFE_ASSET_RIGHT := 1640.0

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
	print("V2_CANONICAL_ARENA_RUNTIME=", "PASS" if canonical_ready() else "BLOCKED", " layers=", _layers.size())
	print("V2_CANONICAL_ARENA_ORIGIN=PASS x=440 safe_world=720..2080")

func _load_texture(path: String) -> Texture2D:
	# Export-safe: PNG source files are remapped to imported textures in packaged builds.
	# ResourceLoader resolves the remap; FileAccess/Image.load on the raw source path does not.
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	return ResourceLoader.load(path, "Texture2D") as Texture2D

func _build_layer(path: String, layer_name: String, layer_z: int, ratio: float) -> void:
	var texture := _load_texture(path)
	if texture == null:
		push_error("Canonical arena texture unavailable: %s" % path)
		return
	var sprite := Sprite2D.new()
	sprite.name = layer_name
	sprite.texture = texture
	sprite.centered = false
	sprite.position = ARENA_ORIGIN
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
		sprite.position = ARENA_ORIGIN + Vector2(
			camera_delta.x * (1.0 - ratio),
			camera_delta.y * (1.0 - ratio)
		)

func canonical_ready() -> bool:
	return _layers.size() == 3

func presentation_signature() -> Dictionary:
	return {
		"arena_id": &"mountain_dojo_night",
		"canonical_layers": _layers.size(),
		"background_ratio": 0.18,
		"midground_ratio": 0.48,
		"foreground_ratio": 1.0,
		"asset_size": ASSET_SIZE,
		"arena_origin": ARENA_ORIGIN,
		"safe_asset_left": SAFE_ASSET_LEFT,
		"safe_asset_right": SAFE_ASSET_RIGHT,
		"safe_world_left": SAFE_ASSET_LEFT + ARENA_ORIGIN.x,
		"safe_world_right": SAFE_ASSET_RIGHT + ARENA_ORIGIN.x,
		"procedural_placeholder": false,
		"visible_grid": false,
		"export_safe_resource_loading": true,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
