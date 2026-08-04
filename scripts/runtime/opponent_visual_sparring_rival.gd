class_name OpponentVisualSparringRival
extends Sprite2D

## VM02-C36 — canonical Training Rival runtime binding with C9 proxy fallback.
## Canonical art wins automatically once C28 imports the complete 44-frame pack.
## Tehkné Solutions

const CANONICAL_ROOT := "res://assets/pack_02_characters/training_rival/first_playable_lot_01/animations"
const CANONICAL_STATE_PATHS := {
	"idle": CANONICAL_ROOT + "/idle/char_training_rival__idle__f001.png",
	"approach": CANONICAL_ROOT + "/run/char_training_rival__run__f003.png",
	"attack": CANONICAL_ROOT + "/attack_light/char_training_rival__attack_light__f004.png",
	"hitstun": CANONICAL_ROOT + "/hit/char_training_rival__hit__f002.png",
}

const PROXY_STATE_PATHS := {
	"idle": "res://assets/pack_01_characters/lian_wu/frames/idle/char_lian_wu__idle__f01.png",
	"approach": "res://assets/pack_01_characters/lian_wu/frames/walk/char_lian_wu__walk__f03.png",
	"attack": "res://assets/pack_01_characters/lian_wu/frames/attacks/ji_body_hook/char_lian_wu__ji_body_hook__f04.png",
	"hitstun": "res://assets/pack_01_characters/lian_wu/frames/fall/char_lian_wu__fall__f03.png",
}

var visual_state := "idle"
var visual_ready := false
var canonical_visual_active := false
var _textures: Dictionary = {}

func _ready() -> void:
	centered = true
	canonical_visual_active = _canonical_pack_available()
	_configure_identity()
	for state_name in ["idle", "approach", "attack", "hitstun"]:
		var path := _path_for_state(state_name)
		var loaded_texture := _load_png_texture(path)
		if loaded_texture == null:
			push_error("VM02_C36 missing visual state %s at %s" % [state_name, path])
			continue
		_textures[state_name] = loaded_texture
	visual_ready = _textures.size() == 4
	set_visual_state("idle")
	print("VM02_C36_VISUAL_RIVAL_READY=%s states=%d canonical=%s" % [
		("PASS" if visual_ready else "BLOCKED"),
		_textures.size(),
		str(canonical_visual_active).to_lower()
	])

func _canonical_pack_available() -> bool:
	for state_name in CANONICAL_STATE_PATHS.keys():
		var absolute := ProjectSettings.globalize_path(str(CANONICAL_STATE_PATHS[state_name]))
		if not FileAccess.file_exists(absolute):
			return false
	return true

func _configure_identity() -> void:
	if canonical_visual_active:
		# Native facing is left; no mirror and no proxy palette tint.
		flip_h = false
		self_modulate = Color.WHITE
	else:
		flip_h = true
		self_modulate = Color(0.88, 0.62, 0.58, 1.0)

func set_visual_state(state_name: String) -> void:
	visual_state = state_name
	if _textures.has(state_name):
		texture = _textures[state_name]
	if canonical_visual_active:
		self_modulate = Color.WHITE
	elif state_name == "hitstun":
		self_modulate = Color(1.0, 0.72, 0.38, 1.0)
	elif state_name == "attack":
		self_modulate = Color(0.96, 0.52, 0.46, 1.0)
	else:
		self_modulate = Color(0.88, 0.62, 0.58, 1.0)

func _path_for_state(state_name: String) -> String:
	var table: Dictionary = CANONICAL_STATE_PATHS if canonical_visual_active else PROXY_STATE_PATHS
	return str(table.get(state_name, table["idle"]))

func _load_png_texture(res_path: String) -> Texture2D:
	var absolute := ProjectSettings.globalize_path(res_path)
	var image := Image.load_from_file(absolute)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func presentation_signature() -> Dictionary:
	return {
		"character_id": &"training_rival",
		"canonical_visual": canonical_visual_active,
		"proxy_visual": not canonical_visual_active,
		"native_facing": &"left" if canonical_visual_active else &"proxy_mirrored",
		"mirrored_lian_wu_proxy": not canonical_visual_active,
		"visual_states": _textures.size(),
		"signature": "Tehkné Solutions"
	}
