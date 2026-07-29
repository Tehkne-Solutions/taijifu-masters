class_name BattlePreparationRuntime
extends Node

signal start_requested

@onready var master_training_runtime: MasterTrainingRuntime = get_node("../MasterTrainingRuntime")

const GOLD := Color(0.83, 0.62, 0.25)
const PARCHMENT := Color(0.90, 0.82, 0.66)
const WOOD := Color(0.12, 0.075, 0.04, 0.98)
const DEEP_WOOD := Color(0.045, 0.028, 0.018, 0.985)
const PLAYER_ONE := Color(0.36, 0.72, 0.66)
const PLAYER_TWO := Color(0.82, 0.40, 0.25)

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
var _subtitle: Label
var _footer: Label
var _player_titles: Array[Label] = []
var _player_roles: Array[Label] = []
var _player_ready_labels: Array[Label] = []
var _player_previews: Array[PreparationAvatarPreview] = []
var _player_stats: Array[RichTextLabel] = []
var _player_fields: Array[RichTextLabel] = []
var _player_summaries: Array[RichTextLabel] = []
var _player_panels: Array[PanelContainer] = []

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
	_background.color = DEEP_WOOD
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_background)
	var safe_area := MarginContainer.new()
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 24)
	safe_area.add_theme_constant_override("margin_right", 24)
	safe_area.add_theme_constant_override("margin_top", 18)
	safe_area.add_theme_constant_override("margin_bottom", 18)
	_background.add_child(safe_area)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	safe_area.add_child(page)
	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(0, 82)
	header.add_theme_stylebox_override("panel", _panel_style(WOOD, GOLD, 3, 8))
	page.add_child(header)
	var header_column := VBoxContainer.new()
	header_column.alignment = BoxContainer.ALIGNMENT_CENTER
	header_column.add_theme_constant_override("separation", 2)
	header.add_child(_with_margin(header_column, 12, 12, 8, 8))
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.58))
	header_column.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 12)
	_subtitle.add_theme_color_override("font_color", Color(0.76, 0.69, 0.58))
	header_column.add_child(_subtitle)
	var duel_row := HBoxContainer.new()
	duel_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	duel_row.add_theme_constant_override("separation", 14)
	page.add_child(duel_row)
	duel_row.add_child(_build_player_panel(1))
	var versus_frame := PanelContainer.new()
	versus_frame.custom_minimum_size = Vector2(76, 0)
	versus_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.045, 0.025, 0.94), Color(0.43, 0.29, 0.12, 0.9), 2, 38))
	duel_row.add_child(versus_frame)
	var versus := Label.new()
	versus.text = "VS"
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	versus.add_theme_font_size_override("font_size", 28)
	versus.add_theme_color_override("font_color", GOLD)
	versus_frame.add_child(versus)
	duel_row.add_child(_build_player_panel(2))
	var footer_panel := PanelContainer.new()
	footer_panel.custom_minimum_size = Vector2(0, 48)
	footer_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.055, 0.03, 0.98), Color(0.43, 0.28, 0.12, 0.9), 2, 6))
	page.add_child(footer_panel)
	_footer = Label.new()
	_footer.text = "↑↓ ESCOLHER CAMPO   •   ←→ ALTERAR   •   A / F SELAR LOADOUT   •   Y / 1–2 RESTAURAR"
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_color_override("font_color", PARCHMENT)
	footer_panel.add_child(_with_margin(_footer, 8, 8, 5, 5))
	_canvas.visible = false

func _build_player_panel(player_index: int) -> PanelContainer:
	var accent := PLAYER_ONE if player_index == 1 else PLAYER_TWO
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.075, 0.048, 0.029, 0.99), accent, 3, 10))
	_player_panels.append(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 7)
	margin.add_child(root_column)
	var crest := Label.new()
	crest.text = "ESTANDARTE DO NORTE" if player_index == 1 else "ESTANDARTE DO SUL"
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", 10)
	crest.add_theme_color_override("font_color", Color(0.70, 0.61, 0.44))
	root_column.add_child(crest)
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.84, 0.96, 0.91) if player_index == 1 else Color(1.0, 0.80, 0.68))
	root_column.add_child(title)
	_player_titles.append(title)
	var role := Label.new()
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_font_size_override("font_size", 11)
	role.add_theme_color_override("font_color", Color(0.80, 0.73, 0.62))
	root_column.add_child(role)
	_player_roles.append(role)
	var ready_panel := PanelContainer.new()
	ready_panel.custom_minimum_size = Vector2(0, 34)
	ready_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.08, 0.045, 0.95), Color(0.43, 0.29, 0.13, 0.9), 1, 4))
	root_column.add_child(ready_panel)
	var ready_label := Label.new()
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ready_label.add_theme_font_size_override("font_size", 12)
	ready_panel.add_child(ready_label)
	_player_ready_labels.append(ready_label)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	root_column.add_child(middle)
	var identity_column := VBoxContainer.new()
	identity_column.custom_minimum_size = Vector2(205, 0)
	identity_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	identity_column.add_theme_constant_override("separation", 8)
	middle.add_child(identity_column)
	var preview_frame := PanelContainer.new()
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.custom_minimum_size = Vector2(205, 220)
	preview_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.024, 0.016, 0.98), Color(0.38, 0.27, 0.13, 0.9), 2, 6))
	identity_column.add_child(preview_frame)
	var preview := PreparationAvatarPreview.new()
	preview.set_player_index(player_index)
	preview_frame.add_child(_with_margin(preview, 6, 6, 6, 6))
	_player_previews.append(preview)
	var stats_frame := PanelContainer.new()
	stats_frame.custom_minimum_size = Vector2(0, 112)
	stats_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.082, 0.045, 0.96), Color(0.46, 0.32, 0.14, 0.86), 1, 5))
	identity_column.add_child(stats_frame)
	var stats := RichTextLabel.new()
	stats.bbcode_enabled = true
	stats.fit_content = false
	stats.scroll_active = false
	stats.add_theme_font_size_override("normal_font_size", 11)
	stats.add_theme_font_size_override("bold_font_size", 12)
	stats.add_theme_color_override("default_color", PARCHMENT)
	stats_frame.add_child(_with_margin(stats, 10, 10, 8, 8))
	_player_stats.append(stats)
	var loadout_column := VBoxContainer.new()
	loadout_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout_column.add_theme_constant_override("separation", 8)
	middle.add_child(loadout_column)
	var section_title := Label.new()
	section_title.text = "ARSENAL E DISCIPLINAS"
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_title.add_theme_font_size_override("font_size", 11)
	section_title.add_theme_color_override("font_color", GOLD)
	loadout_column.add_child(section_title)
	var field_frame := PanelContainer.new()
	field_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.095, 0.06, 0.96), Color(0.53, 0.37, 0.16, 0.9), 2, 6))
	loadout_column.add_child(field_frame)
	var fields := RichTextLabel.new()
	fields.bbcode_enabled = true
	fields.fit_content = false
	fields.scroll_active = false
	fields.add_theme_font_size_override("normal_font_size", 11)
	fields.add_theme_font_size_override("bold_font_size", 12)
	fields.add_theme_color_override("default_color", Color(0.88, 0.82, 0.70))
	field_frame.add_child(_with_margin(fields, 12, 12, 9, 9))
	_player_fields.append(fields)
	var summary_frame := PanelContainer.new()
	summary_frame.custom_minimum_size = Vector2(0, 92)
	summary_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.065, 0.042, 0.026, 0.96), Color(0.33, 0.23, 0.11, 0.82), 1, 5))
	loadout_column.add_child(summary_frame)
	var summary := RichTextLabel.new()
	summary.bbcode_enabled = true
	summary.fit_content = false
	summary.scroll_active = false
	summary.add_theme_font_size_override("normal_font_size", 10)
	summary.add_theme_font_size_override("bold_font_size", 11)
	summary.add_theme_color_override("default_color", Color(0.80, 0.75, 0.66))
	summary_frame.add_child(_with_margin(summary, 10, 10, 8, 8))
	_player_summaries.append(summary)
	return panel

func _panel_style(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 7
	return style

func _with_margin(control: Control, left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.add_child(control)
	return margin

func _refresh() -> void:
	_refresh_player(1)
	_refresh_player(2)
	_refresh_header()

func _refresh_header() -> void:
	if all_players_ready():
		_title.text = "JURAMENTOS SELADOS • OS PORTÕES DA ARENA ESTÃO ABRINDO"
		_subtitle.text = "As duas formações foram registradas no conselho de guerra."
		_title.add_theme_color_override("font_color", Color(0.66, 1.0, 0.69))
	else:
		_title.text = "CONSELHO DE GUERRA"
		_subtitle.text = "Prepare os dois mestres, compare as formações e sele cada loadout para iniciar o duelo."
		_title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.58))

func _refresh_player(player_index: int) -> void:
	if _player_titles.size() < player_index:
		return
	var slot := player_index - 1
	var loadout := loadout_for_player(player_index)
	_loadouts[slot] = loadout
	var character_id := StringName(loadout.get("character_id", &"kael"))
	var preset_id := StringName(loadout.get("preset_id", &"adaptive_staff"))
	var build := BuildProfile.prototype_preset(preset_id)
	var accent := PLAYER_ONE if player_index == 1 else PLAYER_TWO
	_player_titles[slot].text = "MESTRE %d • %s" % [player_index, build.character_name.to_upper()]
	_player_roles[slot].text = CharacterVisualCatalog.role(character_id).to_upper()
	_player_ready_labels[slot].text = "✓ LOADOUT SELADO • CONFIRME PARA REABRIR" if _ready_states[slot] else "FORMAÇÃO ABERTA • CONFIRME QUANDO ESTIVER PRONTO"
	_player_ready_labels[slot].add_theme_color_override("font_color", Color(0.55, 1.0, 0.63) if _ready_states[slot] else Color(0.95, 0.76, 0.34))
	_player_panels[slot].add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.052, 0.032, 0.99) if _ready_states[slot] else Color(0.075, 0.048, 0.029, 0.99), Color(0.46, 0.88, 0.55) if _ready_states[slot] else accent, 4 if _ready_states[slot] else 3, 10))
	_player_stats[slot].text = ("[center][color=#d5b45f][b]ATRIBUTOS DE COMBATE[/b][/color]\n" + "TAI [b]%d[/b]   JI [b]%d[/b]   FU [b]%d[/b]\n" + "VIDA [b]%d[/b]   POSTURA [b]%d[/b][/center]") % [roundi(build.tai_index()), roundi(build.ji_index()), roundi(build.fu_index()), roundi(build.max_health()), roundi(build.max_posture())]
	var primary := WeaponKitCatalog.label_for(StringName(loadout.get("primary_weapon_id", &"unarmed")))
	var secondary := WeaponKitCatalog.label_for(StringName(loadout.get("secondary_weapon_id", &"unarmed")))
	var variant_summary := MasterTrainingCatalog.variant_summary(StringName(loadout.get("variant_id", &"")))
	_player_summaries[slot].text = ("[color=#d5b45f][b]LEITURA TÁTICA[/b][/color]\n%s\n" + "[color=#b9a98d]ARMAS[/color]  [b]%s[/b] / [b]%s[/b]\n" + "[color=#b9a98d]VARIANTE[/color]  %s") % [build.tactical_summary, primary, secondary, variant_summary]
	_player_previews[slot].apply_loadout(loadout)
	_update_fields(slot, player_index)

func _update_fields(slot: int, player_index: int) -> void:
	var lines: Array[String] = []
	var loadout := _loadouts[slot]
	var color := "#9ed8c6" if player_index == 1 else "#e6a07a"
	for index in range(BattleLoadoutCatalog.FIELD_ORDER.size()):
		var field_id := BattleLoadoutCatalog.FIELD_ORDER[index]
		var value_id := BattleLoadoutCatalog.value_for_field(field_id, loadout)
		var label := BattleLoadoutCatalog.field_label(field_id)
		var value := BattleLoadoutCatalog.value_label(field_id, value_id)
		if index == _field_indices[slot] and not _ready_states[slot]:
			lines.append("[color=%s][b]◆ %s[/b][/color]\n[color=#f0d89c]    ◀  %s  ▶[/color]" % [color, label, value])
		else:
			lines.append("[color=#b9a98d]%s[/color]\n    [b]%s[/b]" % [label, value])
	_player_fields[slot].text = "\n".join(lines)

func _register_preparation_inputs() -> void:
	_register_player_prep_inputs(1, KEY_W, KEY_S, KEY_A, KEY_D, KEY_F, KEY_1, 0)
	_register_player_prep_inputs(2, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_KP_1, KEY_2, 1)

func _register_player_prep_inputs(player_index: int, up_key: Key, down_key: Key, prev_key: Key, next_key: Key, ready_key: Key, reset_key: Key, device: int) -> void:
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
