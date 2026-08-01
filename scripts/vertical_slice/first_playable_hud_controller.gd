class_name FirstPlayableHudController
extends Node

signal rematch_requested
signal menu_requested
signal resume_requested
signal feedback_submitted(rating_id: StringName)
signal report_copy_requested

@onready var p1_health: ProgressBar = get_node("../HUD/P1Health")
@onready var p1_posture: ProgressBar = get_node("../HUD/P1Posture")
@onready var p1_stamina: ProgressBar = get_node("../HUD/P1Stamina")
@onready var p2_health: ProgressBar = get_node("../HUD/P2Health")
@onready var p2_posture: ProgressBar = get_node("../HUD/P2Posture")
@onready var p2_stamina: ProgressBar = get_node("../HUD/P2Stamina")
@onready var result_overlay: Control = get_node("../HUD/ResultOverlay")
@onready var result_panel: PanelContainer = get_node("../HUD/ResultOverlay/Panel")
@onready var result_content: VBoxContainer = get_node("../HUD/ResultOverlay/Panel/Content")
@onready var result_title: Label = get_node("../HUD/ResultOverlay/Panel/Content/Title")
@onready var result_detail: Label = get_node("../HUD/ResultOverlay/Panel/Content/Detail")
@onready var rematch_button: Button = get_node("../HUD/ResultOverlay/Panel/Content/RematchButton")
@onready var result_menu_button: Button = get_node("../HUD/ResultOverlay/Panel/Content/MenuButton")
@onready var pause_overlay: Control = get_node("../HUD/PauseOverlay")
@onready var resume_button: Button = get_node("../HUD/PauseOverlay/Panel/Content/ResumeButton")
@onready var pause_menu_button: Button = get_node("../HUD/PauseOverlay/Panel/Content/MenuButton")

var _feedback_prompt: Label
var _feedback_buttons: Array[Button] = []
var _feedback_status: Label
var _copy_report_button: Button
var _export_report_button: Button
var _qa_toggle: Button
var _qa_controls: Array[Control] = []
var _qa_visible := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rematch_button.pressed.connect(func() -> void: rematch_requested.emit())
	result_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	pause_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	_build_playtest_controls()
	FirstPlayableHudSkin.apply(self)
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

func show_result(winner_name: String, player_won: bool, reason: String, difficulty_label: String, report_file_name: String = "") -> void:
	result_overlay.visible = true
	result_title.text = "VITÓRIA" if player_won else "DERROTA"
	result_detail.text = "%s • %s\nIA %s" % [winner_name.to_upper(), reason, difficulty_label]
	_prepare_feedback_prompt()
	_set_qa_visible(false)
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

func set_report_status(message: String) -> void:
	if is_instance_valid(_feedback_status):
		_feedback_status.text = message

func presentation_signature() -> Dictionary:
	return {
		"resource_bars_per_fighter": 3,
		"result_overlay": true,
		"rematch_button": true,
		"menu_button": true,
		"pause_overlay": true,
		"resume_button": true,
		"playtest_feedback": true,
		"balance_feedback_options": 3,
		"copy_report_button": true,
		"export_report_button": true,
		"qa_controls_collapsed_by_default": true,
		"browser_json_download": true,
		"native_file_reveal": true,
		"mouse_supported": true,
		"gamepad_focus_supported": true,
		"final_skin": FirstPlayableHudSkin.presentation_signature()
	}

func _build_playtest_controls() -> void:
	result_panel.offset_left = 420.0
	result_panel.offset_right = 860.0
	result_detail.custom_minimum_size = Vector2(0.0, 58.0)

	_qa_toggle = Button.new()
	_qa_toggle.name = "PlaytestToolsToggle"
	_qa_toggle.custom_minimum_size = Vector2(0.0, 34.0)
	_qa_toggle.text = "DADOS DO TESTE"
	_qa_toggle.add_theme_font_size_override("font_size", 10)
	_qa_toggle.pressed.connect(func() -> void: _set_qa_visible(not _qa_visible))
	result_content.add_child(_qa_toggle)

	_feedback_prompt = Label.new()
	_feedback_prompt.name = "PlaytestFeedbackPrompt"
	_feedback_prompt.custom_minimum_size = Vector2(0.0, 30.0)
	_feedback_prompt.text = "COMO FOI O EQUILÍBRIO DESTA LUTA?"
	_feedback_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_prompt.add_theme_font_size_override("font_size", 12)
	_feedback_prompt.add_theme_color_override("font_color", Color(0.96, 0.80, 0.38))
	result_content.add_child(_feedback_prompt)
	_qa_controls.append(_feedback_prompt)

	var feedback_row := HBoxContainer.new()
	feedback_row.name = "PlaytestFeedbackButtons"
	feedback_row.alignment = BoxContainer.ALIGNMENT_CENTER
	feedback_row.add_theme_constant_override("separation", 6)
	result_content.add_child(feedback_row)
	_qa_controls.append(feedback_row)
	_add_feedback_button(feedback_row, "FÁCIL", &"too_easy")
	_add_feedback_button(feedback_row, "EQUILIBRADO", &"balanced")
	_add_feedback_button(feedback_row, "DIFÍCIL", &"too_hard")

	_feedback_status = Label.new()
	_feedback_status.name = "PlaytestFeedbackStatus"
	_feedback_status.custom_minimum_size = Vector2(0.0, 24.0)
	_feedback_status.text = "COLETA LOCAL • NADA É ENVIADO AUTOMATICAMENTE"
	_feedback_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_status.add_theme_font_size_override("font_size", 9)
	_feedback_status.add_theme_color_override("font_color", Color(0.67, 0.76, 0.86))
	result_content.add_child(_feedback_status)
	_qa_controls.append(_feedback_status)

	_copy_report_button = Button.new()
	_copy_report_button.name = "CopyPlaytestReportButton"
	_copy_report_button.custom_minimum_size = Vector2(0.0, 34.0)
	_copy_report_button.text = "COPIAR RELATÓRIO"
	_copy_report_button.add_theme_font_size_override("font_size", 10)
	_copy_report_button.pressed.connect(func() -> void: report_copy_requested.emit())
	result_content.add_child(_copy_report_button)
	_qa_controls.append(_copy_report_button)

	_export_report_button = Button.new()
	_export_report_button.name = "ExportPlaytestReportButton"
	_export_report_button.custom_minimum_size = Vector2(0.0, 34.0)
	_export_report_button.text = "BAIXAR JSON" if OS.has_feature("web") else "LOCALIZAR JSON"
	_export_report_button.add_theme_font_size_override("font_size", 10)
	_export_report_button.pressed.connect(_export_playtest_report)
	result_content.add_child(_export_report_button)
	_qa_controls.append(_export_report_button)

	result_content.move_child(rematch_button, result_content.get_child_count() - 2)
	result_content.move_child(result_menu_button, result_content.get_child_count() - 1)
	_set_qa_visible(false)

func _set_qa_visible(active: bool) -> void:
	_qa_visible = active
	for control in _qa_controls:
		if is_instance_valid(control):
			control.visible = active
	if is_instance_valid(_qa_toggle):
		_qa_toggle.text = "OCULTAR DADOS DO TESTE" if active else "DADOS DO TESTE"
	if active:
		result_panel.offset_top = 72.0
		result_panel.offset_bottom = 688.0
	else:
		result_panel.offset_top = 180.0
		result_panel.offset_bottom = 540.0

func _add_feedback_button(parent: HBoxContainer, label: String, rating_id: StringName) -> void:
	var button := Button.new()
	button.name = "Feedback%s" % String(rating_id).to_pascal_case()
	button.custom_minimum_size = Vector2(118.0, 36.0)
	button.text = label
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(_on_feedback_button.bind(rating_id))
	parent.add_child(button)
	_feedback_buttons.append(button)

func _prepare_feedback_prompt() -> void:
	_feedback_prompt.text = "COMO FOI O EQUILÍBRIO DESTA LUTA?"
	_feedback_status.text = "COLETA LOCAL • NADA É ENVIADO AUTOMATICAMENTE"
	for button in _feedback_buttons:
		button.disabled = false

func _on_feedback_button(rating_id: StringName) -> void:
	for button in _feedback_buttons:
		button.disabled = true
	_feedback_prompt.text = "FEEDBACK REGISTRADO"
	_feedback_status.text = "RESPOSTA ANEXADA AO RELATÓRIO LOCAL"
	feedback_submitted.emit(rating_id)

func _export_playtest_report() -> void:
	var match_controller := get_parent()
	if match_controller == null:
		set_report_status("CONTROLADOR DA PARTIDA NÃO ENCONTRADO")
		return
	var telemetry_variant: Variant = match_controller.get("_telemetry")
	if not telemetry_variant is MatchTelemetry:
		set_report_status("RELATÓRIO AINDA NÃO DISPONÍVEL")
		return
	var telemetry := telemetry_variant as MatchTelemetry
	var report := telemetry.session_json()
	var source_path := String(match_controller.get("_last_telemetry_path"))
	var file_name := source_path.get_file()
	if file_name == "":
		file_name = "TJFP-REPORT__taijifu_%s.json" % telemetry.session_id()
	var result := PlaytestReportExporter.export_report(report, file_name, source_path)
	if not bool(result.get("ok", false)):
		set_report_status("NÃO FOI POSSÍVEL EXPORTAR • USE COPIAR RELATÓRIO")
		return
	match String(result.get("mode", "")):
		"browser_download": set_report_status("DOWNLOAD INICIADO • %s" % String(result.get("file_name", file_name)))
		"native_reveal": set_report_status("ARQUIVO LOCALIZADO • %s" % String(result.get("file_name", file_name)))
		_: set_report_status("RELATÓRIO PRONTO • %s" % String(result.get("file_name", file_name)))

func _update_bar(bar: ProgressBar, current_value: float, maximum_value: float, label: String) -> void:
	bar.max_value = maxf(1.0, maximum_value)
	bar.value = clampf(current_value, 0.0, bar.max_value)
	bar.tooltip_text = "%s %.0f / %.0f" % [label, bar.value, bar.max_value]
