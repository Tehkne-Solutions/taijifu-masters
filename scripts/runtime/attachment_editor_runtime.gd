class_name AttachmentEditorRuntime
extends Node

const SAVE_PATH := "user://attachment_overrides.json"
const POSITION_STEP := 1.0
const ANGLE_STEP := 0.04
const REACH_STEP := 0.03

var _overrides: Dictionary = {}
var _techniques: Array[StringName] = []
var _technique_index := 0
var _stage_index := 0
var _active := false
var _previous_pause := false
var _fighter: FighterController
var _panel: PanelContainer
var _label: Label
var _feedback := "PRONTO"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("attachment_editor")
	_techniques = TechniqueAttachmentCatalog.technique_ids()
	_load_data()
	_build_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_F6:
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	var handled := true
	match key.keycode:
		KEY_LEFT: _cycle_technique(-1)
		KEY_RIGHT: _cycle_technique(1)
		KEY_UP: _cycle_stage(-1)
		KEY_DOWN: _cycle_stage(1)
		KEY_A: _move_hand(-POSITION_STEP, 0.0, key.shift_pressed)
		KEY_D: _move_hand(POSITION_STEP, 0.0, key.shift_pressed)
		KEY_W: _move_hand(0.0, -POSITION_STEP, key.shift_pressed)
		KEY_S: _move_hand(0.0, POSITION_STEP, key.shift_pressed)
		KEY_Q: _adjust("angle", -ANGLE_STEP)
		KEY_E: _adjust("angle", ANGLE_STEP)
		KEY_Z: _adjust("reach", -REACH_STEP)
		KEY_X: _adjust("reach", REACH_STEP)
		KEY_R: _reset_current()
		KEY_ENTER:
			_save_data()
			_feedback = "SALVO"
			_refresh()
		_: handled = false
	if handled:
		get_viewport().set_input_as_handled()

func is_active() -> bool:
	return _active

func visual_context_for(fighter: FighterController, fallback: Dictionary) -> Dictionary:
	if not _active or fighter != _fighter or _techniques.is_empty():
		return fallback
	var stage := TechniqueAttachmentCatalog.PREVIEW_STAGES[_stage_index]
	var phase_id := stage
	var progress := 0.7
	if stage == &"active_early":
		phase_id = &"active"
		progress = 0.25
	elif stage == &"active_late":
		phase_id = &"active"
		progress = 0.75
	elif stage == &"recovery":
		progress = 0.35
	return {"technique_id": _techniques[_technique_index], "phase_id": phase_id, "progress": progress}

func override_for(character_id: StringName, technique_id: StringName, phase_id: StringName, progress: float) -> Dictionary:
	var stage := TechniqueAttachmentCatalog.preview_stage(phase_id, progress)
	var key := TechniqueAttachmentCatalog.override_key(character_id, technique_id, stage)
	var value: Variant = _overrides.get(key, {})
	if value is Dictionary:
		var data: Dictionary = value
		return data.duplicate(true)
	return {}

func set_override_for_test(key: String, values: Dictionary) -> void:
	_overrides[key] = values.duplicate(true)

func override_count() -> int:
	return _overrides.size()

func _toggle() -> void:
	if _active:
		_close()
	else:
		_open()

func _open() -> void:
	_fighter = _find_player_one()
	if not is_instance_valid(_fighter):
		_feedback = "INICIE UMA BATALHA"
		_refresh()
		return
	_previous_pause = get_tree().paused
	get_tree().paused = true
	_active = true
	_panel.visible = true
	_apply_preview()
	_feedback = "EDIÇÃO AO VIVO"
	_refresh()

func _close() -> void:
	_save_data()
	_clear_preview()
	_active = false
	_panel.visible = false
	get_tree().paused = _previous_pause
	_fighter = null

func _find_player_one() -> FighterController:
	var main := get_parent()
	var candidate: Variant = main.get("player_one")
	if candidate is FighterController:
		return candidate
	for node in get_tree().get_nodes_in_group("fighters"):
		if node is FighterController and int(node.get("player_index")) == 1:
			return node as FighterController
	return null

func _cycle_technique(direction: int) -> void:
	if _techniques.is_empty():
		return
	_technique_index = wrapi(_technique_index + direction, 0, _techniques.size())
	_feedback = "TÉCNICA ALTERADA"
	_refresh()

func _cycle_stage(direction: int) -> void:
	_stage_index = wrapi(_stage_index + direction, 0, TechniqueAttachmentCatalog.PREVIEW_STAGES.size())
	_apply_preview()
	_feedback = "ESTÁGIO ALTERADO"
	_refresh()

func _move_hand(x: float, y: float, rear: bool) -> void:
	var data := _current_data()
	var x_key := "rear_x" if rear else "hand_x"
	var y_key := "rear_y" if rear else "hand_y"
	data[x_key] = float(data.get(x_key, 0.0)) + x
	data[y_key] = float(data.get(y_key, 0.0)) + y
	_store(data)
	_feedback = "APOIO AJUSTADO" if rear else "MÃO AJUSTADA"

func _adjust(field: String, delta: float) -> void:
	var data := _current_data()
	var default_value := 1.0 if field == "reach" else 0.0
	data[field] = float(data.get(field, default_value)) + delta
	if field == "reach":
		data[field] = clampf(float(data[field]), 0.55, 1.55)
	_store(data)
	_feedback = "ALCANCE AJUSTADO" if field == "reach" else "ÂNGULO AJUSTADO"

func _reset_current() -> void:
	_overrides.erase(_current_key())
	_save_data()
	_feedback = "PADRÃO RESTAURADO"
	_refresh()

func _current_data() -> Dictionary:
	var value: Variant = _overrides.get(_current_key(), TechniqueAttachmentCatalog.default_override())
	if value is Dictionary:
		var data: Dictionary = value
		return data.duplicate(true)
	return TechniqueAttachmentCatalog.default_override()

func _store(data: Dictionary) -> void:
	_overrides[_current_key()] = data.duplicate(true)
	_save_data()
	_refresh()

func _current_key() -> String:
	var character_id := &"kael"
	if is_instance_valid(_fighter) and is_instance_valid(_fighter.build):
		character_id = _fighter.build.character_id
	var technique_id := _techniques[_technique_index] if not _techniques.is_empty() else &""
	var stage := TechniqueAttachmentCatalog.PREVIEW_STAGES[_stage_index]
	return TechniqueAttachmentCatalog.override_key(character_id, technique_id, stage)

func _apply_preview() -> void:
	if not is_instance_valid(_fighter):
		return
	var presenter := _fighter.get_node_or_null("SpritePresenter") as ProvisionalSpritePresenter
	if not is_instance_valid(presenter):
		return
	var stage := TechniqueAttachmentCatalog.PREVIEW_STAGES[_stage_index]
	var frame := TechniqueAttachmentCatalog.PREVIEW_STAGES.find(stage)
	presenter.set_visual_preview(&"attack", frame)

func _clear_preview() -> void:
	if not is_instance_valid(_fighter):
		return
	var presenter := _fighter.get_node_or_null("SpritePresenter") as ProvisionalSpritePresenter
	if is_instance_valid(presenter):
		presenter.clear_visual_preview()

func _build_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 250
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	_panel = PanelContainer.new()
	_panel.offset_left = 32.0
	_panel.offset_top = 190.0
	_panel.offset_right = 452.0
	_panel.offset_bottom = 612.0
	_panel.visible = false
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.032, 0.052, 0.97)
	style.border_color = Color(0.76, 0.52, 1.0, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.95))
	margin.add_child(_label)
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_label):
		return
	var technique_id := _techniques[_technique_index] if not _techniques.is_empty() else &""
	var technique := TechniqueCatalog.get_technique(technique_id)
	var stage := TechniqueAttachmentCatalog.PREVIEW_STAGES[_stage_index]
	var data := _current_data() if _active else TechniqueAttachmentCatalog.default_override()
	_label.text = "EDITOR DE ENCAIXES\n%s\n%s • %s\n\nMÃO (%.1f, %.1f)\nAPOIO (%.1f, %.1f)\nÂNGULO %.2f rad\nALCANCE %.2f×\n\n%s\n\nF6 fecha • ←/→ técnica • ↑/↓ estágio\nA/D W/S mão • SHIFT apoio\nQ/E ângulo • Z/X alcance • R restaura" % [
		_feedback, technique.display_name, String(stage).replace("_", " ").to_upper(),
		float(data.get("hand_x", 0.0)), float(data.get("hand_y", 0.0)),
		float(data.get("rear_x", 0.0)), float(data.get("rear_y", 0.0)),
		float(data.get("angle", 0.0)), float(data.get("reach", 1.0)),
		SAVE_PATH
	]

func _save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"version": 1, "overrides": _overrides}, "\t"))

func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var root: Dictionary = parsed
		var loaded: Variant = root.get("overrides", {})
		if loaded is Dictionary:
			var data: Dictionary = loaded
			_overrides = data.duplicate(true)

func _exit_tree() -> void:
	if _active:
		_clear_preview()
		get_tree().paused = _previous_pause
	_save_data()
