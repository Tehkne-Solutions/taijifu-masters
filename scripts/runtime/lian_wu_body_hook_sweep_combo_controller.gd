class_name LianWuBodyHookSweepComboController
extends "res://scripts/runtime/lian_wu_body_hook_combat_controller.gd"

## VM02-C7 — heterogeneous combo: ji_body_hook -> ji_sweep.
## Tehkné Solutions

signal combo_buffered(combo_index: int)
signal combo_completed(combo_hits: int)
signal combo_link_started(index: int, technique_id: StringName)

const COMBO_MAX := 2
const CANCEL_WINDOW_RATIO := 0.45
const SWEEP_ID := &"ji_sweep"
const SWEEP_FRAME_DIR := "res://assets/pack_01_characters/lian_wu/frames/attacks/ji_sweep"

var combo_index := 0
var combo_hits := 0
var combo_buffer_open := false
var combo_attack_queued := false
var current_technique_id: StringName = TECHNIQUE_ID
var _combo_test_edge := false

var _body_hook_textures: Array[Texture2D] = []
var _body_hook_bounds: Array[Rect2i] = []
var _sweep_textures: Array[Texture2D] = []
var _sweep_bounds: Array[Rect2i] = []
var _body_hook_technique
var _sweep_technique

func _ready() -> void:
	super._ready()
	_body_hook_textures = _attack_textures.duplicate()
	_body_hook_bounds = _attack_bounds.duplicate()
	_body_hook_technique = TechniqueCatalog.get_technique(TECHNIQUE_ID)
	_sweep_technique = TechniqueCatalog.get_technique(SWEEP_ID)
	_load_sweep_frames()
	body_hook_completed.connect(_on_combo_link_completed)
	print("VM02_C7_SWEEP_VISUAL_FRAMES=%d" % _sweep_textures.size())

func set_test_combo_edge(value: bool) -> void:
	_combo_test_edge = value

func _physics_process(delta: float) -> void:
	_update_combo_buffer_state()
	if attack_phase == "recovery" and combo_buffer_open and combo_index < COMBO_MAX:
		var requested := false
		if _test_override:
			requested = _combo_test_edge
			_combo_test_edge = false
		else:
			requested = Input.is_action_just_pressed(&"p1_attack")
		if requested and not combo_attack_queued:
			combo_attack_queued = true
			combo_buffered.emit(combo_index + 1)
			print("VM02_C7_COMBO_BUFFERED=%d" % (combo_index + 1))
	super._physics_process(delta)

func _begin_body_hook() -> void:
	if attack_phase != "idle":
		return
	if combo_index == 0:
		combo_index = 1
		_bind_body_hook()
	elif combo_attack_queued and combo_index < COMBO_MAX:
		combo_index += 1
		combo_attack_queued = false
		_bind_sweep()
	else:
		return
	combo_buffer_open = false
	_start_bound_attack()
	combo_link_started.emit(combo_index, current_technique_id)
	print("VM02_C7_COMBO_LINK=%d technique=%s" % [combo_index, String(current_technique_id)])

func _bind_body_hook() -> void:
	current_technique_id = TECHNIQUE_ID
	_technique = _body_hook_technique
	_attack_textures = _body_hook_textures.duplicate()
	_attack_bounds = _body_hook_bounds.duplicate()

func _bind_sweep() -> void:
	current_technique_id = SWEEP_ID
	_technique = _sweep_technique
	_attack_textures = _sweep_textures.duplicate()
	_attack_bounds = _sweep_bounds.duplicate()

func _start_bound_attack() -> void:
	if _attack_textures.size() != ATTACK_FRAME_COUNT or _technique == null:
		return
	body_hook_count += 1
	attack_phase = "startup"
	attack_phase_elapsed = 0.0
	attack_keypose = 0
	active_keypose_observed = false
	velocity.x = 0.0
	_set_attack_hitbox(false)
	_configure_hitbox()
	attack_phase_changed.emit(attack_phase)
	print("VM02_C7_ATTACK_PHASE=startup technique=%s" % String(current_technique_id))
	_update_attack_visual()

func _update_combo_buffer_state() -> void:
	combo_buffer_open = false
	if attack_phase != "recovery" or combo_index <= 0 or combo_index >= COMBO_MAX or _technique == null:
		return
	var duration: float = maxf(float(_technique.recovery_seconds()), 0.0001)
	var ratio: float = clampf(attack_phase_elapsed / duration, 0.0, 1.0)
	combo_buffer_open = ratio >= CANCEL_WINDOW_RATIO

func _on_combo_link_completed() -> void:
	combo_hits += 1
	if combo_attack_queued and combo_index < COMBO_MAX:
		_begin_body_hook()
		return
	var completed := combo_index
	combo_index = 0
	combo_attack_queued = false
	combo_buffer_open = false
	combo_completed.emit(completed)
	print("VM02_C7_COMBO_COMPLETE=%d" % completed)

func _load_sweep_frames() -> void:
	_sweep_textures.clear()
	_sweep_bounds.clear()
	for frame_number in range(1, ATTACK_FRAME_COUNT + 1):
		var path := "%s/char_lian_wu__ji_sweep__f%02d.png" % [SWEEP_FRAME_DIR, frame_number]
		var texture := _load_png_texture(path)
		if texture == null:
			push_error("missing C7 sweep frame %s" % path)
			continue
		var frame_bounds := _alpha_bounds(texture)
		if frame_bounds.size == Vector2i.ZERO:
			push_error("empty C7 sweep frame %s" % path)
			continue
		_sweep_textures.append(texture)
		_sweep_bounds.append(frame_bounds)
