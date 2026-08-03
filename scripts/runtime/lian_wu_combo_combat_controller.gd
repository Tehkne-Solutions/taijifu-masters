class_name LianWuComboCombatController
extends "res://scripts/runtime/lian_wu_body_hook_combat_controller.gd"

## VM02-C5 — buffered two-hit combo foundation.
## Tehkné Solutions

signal combo_buffered(combo_index: int)
signal combo_completed(combo_hits: int)

const COMBO_MAX := 2
const CANCEL_WINDOW_RATIO := 0.45

var combo_index := 0
var combo_hits := 0
var combo_buffer_open := false
var combo_attack_queued := false
var _combo_test_edge := false

func _ready() -> void:
	super._ready()
	body_hook_completed.connect(_on_combo_attack_completed)

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
			print("VM02_C5_COMBO_BUFFERED=%d" % (combo_index + 1))
	super._physics_process(delta)

func _begin_body_hook() -> void:
	if attack_phase != "idle":
		return
	if combo_index == 0:
		combo_index = 1
	elif combo_attack_queued:
		combo_index += 1
		combo_attack_queued = false
	combo_buffer_open = false
	super._begin_body_hook()
	print("VM02_C5_COMBO_ATTACK=%d" % combo_index)

func _update_combo_buffer_state() -> void:
	combo_buffer_open = false
	if attack_phase != "recovery" or combo_index <= 0 or combo_index >= COMBO_MAX or _technique == null:
		return
	var duration: float = maxf(float(_technique.recovery_seconds()), 0.0001)
	var ratio: float = clampf(attack_phase_elapsed / duration, 0.0, 1.0)
	combo_buffer_open = ratio >= CANCEL_WINDOW_RATIO

func _on_combo_attack_completed() -> void:
	combo_hits += 1
	if combo_attack_queued and combo_index < COMBO_MAX:
		# Parent already returned to idle; consume the buffered attack immediately.
		_begin_body_hook()
		return
	var completed := combo_index
	combo_index = 0
	combo_attack_queued = false
	combo_buffer_open = false
	combo_completed.emit(completed)
	print("VM02_C5_COMBO_COMPLETE=%d" % completed)
