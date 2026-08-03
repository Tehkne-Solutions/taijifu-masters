class_name OpponentVisualSparringRival
extends Sprite2D

## VM02-C9 — provisional visual sparring rival.
## Reuses the validated Lian Wu Character Lock with mirrored facing + palette modulation
## until the second canonical fighter pack is produced.
## Tehkné Solutions

const IDLE_PATH := "res://assets/pack_01_characters/lian_wu/frames/idle/char_lian_wu__idle__f01.png"
const APPROACH_PATH := "res://assets/pack_01_characters/lian_wu/frames/walk/char_lian_wu__walk__f03.png"
const ATTACK_PATH := "res://assets/pack_01_characters/lian_wu/frames/attacks/ji_body_hook/char_lian_wu__ji_body_hook__f04.png"
const HITSTUN_PATH := "res://assets/pack_01_characters/lian_wu/frames/fall/char_lian_wu__fall__f03.png"

var visual_state := "idle"
var visual_ready := false
var _textures: Dictionary = {}

func _ready() -> void:
	centered = true
	flip_h = true
	self_modulate = Color(0.88, 0.62, 0.58, 1.0)
	for state_name in ["idle", "approach", "attack", "hitstun"]:
		var path := _path_for_state(state_name)
		var texture := _load_png_texture(path)
		if texture == null:
			push_error("VM02_C9 missing visual state %s at %s" % [state_name, path])
			continue
		_textures[state_name] = texture
	visual_ready = _textures.size() == 4
	set_visual_state("idle")
	print("VM02_C9_VISUAL_RIVAL_READY=%s states=%d" % [("PASS" if visual_ready else "BLOCKED"), _textures.size()])

func set_visual_state(state_name: String) -> void:
	visual_state = state_name
	if _textures.has(state_name):
		texture = _textures[state_name]
	if state_name == "hitstun":
		self_modulate = Color(1.0, 0.72, 0.38, 1.0)
	elif state_name == "attack":
		self_modulate = Color(0.96, 0.52, 0.46, 1.0)
	else:
		self_modulate = Color(0.88, 0.62, 0.58, 1.0)

func _path_for_state(state_name: String) -> String:
	match state_name:
		"approach": return APPROACH_PATH
		"attack": return ATTACK_PATH
		"hitstun": return HITSTUN_PATH
		_: return IDLE_PATH

func _load_png_texture(res_path: String) -> Texture2D:
	var absolute := ProjectSettings.globalize_path(res_path)
	var image := Image.load_from_file(absolute)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
