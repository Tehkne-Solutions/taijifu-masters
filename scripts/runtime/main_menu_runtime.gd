extends Node

signal menu_opened
signal preparation_requested(mode_id: String, options: Dictionary)
signal menu_closed

const DEFAULT_MODE := "arena_loot"

var _layer: CanvasLayer
var _selected_mode := DEFAULT_MODE
var _series_format := 3
var _options_panel: VBoxContainer
var _start_button: Button
var _mode_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("open_main_menu")

func open_main_menu() -> void:
	_close_existing()
	_pause_preparation()
	_layer = CanvasLayer.new()
	_layer.name = "TaijifuMainMenu"
	_layer.layer = 400
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.03, 0.045, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.add_child(shade)

	var root := HBoxContainer.new()
	root.position = Vector2(90, 55)
	root.size = Vector2(1100, 610)
	root.add_theme_constant_override("separation", 26)
	shade.add_child(root)

	var identity := VBoxContainer.new()
	identity.custom_minimum_size = Vector2(360, 560)
	identity.add_theme_constant_override("separation", 14)
	root.add_child(identity)
	identity.add_child(_label("TAIJIFU\nMASTERS", 46))
	identity.add_child(_label("TAI • JI • FU", 20))
	var pitch := Label.new()
	pitch.text = "Domine o corpo, controle o fluxo e imponha sua técnica em arenas de fantasia estratégica."
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.custom_minimum_size = Vector2(340, 110)
	pitch.add_theme_font_size_override("font_size", 17)
	identity.add_child(pitch)
	var status := Label.new()
	status.text = "Escolha uma experiência para configurar a batalha."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(340, 72)
	identity.add_child(status)

	var navigation := VBoxContainer.new()
	navigation.custom_minimum_size = Vector2(680, 560)
	navigation.add_theme_constant_override("separation", 10)
	root.add_child(navigation)
	navigation.add_child(_label("ESCOLHA O MODO", 27))

	var mode_runtime := get_node_or_null("/root/GameModeRuntime")
	if mode_runtime != null:
		for mode_id in mode_runtime.available_modes():
			var config: Dictionary = mode_runtime.MODES[mode_id]
			var button := Button.new()
			button.text = "%s\n%s" % [String(config.get("label", mode_id)), String(config.get("description", ""))]
			button.custom_minimum_size = Vector2(650, 72)
			button.process_mode = Node.PROCESS_MODE_ALWAYS
			var selected := String(mode_id)
			button.pressed.connect(func(): _select_mode(selected))
			navigation.add_child(button)
			_mode_buttons[selected] = button

	_options_panel = VBoxContainer.new()
	_options_panel.add_theme_constant_override("separation", 8)
	navigation.add_child(_options_panel)

	_start_button = Button.new()
	_start_button.text = "CONTINUAR PARA A PREPARAÇÃO"
	_start_button.custom_minimum_size = Vector2(650, 54)
	_start_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_start_button.pressed.connect(_start_selected_mode)
	navigation.add_child(_start_button)

	_select_mode(DEFAULT_MODE)
	menu_opened.emit()

func _select_mode(mode_id: String) -> void:
	var mode_runtime := get_node_or_null("/root/GameModeRuntime")
	if mode_runtime == null or not mode_runtime.MODES.has(mode_id):
		return
	_selected_mode = mode_id
	for id in _mode_buttons:
		var button: Button = _mode_buttons[id]
		button.disabled = String(id) == mode_id
	_build_mode_options()

func _build_mode_options() -> void:
	for child in _options_panel.get_children():
		child.queue_free()
	var mode_runtime := get_node_or_null("/root/GameModeRuntime")
	if mode_runtime == null:
		return
	var config: Dictionary = mode_runtime.MODES[_selected_mode]
	_options_panel.add_child(_label("CONFIGURAÇÃO • %s" % String(config.get("label", "MODO")), 17))
	if _selected_mode == "roguelite_series":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var best_three := Button.new()
		best_three.text = "MELHOR DE 3"
		best_three.process_mode = Node.PROCESS_MODE_ALWAYS
		best_three.pressed.connect(func():
			_series_format = 3
			_build_mode_options()
		)
		row.add_child(best_three)
		var best_five := Button.new()
		best_five.text = "MELHOR DE 5"
		best_five.process_mode = Node.PROCESS_MODE_ALWAYS
		best_five.pressed.connect(func():
			_series_format = 5
			_build_mode_options()
		)
		row.add_child(best_five)
		_options_panel.add_child(row)
		_options_panel.add_child(_label("Formato selecionado: melhor de %d" % _series_format, 14))
	elif _selected_mode == "competitive_duel":
		_options_panel.add_child(_label("Sem tropas, pickups ou progressão. Vitória definida apenas pela técnica.", 14))
	elif _selected_mode == "training":
		_options_panel.add_child(_label("Gravação, fantasmas, maestria e certificações serão priorizados.", 14))
	elif _selected_mode == "champion_challenge":
		_options_panel.add_child(_label("Tropas neutras e Champion Dragon ativos. Recursos estratégicos limitados.", 14))
	else:
		_options_panel.add_child(_label("Arena completa com tropas, pickups, raridades e sinergias.", 14))

func _start_selected_mode() -> void:
	var mode_runtime := get_node_or_null("/root/GameModeRuntime")
	if mode_runtime == null or not mode_runtime.apply_mode(_selected_mode):
		return
	if _selected_mode == "roguelite_series":
		var series := get_node_or_null("/root/CompleteSeriesModeRuntime")
		if series != null:
			series.start_series(_series_format)
	var options := {"series_format": _series_format}
	preparation_requested.emit(_selected_mode, options)
	_open_preparation()
	_close_existing()
	menu_closed.emit()

func return_to_menu() -> void:
	get_tree().paused = false
	open_main_menu()

func _pause_preparation() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var preparation := scene.get_node_or_null("BattlePreparationRuntime")
	if preparation != null and preparation.has_method("close"):
		preparation.close()

func _open_preparation() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var preparation := scene.get_node_or_null("BattlePreparationRuntime")
	if preparation != null and preparation.has_method("open"):
		preparation.open()

func _close_existing() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_mode_buttons.clear()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func selected_mode() -> String:
	return _selected_mode

func selected_series_format() -> int:
	return _series_format

func is_menu_open() -> bool:
	return is_instance_valid(_layer)
