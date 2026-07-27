class_name PlayerProfileRuntime
extends Node

@onready var preparation_runtime: BattlePreparationRuntime = get_node("../BattlePreparationRuntime")

var ledger := PlayerProfileLedger.new()
var _active := false
var _slot := 1
var _selected_index := 0
var _editing_mode: StringName = &""
var _editing_profile_id := ""
var _canvas: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _list: RichTextLabel
var _footer: Label
var _name_input: LineEdit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ledger.load_from_disk()
	_register_inputs()
	_build_interface()
	_refresh()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"profiles_toggle") and _editing_mode == &"":
		if _active:
			close()
		elif preparation_runtime.is_active():
			open()
	if not _active:
		return
	if not preparation_runtime.is_active():
		close()
		return
	if _editing_mode != &"":
		return
	if Input.is_action_just_pressed(&"profiles_slot"):
		_slot = 2 if _slot == 1 else 1
		_sync_selection_to_active()
		_refresh()
	if Input.is_action_just_pressed(&"profiles_prev"):
		_selected_index = wrapi(_selected_index - 1, 0, maxi(1, ledger.profiles().size()))
		_refresh()
	elif Input.is_action_just_pressed(&"profiles_next"):
		_selected_index = wrapi(_selected_index + 1, 0, maxi(1, ledger.profiles().size()))
		_refresh()
	if Input.is_action_just_pressed(&"profiles_activate"):
		_activate_selected()
	if Input.is_action_just_pressed(&"profiles_create"):
		_begin_edit(&"create", "", "")
	if Input.is_action_just_pressed(&"profiles_rename"):
		var selected := selected_profile()
		if not selected.is_empty():
			_begin_edit(&"rename", String(selected.get("profile_id", "")), String(selected.get("name", "")))
	if Input.is_action_just_pressed(&"profiles_delete"):
		_delete_selected()

func open() -> void:
	_active = true
	_canvas.visible = true
	_sync_selection_to_active()
	_refresh()

func close() -> void:
	_active = false
	_editing_mode = &""
	_name_input.visible = false
	_canvas.visible = false

func is_active() -> bool:
	return _active

func active_profile(player_index: int) -> Dictionary:
	return ledger.active_profile(player_index)

func profile_context_for_player(player_index: int) -> Dictionary:
	var profile := active_profile(player_index)
	return {
		"profile_id": String(profile.get("profile_id", "profile_p%d" % clampi(player_index, 1, 2))),
		"profile_name": String(profile.get("name", "JOGADOR %d" % clampi(player_index, 1, 2)))
	}

func set_active_for_test(player_index: int, profile_id: String) -> bool:
	return ledger.set_active(player_index, profile_id)

func create_profile_for_test(name: String) -> Dictionary:
	return ledger.create_profile(name)

func selected_profile() -> Dictionary:
	var profiles := ledger.profiles()
	if profiles.is_empty():
		return {}
	return profiles[clampi(_selected_index, 0, profiles.size() - 1)].duplicate(true)

func _activate_selected() -> void:
	var selected := selected_profile()
	if selected.is_empty():
		return
	ledger.set_active(_slot, String(selected.get("profile_id", "")))
	_refresh()

func _delete_selected() -> void:
	var selected := selected_profile()
	if selected.is_empty():
		return
	if ledger.delete_profile(String(selected.get("profile_id", ""))):
		_selected_index = clampi(_selected_index, 0, maxi(0, ledger.profiles().size() - 1))
		_refresh()

func _begin_edit(mode: StringName, profile_id: String, current_name: String) -> void:
	_editing_mode = mode
	_editing_profile_id = profile_id
	_name_input.text = current_name
	_name_input.visible = true
	_name_input.grab_focus()
	_name_input.select_all()
	_footer.text = "Digite o nome e pressione Enter • Esc cancela"

func _finish_edit(submitted: bool) -> void:
	if submitted:
		if _editing_mode == &"create":
			var created := ledger.create_profile(_name_input.text)
			if not created.is_empty():
				var profiles := ledger.profiles()
				_selected_index = maxi(0, profiles.size() - 1)
		elif _editing_mode == &"rename":
			ledger.rename_profile(_editing_profile_id, _name_input.text)
	_editing_mode = &""
	_editing_profile_id = ""
	_name_input.visible = false
	_name_input.release_focus()
	_refresh()

func _sync_selection_to_active() -> void:
	var active_id := String(active_profile(_slot).get("profile_id", ""))
	var profiles := ledger.profiles()
	for index in range(profiles.size()):
		if String(profiles[index].get("profile_id", "")) == active_id:
			_selected_index = index
			return
	_selected_index = 0

func _refresh() -> void:
	if not is_instance_valid(_title):
		return
	_title.text = "PERFIS LOCAIS • CONFIGURANDO P%d" % _slot
	var active_p1 := active_profile(1)
	var active_p2 := active_profile(2)
	var lines: Array[String] = []
	lines.append("[center]P1: [b]%s[/b]    |    P2: [b]%s[/b][/center]\n" % [String(active_p1.get("name", "JOGADOR 1")), String(active_p2.get("name", "JOGADOR 2"))])
	var profiles := ledger.profiles()
	for index in range(profiles.size()):
		var profile: Dictionary = profiles[index]
		var profile_id := String(profile.get("profile_id", ""))
		var markers: Array[String] = []
		if profile_id == String(active_p1.get("profile_id", "")): markers.append("P1")
		if profile_id == String(active_p2.get("profile_id", "")): markers.append("P2")
		var marker := "[%s]" % ",".join(markers) if not markers.is_empty() else ""
		var cursor := "[color=#ffd36b]▶[/color]" if index == _selected_index else " "
		lines.append("%s [b]%s[/b] %s\n[color=#6f829d]%s[/color]" % [cursor, String(profile.get("name", "JOGADOR")), marker, profile_id])
	_list.text = "\n\n".join(lines)
	_footer.text = "F9 fecha • Tab alterna P1/P2 • ↑/↓ perfil • Enter ativa • N cria • R renomeia • Delete remove • Tehkné Solutions"

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 236
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.offset_left = 250.0
	_panel.offset_top = 72.0
	_panel.offset_right = 1030.0
	_panel.offset_bottom = 648.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.020, 0.036, 0.99)
	style.border_color = Color(0.46, 0.78, 1.0, 0.94)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	_panel.add_theme_stylebox_override("panel", style)
	_canvas.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(0.68, 0.90, 1.0))
	column.add_child(_title)
	_name_input = LineEdit.new()
	_name_input.max_length = 36
	_name_input.placeholder_text = "Nome do perfil"
	_name_input.visible = false
	_name_input.text_submitted.connect(func(_value: String) -> void: _finish_edit(true))
	_name_input.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_finish_edit(false)
	)
	column.add_child(_name_input)
	_list = RichTextLabel.new()
	_list.custom_minimum_size = Vector2(710.0, 400.0)
	_list.bbcode_enabled = true
	_list.scroll_active = true
	_list.add_theme_font_size_override("normal_font_size", 16)
	column.add_child(_list)
	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
	column.add_child(_footer)
	_canvas.visible = false

func _register_inputs() -> void:
	_add_key_action(&"profiles_toggle", KEY_F9)
	_add_key_action(&"profiles_slot", KEY_TAB)
	_add_key_action(&"profiles_prev", KEY_UP)
	_add_key_action(&"profiles_next", KEY_DOWN)
	_add_key_action(&"profiles_activate", KEY_ENTER)
	_add_key_action(&"profiles_create", KEY_N)
	_add_key_action(&"profiles_rename", KEY_R)
	_add_key_action(&"profiles_delete", KEY_DELETE)

func _add_key_action(action_id: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id, 0.5)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_id, event)
