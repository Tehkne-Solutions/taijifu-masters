class_name ModularFighterAssembler
extends Node2D

## Runtime visual assembler for the Taijifu Modular Fighter System.
## BASE-00 owns body/rig; visual modules attach by canonical slots.
## Tehkné Solutions

const STANDARD_PATH := "res://config/modular-fighter-standard-v1.json"
const BASE_PATH := "res://config/fighter-bases/base_fighter_v1.json"

var _profile: ModularFighterProfile
var _layers: Dictionary = {}
var _ready_for_render := false

func configure(profile: ModularFighterProfile) -> PackedStringArray:
	_clear_layers()
	_profile = profile
	var failures := PackedStringArray()
	if _profile == null:
		failures.append("profile_missing")
		return failures
	failures.append_array(_profile.validate_against_standard())
	if not failures.is_empty():
		return failures
	if not FileAccess.file_exists(BASE_PATH):
		failures.append("base_fighter_contract_missing")
		return failures
	_ready_for_render = true
	return failures

func attach_visual_module(slot: StringName, node: CanvasItem) -> bool:
	if not _ready_for_render or node == null:
		return false
	var slot_name := String(slot)
	if not _allowed_slots().has(slot_name):
		return false
	if _layers.has(slot_name):
		var previous = _layers[slot_name]
		if is_instance_valid(previous):
			previous.queue_free()
	_layers[slot_name] = node
	node.name = "Module_%s" % slot_name
	add_child(node)
	return true

func clear_visual_module(slot: StringName) -> void:
	var key := String(slot)
	if not _layers.has(key):
		return
	var node = _layers[key]
	_layers.erase(key)
	if is_instance_valid(node):
		node.queue_free()

func is_ready_for_render() -> bool:
	return _ready_for_render

func profile_id() -> StringName:
	return _profile.profile_id if _profile != null else &""

func _clear_layers() -> void:
	for node in _layers.values():
		if is_instance_valid(node):
			node.queue_free()
	_layers.clear()
	_ready_for_render = false

func _allowed_slots() -> PackedStringArray:
	var result := PackedStringArray()
	if not FileAccess.file_exists(STANDARD_PATH):
		return result
	var file := FileAccess.open(STANDARD_PATH, FileAccess.READ)
	if file == null:
		return result
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return result
	for slot in parsed.get("slots", []):
		result.append(String(slot))
	return result
