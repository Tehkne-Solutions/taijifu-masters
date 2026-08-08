class_name ModularFighterSkinSelector
extends Control

## Reusable Character Creator control for BASE-01 skin palette selection.
## The selector writes only canonical palette IDs into ModularFighterProfile and
## delegates rendering to ModularFighterAssembler. No duplicated body sprites.
## Tehkné Solutions

signal skin_selected(palette_id: StringName)

const CONTRACT_PATH := "res://assets/modular_fighters/base_01/production/BASE01_SKIN_PALETTES.json"
const PALETTE_ROOT := "res://assets/modular_fighters/base_01/palettes"
const DEFAULT_ID := "skin_tone_03_warm"

var _profile: ModularFighterProfile
var _assembler: ModularFighterAssembler
var _palette_ids := PackedStringArray()
var _palette_data: Dictionary = {}
var _buttons: Dictionary = {}
var _selected_id: StringName = &""
var _grid: GridContainer
var _selected_label: Label
var _built := false

func _ready() -> void:
	custom_minimum_size = Vector2(660.0, 310.0)
	focus_mode = Control.FOCUS_NONE
	_ensure_catalog()
	_build_ui()
	_refresh_selection_visuals()

func bind(profile: ModularFighterProfile, assembler: ModularFighterAssembler = null) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("profile_missing")
		return failures
	_ensure_catalog()
	if _palette_ids.is_empty():
		failures.append("skin_palette_catalog_unavailable")
		return failures
	_profile = profile
	_assembler = assembler
	var requested := String(_profile.skin_palette_id())
	if requested.is_empty():
		requested = DEFAULT_ID
	failures.append_array(select_palette(StringName(requested), false))
	return failures

func select_palette(palette_id: StringName, emit_selection: bool = true) -> PackedStringArray:
	var failures := PackedStringArray()
	_ensure_catalog()
	var palette_name := String(palette_id)
	if not _palette_ids.has(palette_name):
		failures.append("unknown_skin_palette:%s" % palette_name)
		return failures
	if _profile != null:
		_profile.set_skin_palette_id(palette_id)
		var profile_failures := _profile.validate_against_standard()
		if not profile_failures.is_empty():
			failures.append_array(profile_failures)
			return failures
	if _assembler != null and _assembler.is_ready_for_render():
		failures.append_array(_assembler.set_skin_palette(palette_id))
		if not failures.is_empty():
			return failures
	_selected_id = palette_id
	_refresh_selection_visuals()
	if emit_selection:
		skin_selected.emit(palette_id)
	return failures

func selected_palette_id() -> StringName:
	return _selected_id

func palette_ids() -> PackedStringArray:
	_ensure_catalog()
	return _palette_ids.duplicate()

func option_count() -> int:
	_ensure_catalog()
	return _palette_ids.size()

func palette_display_name(palette_id: StringName) -> String:
	_ensure_catalog()
	var data = _palette_data.get(String(palette_id), {})
	return String(data.get("display_name", String(palette_id))) if data is Dictionary else String(palette_id)

func palette_base_color(palette_id: StringName) -> Color:
	_ensure_catalog()
	var data = _palette_data.get(String(palette_id), {})
	if not (data is Dictionary):
		return Color.MAGENTA
	var channels = data.get("channels", {})
	if not (channels is Dictionary):
		return Color.MAGENTA
	return Color.from_string(String(channels.get("skin_base", "#FF00FF")), Color.MAGENTA)

func focus_selected() -> void:
	if _buttons.has(String(_selected_id)):
		var button = _buttons[String(_selected_id)]
		if button is Button:
			(button as Button).grab_focus()

func _ensure_catalog() -> void:
	if not _palette_ids.is_empty() and not _palette_data.is_empty():
		return
	var contract := _load_json(CONTRACT_PATH)
	var ids = contract.get("palette_ids", [])
	if typeof(ids) != TYPE_ARRAY:
		return
	for raw_id in ids:
		var palette_id := String(raw_id)
		var data := _load_json("%s/%s.json" % [PALETTE_ROOT, palette_id])
		if data.is_empty() or String(data.get("palette_id", "")) != palette_id:
			continue
		_palette_ids.append(palette_id)
		_palette_data[palette_id] = data

func _build_ui() -> void:
	if _built:
		return
	_built = true
	var panel := PanelContainer.new()
	panel.name = "SkinSelectorPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "TOM DE PELE"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f0d38b"))
	stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "BASE-01 • 8 paletas canônicas • perfil serializável"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("b8b2a6"))
	stack.add_child(subtitle)

	_selected_label = Label.new()
	_selected_label.add_theme_font_size_override("font_size", 15)
	_selected_label.add_theme_color_override("font_color", Color("e9e2d2"))
	stack.add_child(_selected_label)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	stack.add_child(_grid)

	var group := ButtonGroup.new()
	for palette_id in _palette_ids:
		var data = _palette_data.get(palette_id, {})
		var button := Button.new()
		button.name = "Skin_%s" % palette_id
		button.custom_minimum_size = Vector2(142.0, 68.0)
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_ALL
		button.text = String(data.get("display_name", palette_id)).to_upper()
		button.tooltip_text = palette_id
		button.set_meta("palette_id", palette_id)
		button.pressed.connect(_on_palette_button_pressed.bind(button))
		_grid.add_child(button)
		_buttons[palette_id] = button

	var footer := Label.new()
	footer.text = "Tehkné Solutions"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color("aa9464"))
	stack.add_child(footer)

func _on_palette_button_pressed(button: Button) -> void:
	var palette_id := StringName(String(button.get_meta("palette_id", "")))
	var failures := select_palette(palette_id)
	if not failures.is_empty():
		button.button_pressed = false
		push_error("BASE-01 skin selector blocked: %s" % ",".join(failures))

func _refresh_selection_visuals() -> void:
	if not _built:
		return
	for palette_id in _buttons.keys():
		var button = _buttons[palette_id]
		if not (button is Button):
			continue
		var palette_key := String(palette_id)
		var selected: bool = palette_key == String(_selected_id)
		var base_color := palette_base_color(StringName(palette_key))
		var style := StyleBoxFlat.new()
		style.bg_color = base_color
		style.border_color = Color("f0d38b") if selected else Color(0.08, 0.07, 0.06, 0.72)
		style.set_border_width_all(4 if selected else 2)
		style.set_corner_radius_all(8)
		(button as Button).add_theme_stylebox_override("normal", style)
		(button as Button).add_theme_stylebox_override("hover", style)
		(button as Button).add_theme_stylebox_override("pressed", style)
		(button as Button).add_theme_stylebox_override("focus", _focus_style())
		(button as Button).button_pressed = selected
		var text_color := Color("17120d") if base_color.get_luminance() > 0.48 else Color("f7efe4")
		(button as Button).add_theme_color_override("font_color", text_color)
		(button as Button).add_theme_color_override("font_hover_color", text_color)
		(button as Button).add_theme_color_override("font_pressed_color", text_color)
	if is_instance_valid(_selected_label):
		var label := palette_display_name(_selected_id).to_upper() if _selected_id != &"" else "NENHUM"
		_selected_label.text = "SELECIONADO: %s" % label

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17140f")
	style.border_color = Color("66512c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color("fff1c1")
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)
	return style

func _load_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
