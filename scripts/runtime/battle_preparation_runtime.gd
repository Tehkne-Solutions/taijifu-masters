class_name BattlePreparationRuntime
extends Node

signal start_requested

@onready var master_training_runtime: MasterTrainingRuntime = get_node("../MasterTrainingRuntime")

var _battle_ledger := BattleLoadoutLedger.new()
var _cosmetic_ledger := CosmeticLoadoutLedger.new()
var _loadouts: Array[Dictionary] = [{}, {}]
var _field_indices: Array[int] = [0, 0]
var _ready_states: Array[bool] = [false, false]
var _active := false
var _start_emitted := false
var _canvas: CanvasLayer
var _background: ColorRect
var _title: Label
var _footer: Label
var _player_titles: Array[Label] = []
var _player_roles: Array[Label] = []
var _player_ready_labels: Array[Label] = []
var _player_previews: Array[PreparationAvatarPreview] = []
var _player_stats: Array[Label] = []
var _player_fields: Array[RichTextLabel] = []
var _player_summaries: Array[Label] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_preparation_inputs()
	_cosmetic_ledger.load_from_disk()
	var unlocked := _unlocked_by_profile()
	_battle_ledger.load_from_disk(unlocked)
	for player_index in [1, 2]:
		_loadouts[player_index - 1] = _battle_ledger.loadout_for(player_index, unlocked.get("p%d" % player_index, []))
	_build_interface()
	_sync_all_ledgers()
	_refresh()

func _process(_delta: float) -> void:
	if not _active:
		return
	_process_player_inputs(1)
	_process_player_inputs(2)

func open() -> void:
	_active = true
	_start_emitted = false
	_ready_states = [false, false]
	_canvas.visible = true
	_refresh()

func close() -> void:
	_active = false
	_canvas.visible = false
	_sync_all_ledgers()

func is_active() -> bool:
	return _active

func loadout_for_player(player_index: int) -> Dictionary:
	var slot := clampi(player_index, 1, 2) - 1
	return BattleLoadoutCatalog.sanitize(_loadouts[slot], _unlocked_for(player_index))

func set_loadout_for_test(player_index: int, loadout: Dictionary) -> void:
	var slot := clampi(player_index, 1, 2) - 1
	_loadouts[slot] = BattleLoadoutCatalog.sanitize(loadout, _unlocked_for(player_index))
	_ready_states[slot] = false
	_persist_player(player_index)
	_refresh()

func selected_field_for_player(player_index: int) -> StringName:
	return BattleLoadoutCatalog.FIELD_ORDER[_field_indices[clampi(player_index, 1, 2) - 1]]

func is_player_ready(player_index: int) -> bool:
	return _ready_states[clampi(player_index, 1, 2) - 1]

func all_players_ready() -> bool:
	return _ready_states[0] and _ready_states[1]

func set_ready_for_test(player_index: int, ready: bool) -> void:
	_ready_states[clampi(player_index, 1, 2) - 1] = ready
	_refresh_player(player_index)
	_refresh_header()

func registered_gamepad_actions_valid() -> bool:
	for player_index in [1, 2]:
		for suffix in ["up", "down", "prev", "next", "ready", "reset"]:
			if not InputMap.has_action(_prep_action(player_index, suffix)):
				return false
	return true

func _process_player_inputs(player_index: int) -> void:
	if Input.is_action_just_pressed(_prep_action(player_index, "ready")):
		_toggle_ready(player_index)
		return
	if Input.is_action_just_pressed(_prep_action(player_index, "reset")):
		if not is_player_ready(player_index):
			_reset_player(player_index)
		return
	if is_player_ready(player_index):
		return
	if Input.is_action_just_pressed(_prep_action(player_index, "up")):
		_cycle_field(player_index, -1)
	elif Input.is_action_just_pressed(_prep_action(player_index, "down")):
		_cycle_field(player_index, 1)
	if Input.is_action_just_pressed(_prep_action(player_index, "prev")):
		_cycle_value(player_index, -1)
	elif Input.is_action_just_pressed(_prep_action(player_index, "next")):
		_cycle_value(player_index, 1)

func _toggle_ready(player_index: int) -> void:
	var slot := player_index - 1
	_ready_states[slot] = not _ready_states[slot]
	if _ready_states[slot]:
		_persist_player(player_index)
	else:
		_start_emitted = false
	_refresh_player(player_index)
	_refresh_header()
	if all_players_ready() and not _start_emitted:
		_start_emitted = true
		call_deferred("_emit_start_after_lock")

func _emit_start_after_lock() -> void:
	await get_tree().create_timer(0.42, true, false, true).timeout
	if _active and all_players_ready() and _start_emitted:
		_sync_all_ledgers()
		start_requested.emit()

func _cycle_field(player_index: int, direction: int) -> void:
	var slot := player_index - 1
	_field_indices[slot] = wrapi(_field_indices[slot] + direction, 0, BattleLoadoutCatalog.FIELD_ORDER.size())
	_refresh_player(player_index)

func _cycle_value(player_index: int, direction: int) -> void:
	var slot := player_index - 1
	var field_id := BattleLoadoutCatalog.FIELD_ORDER[_field_indices[slot]]
	var unlocked := _unlocked_for(player_index)
	var options := BattleLoadoutCatalog.options_for(field_id, _loadouts[slot], unlocked)
	if options.is_empty():
		return
	var current := BattleLoadoutCatalog.value_for_field(field_id, _loadouts[slot])
	var index := options.find(current)
	if index < 0:
		index = 0
	var next_id := options[wrapi(index + direction, 0, options.size())]
	_loadouts[slot] = BattleLoadoutCatalog.set_field(_loadouts[slot], field_id, next_id, unlocked)
	_ready_states[slot] = false
	_persist_player(player_index)
	_refresh_player(player_index)
	_refresh_header()

func _reset_player(player_index: int) -> void:
	_loadouts[player_index - 1] = BattleLoadoutCatalog.default_loadout(player_index)
	_field_indices[player_index - 1] = 0
	_ready_states[player_index - 1] = false
	_persist_player(player_index)
	_refresh_player(player_index)
	_refresh_header()

func _persist_player(player_index: int) -> void:
	var slot := player_index - 1
	var profile_id := "p%d" % player_index
	var unlocked := _unlocked_for(player_index)
	_loadouts[slot] = _battle_ledger.set_loadout(player_index, _loadouts[slot], unlocked)
	master_training_runtime.ledger.set_selected_variant(profile_id, StringName(_loadouts[slot].get("variant_id", &"")))
	var cosmetic_loadout := {}
	for socket_id in CosmeticSocketCatalog.SOCKET_IDS:
		cosmetic_loadout[String(socket_id)] = String(_loadouts[slot].get(String(socket_id), &"none"))
	_cosmetic_ledger.set_loadout(profile_id, cosmetic_loadout)
	_battle_ledger.save_to_disk()
	master_training_runtime.ledger.save_to_disk()
	_cosmetic_ledger.save_to_disk()

func _sync_all_ledgers() -> void:
	_persist_player(1)
	_persist_player(2)

func _unlocked_for(player_index: int) -> Array:
	return master_training_runtime.ledger.unlocked_variants("p%d" % player_index)

func _unlocked_by_profile() -> Dictionary:
	return {
		"p1": master_training_runtime.ledger.unlocked_variants("p1"),
		"p2": master_training_runtime.ledger.unlocked_variants("p2")
	}

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 210
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0.012, 0.018, 0.032, 0.985)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_background)
	var header := ColorRect.new()
	header.offset_right = 1280.0
	header.offset_bottom = 86.0
	header.color = Color(0.035, 0.065, 0.105, 0.98)
	_background.add_child(header)
	_title = Label.new()
	_title.offset_left = 20.0
	_title.offset_top = 12.0
	_title.offset_right = 1260.0
	_title.offset_bottom = 72.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	header.add_child(_title)
	for slot in range(2):
		_build_player_panel(slot + 1, 30.0 + slot * 630.0)
	_footer = Label.new()
	_footer.offset_left = 20.0
	_footer.offset_top = 672.0
	_footer.offset_right = 1260.0
	_footer.offset_bottom = 716.0
	_footer.text = "P1: W/S + A/D • F ou A confirma • 1 ou Y restaura    |    P2: setas • Num1 ou A confirma • 2 ou Y restaura"
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer.add_theme_font_size_override("font_size", 13)
	_footer.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
	_background.add_child(_footer)
	_canvas.visible = false

func _build_player_panel(player_index: int, left: float) -> void:
	var panel := PanelContainer.new()
	panel.offset_left = left
	panel.offset_top = 104.0
	panel.offset_right = left + 590.0
	panel.offset_bottom = 660.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.070, 0.96)
	style.border_color = Color(0.28, 0.67, 0.95, 0.9) if player_index == 1 else Color(1.0, 0.42, 0.26, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	_background.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 3)
	margin.add_child(root_column)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.66, 0.87, 1.0) if player_index == 1 else Color(1.0, 0.70, 0.60))
	root_column.add_child(title)
	_player_titles.append(title)
	var role := Label.new()
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_font_size_override("font_size", 12)
	role.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82))
	root_column.add_child(role)
	_player_roles.append(role)
	var ready_label := Label.new()
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.add_theme_font_size_override("font_size", 14)
	root_column.add_child(ready_label)
	_player_ready_labels.append(ready_label)
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 12)
	root_column.add_child(middle)
	var preview := PreparationAvatarPreview.new()
	preview.set_player_index(player_index)
	middle.add_child(preview)
	_player_previews.append(preview)
	var fields := RichTextLabel.new()
	fields.custom_minimum_size = Vector2(320.0, 218.0)
	fields.bbcode_enabled = true
	fields.fit_content = false
	fields.scroll_active = false
	fields.add_theme_font_size_override("normal_font_size", 12)
	fields.add_theme_font_size_override("bold_font_size", 13)
	middle.add_child(fields)
	_player_fields.append(fields)
	var stats := Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", Color(0.94, 0.82, 0.48))
	root_column.add_child(stats)
	_player_stats.append(stats)
	var summary := Label.new()
	summary.custom_minimum_size = Vector2(0.0, 60.0)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", Color(0.75, 0.80, 0.89))
	root_column.add_child(summary)
	_player_summaries.append(summary)

func _refresh() -> void:
	_refresh_player(1)
	_refresh_player(2)
	_refresh_header()

func _refresh_header() -> void:
	if all_players_ready():
		_title.text = "AMBOS PRONTOS • ENTRADA NA ARENA\nOS LOADOUTS FORAM BLOQUEADOS"
		_title.add_theme_color_override("font_color", Color(0.58, 1.0, 0.68))
	else:
		_title.text = "PREPARAÇÃO COMPLETA • TAIJIFU MASTERS\nCADA JOGADOR DEVE CONFIRMAR SEU LOADOUT"
		_title.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))

func _refresh_player(player_index: int) -> void:
	if _player_titles.size() < player_index:
		return
	var slot := player_index - 1
	var loadout := loadout_for_player(player_index)
	_loadouts[slot] = loadout
	var character_id := StringName(loadout.get("character_id", &"kael"))
	var preset_id := StringName(loadout.get("preset_id", &"adaptive_staff"))
	var build := BuildProfile.prototype_preset(preset_id)
	_player_titles[slot].text = "P%d — %s" % [player_index, build.character_name.to_upper()]
	_player_roles[slot].text = CharacterVisualCatalog.role(character_id).to_upper()
	_player_ready_labels[slot].text = "✓ PRONTO — CONFIRME NOVAMENTE PARA EDITAR" if _ready_states[slot] else "AGUARDANDO CONFIRMAÇÃO"
	_player_ready_labels[slot].add_theme_color_override(
		"font_color",
		Color(0.48, 1.0, 0.58) if _ready_states[slot] else Color(0.92, 0.72, 0.30)
	)
	_player_stats[slot].text = "TAI %d   JI %d   FU %d   •   VIDA %d   POSTURA %d" % [
		roundi(build.tai_index()), roundi(build.ji_index()), roundi(build.fu_index()),
		roundi(build.max_health()), roundi(build.max_posture())
	]
	_player_summaries[slot].text = "%s\n%s / %s • %s" % [
		build.tactical_summary,
		WeaponKitCatalog.label_for(StringName(loadout.get("primary_weapon_id", &"unarmed"))),
		WeaponKitCatalog.label_for(StringName(loadout.get("secondary_weapon_id", &"unarmed"))),
		MasterTrainingCatalog.variant_summary(StringName(loadout.get("variant_id", &"")))
	]
	_player_previews[slot].apply_loadout(loadout)
	_update_fields(slot, player_index)

func _update_fields(slot: int, player_index: int) -> void:
	var lines: Array[String] = []
	var loadout := _loadouts[slot]
	var color := "#86d7ff" if player_index == 1 else "#ff9a78"
	for index in range(BattleLoadoutCatalog.FIELD_ORDER.size()):
		var field_id := BattleLoadoutCatalog.FIELD_ORDER[index]
		var value_id := BattleLoadoutCatalog.value_for_field(field_id, loadout)
		var label := BattleLoadoutCatalog.field_label(field_id)
		var value := BattleLoadoutCatalog.value_label(field_id, value_id)
		if index == _field_indices[slot] and not _ready_states[slot]:
			lines.append("[color=%s][b]▶ %s: ◀ %s ▶[/b][/color]" % [color, label, value])
		else:
			lines.append("  [b]%s:[/b] %s" % [label, value])
	_player_fields[slot].text = "\n".join(lines)

func _register_preparation_inputs() -> void:
	_register_player_prep_inputs(1, KEY_W, KEY_S, KEY_A, KEY_D, KEY_F, KEY_1, 0)
	_register_player_prep_inputs(2, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_KP_1, KEY_2, 1)

func _register_player_prep_inputs(
	player_index: int,
	up_key: Key,
	down_key: Key,
	prev_key: Key,
	next_key: Key,
	ready_key: Key,
	reset_key: Key,
	device: int
) -> void:
	_add_key_event(_prep_action(player_index, "up"), up_key)
	_add_key_event(_prep_action(player_index, "down"), down_key)
	_add_key_event(_prep_action(player_index, "prev"), prev_key)
	_add_key_event(_prep_action(player_index, "next"), next_key)
	_add_key_event(_prep_action(player_index, "ready"), ready_key)
	_add_key_event(_prep_action(player_index, "reset"), reset_key)
	_add_joy_button(_prep_action(player_index, "up"), JOY_BUTTON_DPAD_UP, device)
	_add_joy_button(_prep_action(player_index, "down"), JOY_BUTTON_DPAD_DOWN, device)
	_add_joy_button(_prep_action(player_index, "prev"), JOY_BUTTON_DPAD_LEFT, device)
	_add_joy_button(_prep_action(player_index, "next"), JOY_BUTTON_DPAD_RIGHT, device)
	_add_joy_button(_prep_action(player_index, "ready"), JOY_BUTTON_A, device)
	_add_joy_button(_prep_action(player_index, "reset"), JOY_BUTTON_Y, device)
	_add_joy_axis(_prep_action(player_index, "up"), JOY_AXIS_LEFT_Y, -1.0, device)
	_add_joy_axis(_prep_action(player_index, "down"), JOY_AXIS_LEFT_Y, 1.0, device)
	_add_joy_axis(_prep_action(player_index, "prev"), JOY_AXIS_LEFT_X, -1.0, device)
	_add_joy_axis(_prep_action(player_index, "next"), JOY_AXIS_LEFT_X, 1.0, device)

func _prep_action(player_index: int, suffix: String) -> StringName:
	return StringName("prep_p%d_%s" % [player_index, suffix])

func _ensure_action(action_id: StringName) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.55)

func _add_key_event(action_id: StringName, keycode: Key) -> void:
	_ensure_action(action_id)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_id, event)

func _add_joy_button(action_id: StringName, button_index: JoyButton, device: int) -> void:
	_ensure_action(action_id)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventJoypadButton and existing.button_index == button_index and existing.device == device:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.device = device
	InputMap.action_add_event(action_id, event)

func _add_joy_axis(action_id: StringName, axis: JoyAxis, axis_value: float, device: int) -> void:
	_ensure_action(action_id)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventJoypadMotion and existing.axis == axis and is_equal_approx(existing.axis_value, axis_value) and existing.device == device:
			return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	event.device = device
	InputMap.action_add_event(action_id, event)

func _exit_tree() -> void:
	_sync_all_ledgers()
