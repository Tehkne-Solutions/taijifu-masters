class_name ModularFighterCreatorShell
extends Control

## First real BASE-01 Character Creator shell.
## Owns profile identity editing, live modular preview and user preset persistence.
## Tehkné Solutions

signal preset_saved(preset_id: StringName)
signal preset_loaded(preset_id: StringName)
signal creator_state_changed

const BASE_TEXTURE_PATH := "res://assets/modular_fighters/base_00/base_fighter_v1_master.png"
const MENU_SCENE := "res://scenes/vertical_slice/first_playable_menu.tscn"
const PREVIEW_SCALE := 0.34
const CANONICAL_PIVOT := Vector2(0.5, 0.92)
const DEFAULT_PROFILE_ID := &"creator_base01"
const DEFAULT_DISPLAY_NAME := "NOVO LUTADOR"
const DEFAULT_PRESET_ID := "meu_lutador"

var _profile: ModularFighterProfile
var _assembler: ModularFighterAssembler
var _identity_selector: ModularFighterIdentitySelector
var _display_name_edit: LineEdit
var _preset_id_edit: LineEdit
var _preset_list: OptionButton
var _status_label: Label
var _preview_name: Label
var _save_button: Button
var _load_button: Button
var _reset_button: Button
var _back_button: Button
var _built := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_NONE
	_build_ui()
	reset_default_profile()

func reset_default_profile() -> PackedStringArray:
	var profile := ModularFighterProfile.new()
	profile.profile_id = DEFAULT_PROFILE_ID
	profile.display_name = DEFAULT_DISPLAY_NAME
	profile.base_body_id = &"base_fighter_v1"
	profile.authored_facing = 1
	profile.set_skin_palette_id(&"skin_tone_03_warm")
	var failures := _set_profile(profile)
	if failures.is_empty():
		_display_name_edit.text = DEFAULT_DISPLAY_NAME
		_preset_id_edit.text = DEFAULT_PRESET_ID
		_set_status("BASE-01 pronto • identidade padrão carregada", false)
		creator_state_changed.emit()
	return failures

func set_identity(slot: StringName, module_id: StringName) -> PackedStringArray:
	if _identity_selector == null:
		return PackedStringArray(["creator_identity_selector_missing"])
	var failures := _identity_selector.select_identity(slot, module_id)
	if failures.is_empty():
		_update_preview_caption()
		_set_status("Identidade atualizada", false)
		creator_state_changed.emit()
	return failures

func save_current_preset(preset_id: StringName = &"") -> PackedStringArray:
	var failures := PackedStringArray()
	if _profile == null:
		failures.append("creator_profile_missing")
		return failures
	var resolved_id := String(preset_id)
	if resolved_id.is_empty():
		resolved_id = _preset_id_edit.text.strip_edges()
	_profile.display_name = _normalized_display_name(_display_name_edit.text)
	failures.append_array(ModularFighterPresetStore.save_user_preset(_profile, StringName(resolved_id)))
	if not failures.is_empty():
		_set_status("Não foi possível salvar o preset", true)
		return failures
	_preset_id_edit.text = resolved_id
	_refresh_preset_list(resolved_id)
	_update_preview_caption()
	_set_status("Preset salvo: %s" % resolved_id, false)
	preset_saved.emit(StringName(resolved_id))
	return failures

func load_user_preset(preset_id: StringName = &"") -> PackedStringArray:
	var failures := PackedStringArray()
	var resolved_id := String(preset_id)
	if resolved_id.is_empty():
		resolved_id = _preset_id_edit.text.strip_edges()
	var result := ModularFighterPresetStore.load_user_preset(StringName(resolved_id))
	if not bool(result.get("ok", false)):
		failures.append_array(result.get("failures", PackedStringArray()))
		_set_status("Preset não carregado: %s" % resolved_id, true)
		return failures
	var loaded_profile = result.get("profile")
	if not (loaded_profile is ModularFighterProfile):
		failures.append("creator_loaded_profile_invalid")
		_set_status("Preset inválido", true)
		return failures
	# The BASE-01 Creator only accepts identities backed by the current canonical
	# manifest. Legacy v1 presets remain readable through the store but are not
	# silently coerced into editable BASE-01 identities.
	for slot_name in ["face", "eyes", "brows"]:
		var module_id := (loaded_profile as ModularFighterProfile).module_id(StringName(slot_name))
		if module_id == &"":
			continue
		var validation := (loaded_profile as ModularFighterProfile).set_base01_identity_module(StringName(slot_name), module_id)
		if not validation.is_empty():
			failures.append("creator_preset_not_base01:%s:%s" % [slot_name, String(module_id)])
	if not failures.is_empty():
		_set_status("Preset legível, mas não editável no BASE-01", true)
		return failures
	failures.append_array(_set_profile(loaded_profile as ModularFighterProfile))
	if not failures.is_empty():
		_set_status("Falha ao montar o preset", true)
		return failures
	_display_name_edit.text = _profile.display_name
	_preset_id_edit.text = resolved_id
	_refresh_preset_list(resolved_id)
	_set_status("Preset carregado: %s" % resolved_id, false)
	preset_loaded.emit(StringName(resolved_id))
	creator_state_changed.emit()
	return failures

func delete_current_preset() -> PackedStringArray:
	var resolved_id := _preset_id_edit.text.strip_edges()
	var failures := ModularFighterPresetStore.delete_user_preset(StringName(resolved_id))
	if failures.is_empty():
		_refresh_preset_list()
		_set_status("Preset removido: %s" % resolved_id, false)
	else:
		_set_status("Não foi possível remover o preset", true)
	return failures

func current_profile() -> ModularFighterProfile:
	return _profile

func current_assembler() -> ModularFighterAssembler:
	return _assembler

func identity_selector() -> ModularFighterIdentitySelector:
	return _identity_selector

func status_text() -> String:
	return _status_label.text if _status_label != null else ""

func set_display_name(value: String) -> void:
	_display_name_edit.text = value
	if _profile != null:
		_profile.display_name = _normalized_display_name(value)
	_update_preview_caption()

func set_preset_id(value: String) -> void:
	_preset_id_edit.text = value

func flow_signature() -> Dictionary:
	return {
		"scene": "BASE01_CHARACTER_CREATOR_SHELL",
		"identity_categories": ["skin", "face", "eyes", "brows"],
		"identity_options": 24,
		"live_preview": true,
		"preset_schema": ModularFighterPresetStore.SCHEMA_V2,
		"preset_actions": ["save", "load", "list", "delete"],
		"legacy_v1_read_boundary": true,
		"legacy_v1_edit_coercion": false,
		"keyboard_gamepad_focus": true,
		"future_module_expansion": ["hair", "uniform", "weapons", "accessories"],
		"signature": "Tehkné Solutions",
	}

func _set_profile(profile: ModularFighterProfile) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("creator_profile_missing")
		return failures
	_profile = profile
	if _profile.display_name.strip_edges().is_empty():
		_profile.display_name = DEFAULT_DISPLAY_NAME
	failures.append_array(_rebuild_preview_runtime())
	if not failures.is_empty():
		return failures
	failures.append_array(_identity_selector.bind(_profile, _assembler))
	if failures.is_empty():
		_update_preview_caption()
	return failures

func _rebuild_preview_runtime() -> PackedStringArray:
	var failures := PackedStringArray()
	if is_instance_valid(_assembler):
		_assembler.free()
	_assembler = ModularFighterAssembler.new()
	_assembler.name = "CreatorPreviewAssembler"
	_assembler.position = Vector2(235.0, 596.0)
	_assembler.scale = Vector2.ONE * PREVIEW_SCALE
	_assembler.z_index = 5
	add_child(_assembler)
	failures.append_array(_assembler.configure(_profile))
	if not failures.is_empty():
		return failures
	if not ResourceLoader.exists(BASE_TEXTURE_PATH):
		failures.append("creator_base_texture_missing")
		return failures
	var texture := load(BASE_TEXTURE_PATH) as Texture2D
	if texture == null:
		failures.append("creator_base_texture_invalid")
		return failures
	var body := Sprite2D.new()
	body.texture = texture
	body.centered = true
	body.position = Vector2(
		texture.get_width() * (0.5 - CANONICAL_PIVOT.x),
		texture.get_height() * (0.5 - CANONICAL_PIVOT.y)
	)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not _assembler.attach_visual_module(&"body_base", body):
		failures.append("creator_body_attach_failed")
	return failures

func _build_ui() -> void:
	if _built:
		return
	_built = true
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("0b0d0c")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var top_wash := ColorRect.new()
	top_wash.position = Vector2(0, 0)
	top_wash.size = Vector2(1280, 108)
	top_wash.color = Color("121915")
	top_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_wash)

	var title := Label.new()
	title.position = Vector2(28, 20)
	title.size = Vector2(760, 42)
	title.text = "CRIADOR DE LUTADOR"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("f0d38b"))
	add_child(title)

	var subtitle := Label.new()
	subtitle.position = Vector2(30, 62)
	subtitle.size = Vector2(850, 28)
	subtitle.text = "BASE-01 • identidade modular • preview ao vivo • presets locais"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("aaa397"))
	add_child(subtitle)

	var preview_panel := PanelContainer.new()
	preview_panel.name = "PreviewPanel"
	preview_panel.position = Vector2(24, 112)
	preview_panel.size = Vector2(422, 576)
	preview_panel.add_theme_stylebox_override("panel", _panel_style(Color("111511"), Color("5f5130"), 2))
	add_child(preview_panel)

	var preview_title := Label.new()
	preview_title.position = Vector2(48, 132)
	preview_title.size = Vector2(370, 28)
	preview_title.text = "SEU LUTADOR"
	preview_title.add_theme_font_size_override("font_size", 16)
	preview_title.add_theme_color_override("font_color", Color("e8dfcf"))
	add_child(preview_title)

	_preview_name = Label.new()
	_preview_name.position = Vector2(48, 158)
	_preview_name.size = Vector2(370, 32)
	_preview_name.text = DEFAULT_DISPLAY_NAME
	_preview_name.add_theme_font_size_override("font_size", 22)
	_preview_name.add_theme_color_override("font_color", Color("f0d38b"))
	add_child(_preview_name)

	_add_field_label("NOME", Vector2(48, 202))
	_display_name_edit = LineEdit.new()
	_display_name_edit.name = "DisplayNameEdit"
	_display_name_edit.position = Vector2(48, 224)
	_display_name_edit.size = Vector2(370, 38)
	_display_name_edit.placeholder_text = "Nome do lutador"
	_display_name_edit.max_length = 40
	_display_name_edit.text_changed.connect(_on_display_name_changed)
	_style_line_edit(_display_name_edit)
	add_child(_display_name_edit)

	_add_field_label("ID DO PRESET", Vector2(48, 274))
	_preset_id_edit = LineEdit.new()
	_preset_id_edit.name = "PresetIdEdit"
	_preset_id_edit.position = Vector2(48, 296)
	_preset_id_edit.size = Vector2(238, 38)
	_preset_id_edit.placeholder_text = "meu_lutador"
	_preset_id_edit.max_length = 64
	_style_line_edit(_preset_id_edit)
	add_child(_preset_id_edit)

	_save_button = Button.new()
	_save_button.name = "SaveButton"
	_save_button.position = Vector2(296, 296)
	_save_button.size = Vector2(122, 38)
	_save_button.text = "SALVAR"
	_save_button.pressed.connect(_on_save_pressed)
	_style_button(_save_button, true)
	add_child(_save_button)

	_preset_list = OptionButton.new()
	_preset_list.name = "PresetList"
	_preset_list.position = Vector2(48, 344)
	_preset_list.size = Vector2(238, 38)
	_preset_list.item_selected.connect(_on_preset_selected)
	_style_option_button(_preset_list)
	add_child(_preset_list)

	_load_button = Button.new()
	_load_button.name = "LoadButton"
	_load_button.position = Vector2(296, 344)
	_load_button.size = Vector2(122, 38)
	_load_button.text = "CARREGAR"
	_load_button.pressed.connect(_on_load_pressed)
	_style_button(_load_button, false)
	add_child(_load_button)

	_reset_button = Button.new()
	_reset_button.name = "ResetButton"
	_reset_button.position = Vector2(48, 396)
	_reset_button.size = Vector2(178, 36)
	_reset_button.text = "RESTAURAR PADRÃO"
	_reset_button.pressed.connect(reset_default_profile)
	_style_button(_reset_button, false)
	add_child(_reset_button)

	var delete_button := Button.new()
	delete_button.name = "DeleteButton"
	delete_button.position = Vector2(240, 396)
	delete_button.size = Vector2(178, 36)
	delete_button.text = "REMOVER PRESET"
	delete_button.pressed.connect(delete_current_preset)
	_style_button(delete_button, false)
	add_child(delete_button)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.position = Vector2(48, 444)
	_status_label.size = Vector2(370, 48)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color("9db7a3"))
	add_child(_status_label)

	var preview_rule := ColorRect.new()
	preview_rule.position = Vector2(68, 530)
	preview_rule.size = Vector2(334, 1)
	preview_rule.color = Color("6d5931")
	preview_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview_rule)

	var preview_hint := Label.new()
	preview_hint.position = Vector2(65, 642)
	preview_hint.size = Vector2(340, 24)
	preview_hint.text = "preview modular • pivô 0.5 / 0.92"
	preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_hint.add_theme_font_size_override("font_size", 10)
	preview_hint.add_theme_color_override("font_color", Color("716d65"))
	add_child(preview_hint)

	_identity_selector = ModularFighterIdentitySelector.new()
	_identity_selector.name = "IdentitySelector"
	_identity_selector.position = Vector2(470, 116)
	_identity_selector.size = Vector2(786, 544)
	_identity_selector.identity_selected.connect(_on_identity_selected)
	add_child(_identity_selector)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.position = Vector2(1056, 670)
	_back_button.size = Vector2(200, 36)
	_back_button.text = "VOLTAR AO MENU"
	_back_button.pressed.connect(_go_back_to_menu)
	_style_button(_back_button, false)
	add_child(_back_button)

	var signature := Label.new()
	signature.position = Vector2(470, 674)
	signature.size = Vector2(260, 24)
	signature.text = "Tehkné Solutions"
	signature.add_theme_font_size_override("font_size", 11)
	signature.add_theme_color_override("font_color", Color("aa9464"))
	add_child(signature)
	_refresh_preset_list()

func _on_identity_selected(_slot: StringName, _module_id: StringName) -> void:
	_update_preview_caption()
	_set_status("Identidade atualizada", false)
	creator_state_changed.emit()

func _on_display_name_changed(value: String) -> void:
	if _profile != null:
		_profile.display_name = _normalized_display_name(value)
	_update_preview_caption()

func _on_save_pressed() -> void:
	save_current_preset()

func _on_load_pressed() -> void:
	load_user_preset()

func _on_preset_selected(index: int) -> void:
	if index < 0 or index >= _preset_list.item_count:
		return
	var selected := _preset_list.get_item_text(index)
	if selected != "SEM PRESETS":
		_preset_id_edit.text = selected

func _go_back_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

func _refresh_preset_list(select_id: String = "") -> void:
	if _preset_list == null:
		return
	_preset_list.clear()
	var ids := ModularFighterPresetStore.list_user_preset_ids()
	if ids.is_empty():
		_preset_list.add_item("SEM PRESETS")
		_preset_list.disabled = true
		return
	_preset_list.disabled = false
	var selected_index := 0
	for index in range(ids.size()):
		var id_text := String(ids[index])
		_preset_list.add_item(id_text)
		if id_text == select_id:
			selected_index = index
	_preset_list.select(selected_index)

func _update_preview_caption() -> void:
	if _preview_name == null:
		return
	var value := DEFAULT_DISPLAY_NAME
	if _profile != null and not _profile.display_name.strip_edges().is_empty():
		value = _profile.display_name.strip_edges().to_upper()
	_preview_name.text = value

func _normalized_display_name(value: String) -> String:
	var normalized := value.strip_edges()
	return DEFAULT_DISPLAY_NAME if normalized.is_empty() else normalized.left(40)

func _set_status(value: String, error: bool) -> void:
	if _status_label == null:
		return
	_status_label.text = value
	_status_label.add_theme_color_override("font_color", Color("d9947a") if error else Color("9db7a3"))

func _add_field_label(value: String, position_value: Vector2) -> void:
	var label := Label.new()
	label.position = position_value
	label.size = Vector2(220, 20)
	label.text = value
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("9d9588"))
	add_child(label)

func _style_line_edit(edit: LineEdit) -> void:
	edit.add_theme_color_override("font_color", Color("eee4d2"))
	edit.add_theme_color_override("font_placeholder_color", Color("716d65"))
	edit.add_theme_stylebox_override("normal", _panel_style(Color("1b1d18"), Color("534932"), 1))
	edit.add_theme_stylebox_override("focus", _panel_style(Color("20231c"), Color("f0d38b"), 2))

func _style_option_button(button: OptionButton) -> void:
	button.add_theme_color_override("font_color", Color("ddd4c5"))
	button.add_theme_stylebox_override("normal", _panel_style(Color("1b1d18"), Color("534932"), 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("24251f"), Color("8a7446"), 1))
	button.add_theme_stylebox_override("focus", _panel_style(Color("24251f"), Color("f0d38b"), 2))

func _style_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_ALL
	if primary:
		button.add_theme_color_override("font_color", Color("181710"))
		button.add_theme_stylebox_override("normal", _panel_style(Color("d1ad58"), Color("f0d38b"), 1))
		button.add_theme_stylebox_override("hover", _panel_style(Color("e0c06f"), Color("fff0bd"), 2))
		button.add_theme_stylebox_override("focus", _panel_style(Color("e0c06f"), Color("fff0bd"), 2))
	else:
		button.add_theme_color_override("font_color", Color("d7d0c4"))
		button.add_theme_stylebox_override("normal", _panel_style(Color("20221d"), Color("534932"), 1))
		button.add_theme_stylebox_override("hover", _panel_style(Color("292b24"), Color("8a7446"), 1))
		button.add_theme_stylebox_override("focus", _panel_style(Color("292b24"), Color("f0d38b"), 2))

func _panel_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
