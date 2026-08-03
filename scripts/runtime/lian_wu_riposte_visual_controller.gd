class_name LianWuRiposteVisualController
extends "res://scripts/runtime/lian_wu_body_hook_sweep_combo_controller.gd"

## VM02-C20 — dedicated riposte visual handoff.
## Tehkné Solutions

const RIPOSTE_FRAME_DIR := "res://assets/pack_01_characters/lian_wu/frames/attacks/ji_riposte"

var _riposte_textures: Array[Texture2D] = []
var _riposte_bounds: Array[Rect2i] = []
var riposte_visual_ready := false
var riposte_visual_bind_count := 0

func _ready() -> void:
	super._ready()
	_load_riposte_frames()
	riposte_visual_ready = _riposte_textures.size() == ATTACK_FRAME_COUNT and _riposte_bounds.size() == ATTACK_FRAME_COUNT
	print("VM02_C20_RIPOSTE_VISUAL_READY=%s frames=%d" % [("PASS" if riposte_visual_ready else "BLOCKED"), _riposte_textures.size()])

func bind_riposte_visual() -> bool:
	if not riposte_visual_ready:
		print("VM02_C20_RIPOSTE_VISUAL_BIND=BLOCKED frames=%d" % _riposte_textures.size())
		return false
	_attack_textures = _riposte_textures.duplicate()
	_attack_bounds = _riposte_bounds.duplicate()
	riposte_visual_bind_count += 1
	_update_attack_visual()
	print("VM02_C20_RIPOSTE_VISUAL_BIND=PASS count=%d" % riposte_visual_bind_count)
	return true

func _load_riposte_frames() -> void:
	_riposte_textures.clear()
	_riposte_bounds.clear()
	for frame_number in range(1, ATTACK_FRAME_COUNT + 1):
		var path := "%s/char_lian_wu__ji_riposte__f%02d.png" % [RIPOSTE_FRAME_DIR, frame_number]
		var texture := _load_png_texture(path)
		if texture == null:
			push_error("missing C20 riposte frame %s" % path)
			continue
		var frame_bounds := _alpha_bounds(texture)
		if frame_bounds.size == Vector2i.ZERO:
			push_error("empty C20 riposte frame %s" % path)
			continue
		_riposte_textures.append(texture)
		_riposte_bounds.append(frame_bounds)
