class_name LoadoutPresetRuntime
extends Node

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")
@onready var competitive_runtime: CompetitiveMatchRuntime = get_node("../CompetitiveMatchRuntime")
@onready var master_training_runtime: MasterTrainingRuntime = get_node("../MasterTrainingRuntime")

var ledger := LoadoutPresetLedger.new()
var _active := false
var _player_index := 1
var _selected_index := 0
var _renaming := false
var _feedback := ""
var _canvas: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _list: RichTextLabel
var _details: Label
var _rename_input: LineEdit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	ledger.load_from_disk()
	ledger.ensure_import_directory()
	_build_interface()
	_refresh()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"preset_toggle"):
		_toggle()
	if not _active or _renaming:
		return
	if not preparation_runtime.is_active():
		close()
		return
	if Input.is_action_just_pressed(&"preset_player"):
		_player_index = 2 if _player_index == 1 else 1
		_selected_index = 0
		_feedback = "JOGADOR ALTERADO"
		_refresh()
	if Input.is_action_just_pressed(&"preset_up"):
		_cycle_selection(-1)
	elif Input.is_action_just_pressed(&"preset_down"):
		_cycle_selection(1)
	if Input.is_action_just_pressed(&"preset_load"):
		_load_selected()
	if Input.is_action_just_pressed(&"preset_save"):
		_save_current()
	if Input.is_action_just_pressed(&"preset_overwrite"):
		_overwrite_selected()
	if Input.is_action_just_pressed(&"preset_rename"):
		_begin_rename()
	if Input.is_action_just_pressed(&"preset_delete"):
		_delete_selected()
	if Input.is_action_just_pressed(&"preset_export"):
		_export_selected()
	if Input.is_action_just_pressed(&"preset_import"):
		_import_inbox()

func open() -> void:
	if not preparation_runtime.is_active():
		_feedback = "ABRA A PREPARAÇÃO ANTES DOS PRESETS"
		return
	_active = true
	_canvas.visible = true
	_refresh()

func close() -> void:
	_active = false
	_renaming = false
	_canvas.visible = false
	_rename_input.visible = false

func is_active() -> bool:
	return _active

func presets_for_player(player_index: int) -> Array[Dictionary]:
	return ledger.presets_for("p%d" % clampi(player_index, 1, 2))

func save_current_for_test(player_index: int, name: String) -> Dictionary:
	var profile_id := "p%d" % clampi(player_index, 1, 2)
	return ledger.save_preset(
		profile_id,
		name,
		preparation_runtime.loadout_for_player(player_index),
		competitive_runtime.current_config(),
		_unlocked_for(player_index)
	)

func apply_preset_for_test(player_index: int, preset: Dictionary) -> bool:
	return _apply_preset(player_index, preset)

func _toggle() -> void:
	if _active:
		close()
	else:
		open()

func _cycle_selection(direction: int) -> void:
	var presets := presets_for_player(_player_index)
	if presets.is_empty():
		_selected_index = 0
		_feedback = "NENHUM PRESET SALVO"
		_refresh()
		return
	_selected_index = wrapi(_selected_index + direction, 0, presets.size())
	_refresh()

func _save_current() -> void:
	var profile_id := "p%d" % _player_index
	var loadout := preparation_runtime.loadout_for_player(_player_index)
	var build := BuildProfile.prototype_preset(StringName(loadout.get("preset_id", &"adaptive_staff")))
	var count := ledger.preset_count(profile_id) + 1
	var name := "%s • %s • %02d" % [
		build.character_name.to_upper(),
		build.display_name.to_upper(),
		count
	]
	ledger.save_preset(profile_id, name, loadout, competitive_runtime.current_config(), _unlocked_for(_player_index))
	_selected_index = 0
	_feedback = "PRESET SALVO • USE N PARA RENOMEAR"
	_refresh()

func _overwrite_selected() -> void:
	var preset := _selected_preset()
	if preset.is_empty():
		_feedback = "SELECIONE UM PRESET PARA SOBRESCREVER"
		_refresh()
		return
	var updated := ledger.overwrite_preset(
		"p%d" % _player_index,
		String(preset.get("preset_id", "")),
		preparation_runtime.loadout_for_player(_player_index),
		competitive_runtime.current_config(),
		_unlocked_for(_player_index)
	)
	_feedback = "PRESET ATUALIZADO" if not updated.is_empty() else "FALHA AO ATUALIZAR"
	_selected_index = 0
	_refresh()

func _load_selected() -> void:
	var preset := _selected_preset()
	if preset.is_empty():
		_feedback = "NENHUM PRESET DISPONÍVEL"
		_refresh()
		return
	if _apply_preset(_player_index, preset):
		_feedback = "PRESET APLICADO AO P%d" % _player_index
	else:
		_feedback = "PRESET INVÁLIDO"
	_refresh()

func _apply_preset(player_index: int, preset: Dictionary) -> bool:
	var loadout_source: Variant = preset.get("loadout", {})
	if not (loadout_source is Dictionary):
		return false
	preparation_runtime.set_loadout_for_test(player_index, loadout_source as Dictionary)
	var config_source: Variant = preset.get("match_config", {})
	if config_source is Dictionary:
		competitive_runtime.set_config_for_test(config_source as Dictionary)
	return true

func _begin_rename() -> void:
	var preset := _selected_preset()
	if preset.is_empty():
		_feedback = "SELECIONE UM PRESET PARA RENOMEAR"
		_refresh()
		return
	_renaming = true
	_rename_input.visible = true
	_rename_input.text = String(preset.get("name", "PRESET"))
	_rename_input.select_all()
	_rename_input.grab_focus()
	_feedback = "DIGITE O NOVO NOME E PRESSIONE ENTER"
	_refresh()

func _on_name_submitted(value: String) -> void:
	if not _renaming:
		return
	var preset := _selected_preset()
	var renamed := false
	if not preset.is_empty():
		renamed = ledger.rename_preset("p%d" % _player_index, String(preset.get("preset_id", "")), value)
	_renaming = false
	_rename_input.visible = false
	_feedback = "PRESET RENOMEADO" if renamed else "FALHA AO RENOMEAR"
	_refresh()

func _delete_selected() -> void:
	var preset := _selected_preset()
	if preset.is_empty():
		_feedback = "NENHUM PRESET PARA EXCLUIR"
		_refresh()
		return
	ledger.delete_preset("p%d" % _player_index, String(preset.get("preset_id", "")))
	_selected_index = 0
	_feedback = "PRESET EXCLUÍDO"
	_refresh()

func _export_selected() -> void:
	var preset := _selected_preset()
	if preset.is_empty():
		_feedback = "NENHUM PRESET PARA EXPORTAR"
		_refresh()
		return
	var path := ledger.export_preset("p%d" % _player_index, String(preset.get("preset_id", "")))
	_feedback = "EXPORTADO: %s" % path if path != "" else "FALHA NA EXPORTAÇÃO"
	_refresh()

func _import_inbox() -> void:
	var result := ledger.import_inbox("p%d" % _player_index, _unlocked_for(_player_index))
	if bool(result.get("ok", false)):
		_selected_index = 0
		_feedback = "PRESET IMPORTADO COM SUCESSO"
	else:
		_feedback = "%s • %s" % [String(result.get("error", "FALHA NA IMPORTAÇÃO")), LoadoutPresetLedger.IMPORT_INBOX_PATH]
	_refresh()

func _selected_preset() -> Dictionary:
	var presets := presets_for_player(_player_index)
	if presets.is_empty():
		return {}
	_selected_index = clampi(_selected_index, 0, presets.size() - 1)
	return presets[_selected_index].duplicate(true)

func _unlocked_for(player_index: int) -> Array:
	return master_training_runtime.ledger.unlocked_variants("p%d" % player_index)

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 226
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.offset_left = 180.0
	_panel.offset_top = 72.0
	_panel.offset_right = 1100.0
	_panel.offset_bottom = 650.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.022, 0.038, 0.985)
	style.border_color = Color(0.42, 0.82, 0.94, 0.94)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(0.70, 0.92, 1.0))
	column.add_child(_title)
	_list = RichTextLabel.new()
	_list.custom_minimum_size = Vector2(840.0, 360.0)
	_list.bbcode_enabled = true
	_list.fit_content = false
	_list.scroll_active = false
	_list.add_theme_font_size_override("normal_font_size", 15)
	_list.add_theme_font_size_override("bold_font_size", 16)
	column.add_child(_list)
	_rename_input = LineEdit.new()
	_rename_input.placeholder_text = "Nome do preset"
	_rename_input.max_length = 48
	_rename_input.visible = false
	_rename_input.text_submitted.connect(_on_name_submitted)
	column.add_child(_rename_input)
	_details = Label.new()
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 13)
	_details.add_theme_color_override("font_color", Color(0.74, 0.82, 0.94))
	column.add_child(_details)
	_canvas.visible = false

func _refresh() -> void:
	if not is_instance_valid(_title):
		return
	var presets := presets_for_player(_player_index)
	if not presets.is_empty():
		_selected_index = clampi(_selected_index, 0, presets.size() - 1)
	else:
		_selected_index = 0
	_title.text = "BIBLIOTECA DE PRESETS • P%d • %d/%d" % [_player_index, presets.size(), LoadoutPresetLedger.MAX_PRESETS_PER_PROFILE]
	var lines: Array[String] = []
	if presets.is_empty():
		lines.append("[center][color=#8b99ad]Nenhum preset salvo para este jogador.[/color][/center]")
	else:
		for index in range(presets.size()):
			var preset: Dictionary = presets[index]
			var selected := index == _selected_index
			var prefix := "▶" if selected else " "
			var loadout: Dictionary = preset.get("loadout", {})
			var build := BuildProfile.prototype_preset(StringName(loadout.get("preset_id", &"adaptive_staff")))
			var color := "#f4d477" if selected else "#d5dce8"
			lines.append("[color=%s]%s %02d  [b]%s[/b]  •  %s  •  %s[/color]" % [
				color, prefix, index + 1, String(preset.get("name", "PRESET")),
				build.character_name.to_upper(),
				WeaponKitCatalog.label_for(StringName(loadout.get("primary_weapon_id", build.weapon_id)))
			])
	_list.text = "\n".join(lines)
	_details.text = "F2 fecha • TAB jogador • ↑/↓ seleciona • ENTER carrega • F4 salva • F5 sobrescreve • N renomeia • DEL exclui • F7 exporta • F1 importa\n%s" % _feedback

func _register_inputs() -> void:
	_add_key_action(&"preset_toggle", KEY_F2)
	_add_key_action(&"preset_player", KEY_TAB)
	_add_key_action(&"preset_up", KEY_UP)
	_add_key_action(&"preset_down", KEY_DOWN)
	_add_key_action(&"preset_load", KEY_ENTER)
	_add_key_action(&"preset_save", KEY_F4)
	_add_key_action(&"preset_overwrite", KEY_F5)
	_add_key_action(&"preset_rename", KEY_N)
	_add_key_action(&"preset_delete", KEY_DELETE)
	_add_key_action(&"preset_export", KEY_F7)
	_add_key_action(&"preset_import", KEY_F1)

func _add_key_action(action_id: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_id, event)
