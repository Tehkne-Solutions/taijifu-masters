class_name RosterHudRuntime
extends Node

@onready var main: Node = get_parent()
@onready var player_one_label: Label = get_node("../HUD/PlayerOne")
@onready var player_two_label: Label = get_node("../HUD/PlayerTwo")
@onready var controls_label: Label = get_node("../HUD/Controls")

func _process(_delta: float) -> void:
	_sync_character_headings()
	if not controls_label.text.contains("O inspetor"):
		controls_label.text += "\nO inspetor visual de assets"
	if not controls_label.text.contains("F6 editor"):
		controls_label.text += " • F6 editor de encaixes"

func _sync_character_headings() -> void:
	var player_one: FighterController = main.get("player_one") as FighterController
	var player_two: FighterController = main.get("player_two") as FighterController
	if is_instance_valid(player_one) and is_instance_valid(player_two):
		player_one_label.text = _replace_first_line(player_one_label.text, "P1 — %s" % player_one.build.character_name.to_upper())
		player_two_label.text = _replace_first_line(player_two_label.text, "P2 — %s" % player_two.build.character_name.to_upper())
		return
	var preset_ids: Array = main.get("_preset_ids")
	var selected_indices: Array = main.get("_selected_preset_indices")
	if preset_ids.size() < 1 or selected_indices.size() < 2:
		return
	var p1_index := clampi(int(selected_indices[0]), 0, preset_ids.size() - 1)
	var p2_index := clampi(int(selected_indices[1]), 0, preset_ids.size() - 1)
	var p1_build := BuildProfile.prototype_preset(StringName(preset_ids[p1_index]))
	var p2_build := BuildProfile.prototype_preset(StringName(preset_ids[p2_index]))
	player_one_label.text = _replace_first_line(player_one_label.text, "P1 — %s" % p1_build.character_name.to_upper())
	player_two_label.text = _replace_first_line(player_two_label.text, "P2 — %s" % p2_build.character_name.to_upper())

func _replace_first_line(source: String, heading: String) -> String:
	var lines := source.split("\n")
	if lines.is_empty():
		return heading
	lines[0] = heading
	return "\n".join(lines)
