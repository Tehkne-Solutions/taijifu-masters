class_name HeatmapRuntime
extends Node2D

const HEATMAP_DIR := "user://telemetry"
const CELL_SIZE := 140.0
const SAMPLE_INTERVAL := 0.16
const FALL_THRESHOLD := TriplePathArena.WORLD_HEIGHT + 70.0

@onready var intelligence_runtime: PrototypeIntelligenceRuntime = get_node("../PrototypeIntelligenceRuntime")
@onready var tactical_bot: TacticalBotRuntime = get_node("../TacticalBotRuntime")
@onready var hud: CanvasLayer = get_node("../HUD")

var _cells: Dictionary = {"p1": {}, "p2": {}}
var _falls: Dictionary = {"p1": [], "p2": []}
var _fall_armed: Dictionary = {"p1": true, "p2": true}
var _sample_timer := 0.0
var _rounds_recorded := 0
var _visible := false
var _session_id := ""
var _saved_path := ""
var _status_label: Label

func _ready() -> void:
	_session_id = "%d-%d" % [int(Time.get_unix_time_from_system()), randi_range(1000, 9999)]
	_register_toggle_action()
	_create_status_label()
	intelligence_runtime.round_report_ready.connect(_on_round_report_ready)
	z_index = 18
	queue_redraw()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"toggle_heatmap"):
		_visible = not _visible
		queue_redraw()
		_update_status_label()

	_sample_timer -= delta
	if _sample_timer <= 0.0:
		_sample_timer = SAMPLE_INTERVAL
		_sample_fighters()

func _sample_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is FighterController):
			continue
		var fighter := node as FighterController
		var profile_id := "p%d" % fighter.player_index
		_record_position(profile_id, fighter.global_position)
		_record_fall_if_needed(profile_id, fighter.global_position)
	if _visible:
		queue_redraw()

func _record_position(profile_id: String, position: Vector2) -> void:
	var grid_x := floori(position.x / CELL_SIZE)
	var grid_y := floori(position.y / CELL_SIZE)
	var cell_key := "%d:%d" % [grid_x, grid_y]
	var profile_cells: Dictionary = _cells.get(profile_id, {})
	profile_cells[cell_key] = int(profile_cells.get(cell_key, 0)) + 1
	_cells[profile_id] = profile_cells

func _record_fall_if_needed(profile_id: String, position: Vector2) -> void:
	var armed := bool(_fall_armed.get(profile_id, true))
	if position.y > FALL_THRESHOLD and armed:
		var profile_falls: Array = _falls.get(profile_id, [])
		profile_falls.append({
			"x": position.x,
			"y": minf(position.y, FALL_THRESHOLD + 80.0),
			"round": _rounds_recorded + 1,
			"at_unix": int(Time.get_unix_time_from_system())
		})
		_falls[profile_id] = profile_falls
		_fall_armed[profile_id] = false
	elif position.y < TriplePathArena.WORLD_HEIGHT - 70.0:
		_fall_armed[profile_id] = true

func _on_round_report_ready(_report: Dictionary, _telemetry_path: String) -> void:
	_rounds_recorded += 1
	_saved_path = _write_heatmap()
	_update_status_label()
	if _visible:
		queue_redraw()

func _write_heatmap() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HEATMAP_DIR))
	var path := "%s/heatmap_%s.json" % [HEATMAP_DIR, _session_id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify({
		"version": 1,
		"session_id": _session_id,
		"updated_unix": int(Time.get_unix_time_from_system()),
		"rounds_recorded": _rounds_recorded,
		"cell_size": CELL_SIZE,
		"bot": {
			"difficulty": String(tactical_bot.difficulty_id),
			"personality": String(tactical_bot.personality_id)
		},
		"cells": _cells,
		"falls": _falls,
		"summary": _summary()
	}, "\t"))
	return path

func _summary() -> Dictionary:
	return {
		"p1_hottest_cell": _hottest_cell("p1"),
		"p2_hottest_cell": _hottest_cell("p2"),
		"p1_falls": (_falls.get("p1", []) as Array).size(),
		"p2_falls": (_falls.get("p2", []) as Array).size()
	}

func _hottest_cell(profile_id: String) -> Dictionary:
	var profile_cells: Dictionary = _cells.get(profile_id, {})
	var best_key := ""
	var best_count := 0
	for key_variant in profile_cells.keys():
		var count := int(profile_cells[key_variant])
		if count > best_count:
			best_count = count
			best_key = String(key_variant)
	return {"cell": best_key, "samples": best_count}

func _draw() -> void:
	if not _visible:
		return
	_draw_profile_cells("p1", Color(0.18, 0.62, 1.0), 0.0)
	_draw_profile_cells("p2", Color(1.0, 0.34, 0.16), 10.0)
	_draw_falls("p1", Color(0.42, 0.82, 1.0))
	_draw_falls("p2", Color(1.0, 0.62, 0.32))

func _draw_profile_cells(profile_id: String, color: Color, inset: float) -> void:
	var profile_cells: Dictionary = _cells.get(profile_id, {})
	var maximum := 1
	for count_variant in profile_cells.values():
		maximum = maxi(maximum, int(count_variant))
	for key_variant in profile_cells.keys():
		var parts := String(key_variant).split(":")
		if parts.size() != 2:
			continue
		var grid_x := int(parts[0])
		var grid_y := int(parts[1])
		var count := int(profile_cells[key_variant])
		var ratio := clampf(float(count) / float(maximum), 0.0, 1.0)
		var rect := Rect2(
			Vector2(grid_x * CELL_SIZE + inset, grid_y * CELL_SIZE + inset),
			Vector2(CELL_SIZE - inset * 2.0, CELL_SIZE - inset * 2.0)
		)
		draw_rect(rect, Color(color, 0.05 + ratio * 0.30), true)
		draw_rect(rect, Color(color, 0.14 + ratio * 0.26), false, 2.0)

func _draw_falls(profile_id: String, color: Color) -> void:
	var profile_falls: Array = _falls.get(profile_id, [])
	for fall_variant in profile_falls:
		if not (fall_variant is Dictionary):
			continue
		var fall: Dictionary = fall_variant
		var position := Vector2(float(fall.get("x", 0.0)), float(fall.get("y", FALL_THRESHOLD)))
		draw_circle(position, 18.0, Color(color, 0.28))
		draw_line(position + Vector2(-14, -14), position + Vector2(14, 14), color, 4.0)
		draw_line(position + Vector2(-14, 14), position + Vector2(14, -14), color, 4.0)

func _register_toggle_action() -> void:
	if not InputMap.has_action(&"toggle_heatmap"):
		InputMap.add_action(&"toggle_heatmap")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F3
	for existing in InputMap.action_get_events(&"toggle_heatmap"):
		if existing is InputEventKey and existing.physical_keycode == KEY_F3:
			return
	InputMap.action_add_event(&"toggle_heatmap", event)

func _create_status_label() -> void:
	_status_label = Label.new()
	_status_label.offset_left = 24.0
	_status_label.offset_top = 176.0
	_status_label.offset_right = 430.0
	_status_label.offset_bottom = 206.0
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.64, 0.82, 1.0, 0.92))
	hud.add_child(_status_label)
	_update_status_label()

func _update_status_label() -> void:
	if not is_instance_valid(_status_label):
		return
	var mode_label := "VISÍVEL" if _visible else "OCULTO"
	var p1_falls := (_falls.get("p1", []) as Array).size()
	var p2_falls := (_falls.get("p2", []) as Array).size()
	_status_label.text = "F3 HEATMAP %s • ROUNDS %d • QUEDAS P1 %d / P2 %d%s" % [
		mode_label,
		_rounds_recorded,
		p1_falls,
		p2_falls,
		" • %s" % _saved_path.get_file() if _saved_path != "" else ""
	]

func _exit_tree() -> void:
	if not _cells.is_empty():
		_write_heatmap()
