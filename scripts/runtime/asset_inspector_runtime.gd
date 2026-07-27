class_name AssetInspectorRuntime
extends Node

var _canvas: CanvasLayer
var _panel: PanelContainer
var _preview: TextureRect
var _title: Label
var _details: Label
var _status: Label
var _atlas_texture: AtlasTexture
var _character_ids: Array[StringName] = []
var _character_index := 0
var _state_index := 0
var _frame_index := 0
var _frame_timer := 0.0
var _autoplay := true
var _previous_pause_state := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_character_ids = CharacterVisualCatalog.character_ids()
	_build_interface()
	_load_selection()

func _process(delta: float) -> void:
	if not _panel.visible or not _autoplay or _character_ids.is_empty():
		return
	var character_id := _character_ids[_character_index]
	var state_id := CharacterVisualCatalog.STATE_ORDER[_state_index]
	var frame_duration := 1.0 / CharacterVisualCatalog.fps_for(character_id, state_id)
	_frame_timer += delta
	while _frame_timer >= frame_duration:
		_frame_timer -= frame_duration
		_frame_index = wrapi(_frame_index + 1, 0, CharacterVisualCatalog.columns(character_id))
		_update_region()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_O:
		_toggle_inspector()
		get_viewport().set_input_as_handled()
		return
	if not _panel.visible:
		return
	match key_event.keycode:
		KEY_LEFT:
			_cycle_character(-1)
		KEY_RIGHT:
			_cycle_character(1)
		KEY_UP:
			_cycle_state(-1)
		KEY_DOWN:
			_cycle_state(1)
		KEY_SPACE:
			_autoplay = not _autoplay
			_update_labels()
		KEY_COMMA:
			_step_frame(-1)
		KEY_PERIOD:
			_step_frame(1)
		_:
			return
	get_viewport().set_input_as_handled()

func _build_interface() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 240
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	_panel = PanelContainer.new()
	_panel.offset_left = 330.0
	_panel.offset_top = 46.0
	_panel.offset_right = 950.0
	_panel.offset_bottom = 674.0
	_panel.visible = false
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.032, 0.052, 0.98)
	panel_style.border_color = Color(0.34, 0.72, 0.92, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	_panel.add_theme_stylebox_override("panel", panel_style)
	_canvas.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 25)
	_title.add_theme_color_override("font_color", Color(0.74, 0.92, 1.0))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(1.0, 0.80, 0.42))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(420.0, 420.0)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(_preview)

	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 14)
	_details.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94))
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_details)

	var help := Label.new()
	help.text = "O fecha • ←/→ personagem • ↑/↓ estado • ESPAÇO autoplay • ,/. quadro"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.58, 0.66, 0.78))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(help)

func _toggle_inspector() -> void:
	if _panel.visible:
		_panel.visible = false
		get_tree().paused = _previous_pause_state
		return
	_previous_pause_state = get_tree().paused
	get_tree().paused = true
	_panel.visible = true
	_frame_timer = 0.0
	_load_selection()

func _cycle_character(direction: int) -> void:
	if _character_ids.is_empty():
		return
	_character_index = wrapi(_character_index + direction, 0, _character_ids.size())
	_frame_index = 0
	_frame_timer = 0.0
	_load_selection()

func _cycle_state(direction: int) -> void:
	_state_index = wrapi(_state_index + direction, 0, CharacterVisualCatalog.STATE_ORDER.size())
	_frame_index = 0
	_frame_timer = 0.0
	_update_region()

func _step_frame(direction: int) -> void:
	if _character_ids.is_empty():
		return
	_autoplay = false
	_frame_index = wrapi(_frame_index + direction, 0, CharacterVisualCatalog.columns(_character_ids[_character_index]))
	_update_region()

func _load_selection() -> void:
	if _character_ids.is_empty():
		_status.text = "Nenhum personagem catalogado."
		return
	var character_id := _character_ids[_character_index]
	var path := CharacterVisualCatalog.sheet_path(character_id)
	if path == "" or not ResourceLoader.exists(path):
		_preview.texture = null
		_status.text = "ATLAS AUSENTE"
		_update_labels()
		return
	var texture := load(path) as Texture2D
	if not is_instance_valid(texture):
		_preview.texture = null
		_status.text = "FALHA DE IMPORTAÇÃO"
		_update_labels()
		return
	_atlas_texture = AtlasTexture.new()
	_atlas_texture.atlas = texture
	_preview.texture = _atlas_texture
	_status.text = "ATLAS VÁLIDO • %d × %d QUADROS" % [
		CharacterVisualCatalog.columns(character_id),
		CharacterVisualCatalog.rows(character_id)
	]
	_update_region()

func _update_region() -> void:
	if not is_instance_valid(_atlas_texture) or _character_ids.is_empty():
		_update_labels()
		return
	var state_id := CharacterVisualCatalog.STATE_ORDER[_state_index]
	_atlas_texture.region = Rect2(
		Vector2(_frame_index * CharacterVisualCatalog.FRAME_SIZE.x, CharacterVisualCatalog.state_row(state_id) * CharacterVisualCatalog.FRAME_SIZE.y),
		CharacterVisualCatalog.FRAME_SIZE
	)
	_update_labels()

func _update_labels() -> void:
	if _character_ids.is_empty():
		return
	var character_id := _character_ids[_character_index]
	var state_id := CharacterVisualCatalog.STATE_ORDER[_state_index]
	_title.text = "%s — %s" % [CharacterVisualCatalog.display_name(character_id), CharacterVisualCatalog.role(character_id)]
	_details.text = "%s • QUADRO %d/%d • %.1f FPS • %s\n%s" % [
		CharacterVisualCatalog.state_label(state_id),
		_frame_index + 1,
		CharacterVisualCatalog.columns(character_id),
		CharacterVisualCatalog.fps_for(character_id, state_id),
		"AUTOPLAY" if _autoplay else "MANUAL",
		CharacterVisualCatalog.sheet_path(character_id)
	]

func _exit_tree() -> void:
	if is_instance_valid(_panel) and _panel.visible:
		get_tree().paused = _previous_pause_state
