class_name ModularFighterIdentitySelector
extends Control

## Reusable BASE-01 identity control for the Taijifu Character Creator.
## Combines skin, face, eyes and brows while keeping profile/runtime synchronized.
## Tehkné Solutions

signal identity_selected(slot: StringName, module_id: StringName)

const CATEGORIES := ["skin", "face", "eyes", "brows"]
const CATEGORY_LABELS := {
	"skin": "PELE",
	"face": "ROSTO",
	"eyes": "OLHOS",
	"brows": "SOBRANCELHAS",
}
const DISPLAY_NAMES := {
	"face_01_balanced": "BALANCED",
	"face_02_angular": "ANGULAR",
	"face_03_soft": "SOFT",
	"face_04_broad": "BROAD",
	"eyes_01_focused": "FOCUSED",
	"eyes_02_calm": "CALM",
	"eyes_03_fierce": "FIERCE",
	"eyes_04_narrow": "NARROW",
	"eyes_05_round": "ROUND",
	"eyes_06_heavy": "HEAVY",
	"brows_01_focused": "FOCUSED",
	"brows_02_neutral": "NEUTRAL",
	"brows_03_arched": "ARCHED",
	"brows_04_straight": "STRAIGHT",
	"brows_05_heavy": "HEAVY",
	"brows_06_sharp": "SHARP",
}

var _profile: ModularFighterProfile
var _assembler: ModularFighterAssembler
var _skin_selector: ModularFighterSkinSelector
var _pages: Dictionary = {}
var _category_buttons: Dictionary = {}
var _option_buttons: Dictionary = {}
var _selected: Dictionary = {}
var _current_category := "skin"
var _built := false

func _ready() -> void:
	custom_minimum_size = Vector2(760.0, 540.0)
	focus_mode = Control.FOCUS_NONE
	_build_ui()
	_show_category_internal(_current_category)

func bind(profile: ModularFighterProfile, assembler: ModularFighterAssembler) -> PackedStringArray:
	var failures := PackedStringArray()
	if profile == null:
		failures.append("profile_missing")
		return failures
	if assembler == null or not assembler.is_ready_for_render():
		failures.append("assembler_not_ready")
		return failures
	_profile = profile
	_assembler = assembler
	if not _built:
		_build_ui()

	failures.append_array(_skin_selector.bind(_profile, _assembler))
	if not failures.is_empty():
		return failures
	_selected["skin"] = String(_skin_selector.selected_palette_id())

	for slot_name in ["face", "eyes", "brows"]:
		var selected_id := String(_profile.module_id(StringName(slot_name)))
		if selected_id.is_empty():
			selected_id = String(_profile.base01_default_identity_id(StringName(slot_name)))
		var profile_failures := _profile.set_base01_identity_module(StringName(slot_name), StringName(selected_id))
		if not profile_failures.is_empty():
			failures.append_array(profile_failures)
			continue
		var runtime_failures := _assembler.set_base01_identity_module(StringName(slot_name), StringName(selected_id))
		if not runtime_failures.is_empty():
			failures.append_array(runtime_failures)
			continue
		_selected[slot_name] = selected_id
	_refresh_all_options()
	return failures

func select_identity(slot: StringName, module_id: StringName, emit_selection: bool = true) -> PackedStringArray:
	var failures := PackedStringArray()
	var slot_name := String(slot)
	if slot_name == "skin":
		failures.append_array(_skin_selector.select_palette(module_id, false))
		if failures.is_empty():
			_selected["skin"] = String(module_id)
			if emit_selection:
				identity_selected.emit(&"skin", module_id)
		return failures
	if not ["face", "eyes", "brows"].has(slot_name):
		failures.append("identity_creator_slot_invalid:%s" % slot_name)
		return failures
	if _profile == null or _assembler == null:
		failures.append("identity_creator_not_bound")
		return failures
	var previous_id := String(_profile.module_id(slot))
	var profile_failures := _profile.set_base01_identity_module(slot, module_id)
	if not profile_failures.is_empty():
		failures.append_array(profile_failures)
		return failures
	var runtime_failures := _assembler.set_base01_identity_module(slot, module_id)
	if not runtime_failures.is_empty():
		if not previous_id.is_empty():
			_profile.set_module(slot, StringName(previous_id))
		failures.append_array(runtime_failures)
		return failures
	_selected[slot_name] = String(module_id)
	_refresh_option_group(slot_name)
	if emit_selection:
		identity_selected.emit(slot, module_id)
	return failures

func show_category(category: StringName) -> bool:
	var category_name := String(category)
	if not CATEGORIES.has(category_name):
		return false
	_current_category = category_name
	_show_category_internal(category_name)
	return true

func current_category() -> StringName:
	return StringName(_current_category)

func selected_id(slot: StringName) -> StringName:
	var slot_name := String(slot)
	if slot_name == "skin" and is_instance_valid(_skin_selector):
		return _skin_selector.selected_palette_id()
	return StringName(String(_selected.get(slot_name, "")))

func option_count(slot: StringName) -> int:
	var slot_name := String(slot)
	if slot_name == "skin":
		return _skin_selector.option_count() if is_instance_valid(_skin_selector) else 0
	if _profile == null:
		var temp_profile := ModularFighterProfile.new()
		return temp_profile.base01_identity_module_ids(slot).size()
	return _profile.base01_identity_module_ids(slot).size()

func focus_selected() -> void:
	if _current_category == "skin":
		_skin_selector.focus_selected()
		return
	var slot_buttons = _option_buttons.get(_current_category, {})
	if not (slot_buttons is Dictionary):
		return
	var selected_key := String(_selected.get(_current_category, ""))
	if slot_buttons.has(selected_key):
		var button = slot_buttons[selected_key]
		if button is Button:
			(button as Button).grab_focus()

func skin_selector() -> ModularFighterSkinSelector:
	return _skin_selector

func _build_ui() -> void:
	if _built:
		return
	_built = true
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "IDENTIDADE DO LUTADOR"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f0d38b"))
	stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "BASE-01 • perfil serializável • runtime modular"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("b7afa1"))
	stack.add_child(subtitle)

	var category_row := HBoxContainer.new()
	category_row.add_theme_constant_override("separation", 8)
	stack.add_child(category_row)
	var category_group := ButtonGroup.new()
	for category in CATEGORIES:
		var button := Button.new()
		button.text = String(CATEGORY_LABELS[category])
		button.custom_minimum_size = Vector2(168.0, 42.0)
		button.toggle_mode = true
		button.button_group = category_group
		button.focus_mode = Control.FOCUS_ALL
		button.set_meta("category", category)
		button.pressed.connect(_on_category_pressed.bind(button))
		category_row.add_child(button)
		_category_buttons[category] = button

	var content_panel := PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(720.0, 374.0)
	content_panel.add_theme_stylebox_override("panel", _content_style())
	stack.add_child(content_panel)
	var content_root := Control.new()
	content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_panel.add_child(content_root)

	_skin_selector = ModularFighterSkinSelector.new()
	_skin_selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skin_selector.skin_selected.connect(_on_skin_selected)
	content_root.add_child(_skin_selector)
	_pages["skin"] = _skin_selector

	var temp_profile := ModularFighterProfile.new()
	for slot_name in ["face", "eyes", "brows"]:
		var page := VBoxContainer.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.offset_left = 18.0
		page.offset_top = 16.0
		page.offset_right = -18.0
		page.offset_bottom = -16.0
		page.add_theme_constant_override("separation", 12)
		content_root.add_child(page)
		_pages[slot_name] = page

		var heading := Label.new()
		heading.text = "%s • MÓDULOS CANÔNICOS" % String(CATEGORY_LABELS[slot_name])
		heading.add_theme_font_size_override("font_size", 17)
		heading.add_theme_color_override("font_color", Color("e6ddcb"))
		page.add_child(heading)

		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		page.add_child(grid)
		var group := ButtonGroup.new()
		var slot_buttons: Dictionary = {}
		for module_id in temp_profile.base01_identity_module_ids(StringName(slot_name)):
			var module_button := Button.new()
			module_button.text = _display_name(String(module_id))
			module_button.custom_minimum_size = Vector2(208.0, 78.0)
			module_button.toggle_mode = true
			module_button.button_group = group
			module_button.focus_mode = Control.FOCUS_ALL
			module_button.set_meta("slot", slot_name)
			module_button.set_meta("module_id", String(module_id))
			module_button.pressed.connect(_on_identity_button_pressed.bind(module_button))
			grid.add_child(module_button)
			slot_buttons[String(module_id)] = module_button
		_option_buttons[slot_name] = slot_buttons

	var footer := Label.new()
	footer.text = "Tehkné Solutions"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color("aa9464"))
	stack.add_child(footer)

func _on_category_pressed(button: Button) -> void:
	var category := StringName(String(button.get_meta("category", "skin")))
	show_category(category)

func _on_skin_selected(palette_id: StringName) -> void:
	_selected["skin"] = String(palette_id)
	identity_selected.emit(&"skin", palette_id)

func _on_identity_button_pressed(button: Button) -> void:
	var slot := StringName(String(button.get_meta("slot", "")))
	var module_id := StringName(String(button.get_meta("module_id", "")))
	var failures := select_identity(slot, module_id)
	if not failures.is_empty():
		button.button_pressed = false
		push_error("BASE-01 identity selector blocked: %s" % ",".join(failures))

func _show_category_internal(category_name: String) -> void:
	for category in CATEGORIES:
		if _pages.has(category):
			var page = _pages[category]
			if page is CanvasItem:
				(page as CanvasItem).visible = category == category_name
		if _category_buttons.has(category):
			var button = _category_buttons[category]
			if button is Button:
				(button as Button).button_pressed = category == category_name
	_refresh_all_options()

func _refresh_all_options() -> void:
	for slot_name in ["face", "eyes", "brows"]:
		_refresh_option_group(slot_name)

func _refresh_option_group(slot_name: String) -> void:
	var slot_buttons = _option_buttons.get(slot_name, {})
	if not (slot_buttons is Dictionary):
		return
	var selected_key := String(_selected.get(slot_name, ""))
	for raw_id in slot_buttons.keys():
		var module_id := String(raw_id)
		var button = slot_buttons[module_id]
		if not (button is Button):
			continue
		var is_selected: bool = module_id == selected_key
		(button as Button).button_pressed = is_selected
		var style := StyleBoxFlat.new()
		style.bg_color = Color("57452d") if is_selected else Color("242019")
		style.border_color = Color("f0d38b") if is_selected else Color("5a4d36")
		style.set_border_width_all(3 if is_selected else 2)
		style.set_corner_radius_all(8)
		(button as Button).add_theme_stylebox_override("normal", style)
		(button as Button).add_theme_stylebox_override("hover", style)
		(button as Button).add_theme_stylebox_override("pressed", style)
		(button as Button).add_theme_stylebox_override("focus", _focus_style())
		(button as Button).add_theme_color_override("font_color", Color("f3ead9"))
		(button as Button).add_theme_color_override("font_hover_color", Color("fff5df"))
		(button as Button).add_theme_color_override("font_pressed_color", Color("fff5df"))

func _display_name(module_id: String) -> String:
	return String(DISPLAY_NAMES.get(module_id, module_id)).to_upper()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17140f")
	style.border_color = Color("66512c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style

func _content_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("11130f")
	style.border_color = Color("403821")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style

func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color("fff1c1")
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)
	return style
