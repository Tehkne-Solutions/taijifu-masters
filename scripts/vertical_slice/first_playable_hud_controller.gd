class_name FirstPlayableHudController
extends Node

signal rematch_requested
signal menu_requested
signal resume_requested

@onready var p1_health: ProgressBar = get_node("../HUD/P1Health")
@onready var p1_posture: ProgressBar = get_node("../HUD/P1Posture")
@onready var p1_stamina: ProgressBar = get_node("../HUD/P1Stamina")
@onready var p2_health: ProgressBar = get_node("../HUD/P2Health")
@onready var p2_posture: ProgressBar = get_node("../HUD/P2Posture")
@onready var p2_stamina: ProgressBar = get_node("../HUD/P2Stamina")
@onready var result_overlay: Control = get_node("../HUD/ResultOverlay")
@onready var result_title: Label = get_node("../HUD/ResultOverlay/Panel/Content/Title")
@onready var result_detail: Label = get_node("../HUD/ResultOverlay/Panel/Content/Detail")
@onready var rematch_button: Button = get_node("../HUD/ResultOverlay/Panel/Content/RematchButton")
@onready var result_menu_button: Button = get_node("../HUD/ResultOverlay/Panel/Content/MenuButton")
@onready var pause_overlay: Control = get_node("../HUD/PauseOverlay")
@onready var resume_button: Button = get_node("../HUD/PauseOverlay/Panel/Content/ResumeButton")
@onready var pause_menu_button: Button = get_node("../HUD/PauseOverlay/Panel/Content/MenuButton")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rematch_button.pressed.connect(func() -> void: rematch_requested.emit())
	result_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	pause_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	hide_result()
	show_pause(false)

func update_fighters(player_one: FighterController, player_two: FighterController) -> void:
	if not is_instance_valid(player_one) or not is_instance_valid(player_two):
		return
	_update_bar(p1_health, player_one.health, player_one.build.max_health(), "VIDA")
	_update_bar(p1_posture, player_one.posture, player_one.build.max_posture(), "POSTURA")
	_update_bar(p1_stamina, player_one.stamina, 100.0, "FÔLEGO")
	_update_bar(p2_health, player_two.health, player_two.build.max_health(), "VIDA")
	_update_bar(p2_posture, player_two.posture, player_two.build.max_posture(), "POSTURA")
	_update_bar(p2_stamina, player_two.stamina, 100.0, "FÔLEGO")

func show_result(winner_name: String, player_won: bool, reason: String, difficulty_label: String) -> void:
	result_overlay.visible = true
	result_title.text = "VITÓRIA" if player_won else "DERROTA"
	result_detail.text = "%s VENCEU • %s\nIA %s" % [winner_name.to_upper(), reason, difficulty_label]
	rematch_button.grab_focus()

func hide_result() -> void:
	if is_instance_valid(result_overlay):
		result_overlay.visible = false

func show_pause(active: bool) -> void:
	if not is_instance_valid(pause_overlay):
		return
	pause_overlay.visible = active
	if active:
		resume_button.grab_focus()

func presentation_signature() -> Dictionary:
	return {
		"resource_bars_per_fighter": 3,
		"result_overlay": true,
		"rematch_button": true,
		"menu_button": true,
		"pause_overlay": true,
		"resume_button": true,
		"mouse_supported": true,
		"gamepad_focus_supported": true
	}

func _update_bar(bar: ProgressBar, current_value: float, maximum_value: float, label: String) -> void:
	bar.max_value = maxf(1.0, maximum_value)
	bar.value = clampf(current_value, 0.0, bar.max_value)
	bar.tooltip_text = "%s %.0f / %.0f" % [label, bar.value, bar.max_value]
