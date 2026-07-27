class_name CosmeticLoadoutRuntime
extends Node

const CONNECT_INTERVAL := 0.35

var _ledger := CosmeticLoadoutLedger.new()
var _panel_layer: CanvasLayer
var _panel: ColorRect
var _title: Label
var _details: Label
var _feedback: Label
var _active := false
var _previous_pause_state := false
var _selected_player := 1
var _socket_index := 0
var _connect_timer := 0.0
var _known_presenters: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ledger.load_from_disk()
	_build_panel()
	_connect_presenters()

func _process(delta: float) -> void:
	_connect_timer -= delta
	if _connect_timer <= 0.0:
		_connect_timer = CONNECT_INTERVAL
		_connect_presenters()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_J:
		_toggle_panel()
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	match key_event.keycode:
		KEY_TAB:
			_selected_player = 2 if _selected_player == 1 else 1
			_refresh_panel("JOGADOR ALTERADO")
		KEY_LEFT:
			_socket_index = wrapi(_socket_index - 1, 0, CosmeticSocketCatalog.SOCKET_IDS.size())
			_refresh_panel("SOCKET ANTERIOR")
		KEY_RIGHT:
			_socket_index = wrapi(_socket_index + 1, 0, CosmeticSocketCatalog.SOCKET_IDS.size())
			_refresh_panel("PRÓXIMO SOCKET")
		KEY_UP:
			_cycle_item(1)
		KEY_DOWN:
			_cycle_item(-1)
		KEY_R:
			_reset_selected_profile()
		KEY_ENTER, KEY_KP_ENTER:
			_save_loadouts("LOADOUT SALVO")
		_:
			return
	get_viewport().set_input_as_handled()

func is_panel_active() -> bool:
	return _active

func _toggle_panel() -> void:
	if _active:
		_close_panel()
		return
	if not is_instance_valid(_presenter_for_player(_selected_player)):
		_feedback.text = "INICIE UMA BATALHA PARA EDITAR COSMÉTICOS"
		return
	_previous_pause_state = get_tree().paused
	get_tree().paused = true
	_active = true
	_panel.visible = true
	_refresh_panel("EDITOR ABERTO")

func _close_panel() -> void:
	_save_loadouts("LOADOUT SALVO")
	_active = false
	_panel.visible = false
	get_tree().paused = _previous_pause_state

func _cycle_item(direction: int) -> void:
	var presenter := _presenter_for_player(_selected_player)
	if not is_instance_valid(presenter):
		_refresh_panel("LUTADOR INDISPONÍVEL")
		return
	var fighter := presenter.get_parent() as FighterController
	if not is_instance_valid(fighter):
		return
	var socket_id := CosmeticSocketCatalog.SOCKET_IDS[_socket_index]
	var profile_id := _profile_id(_selected_player)
	var loadout := _ledger.cycle_item(profile_id, fighter.build.character_id, socket_id, direction)
	presenter.apply_loadout(loadout)
	_refresh_panel("%s ATUALIZADO" % CosmeticSocketCatalog.socket_label(socket_id))

func _reset_selected_profile() -> void:
	var presenter := _presenter_for_player(_selected_player)
	if not is_instance_valid(presenter):
		return
	var fighter := presenter.get_parent() as FighterController
	if not is_instance_valid(fighter):
		return
	var loadout := _ledger.reset_profile(_profile_id(_selected_player), fighter.build.character_id)
	presenter.apply_loadout(loadout)
	_refresh_panel("PADRÃO DO PERSONAGEM RESTAURADO")

func _save_loadouts(message: String) -> void:
	for player_index in [1, 2]:
		var presenter := _presenter_for_player(player_index)
		if not is_instance_valid(presenter):
			continue
		_ledger.set_loadout(_profile_id(player_index), presenter.current_loadout())
	var path := _ledger.save_to_disk()
	_refresh_panel(message if path != "" else "FALHA AO SALVAR")

func _connect_presenters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as FighterController
		if not is_instance_valid(fighter):
			continue
		var presenter := fighter.get_node_or_null("CosmeticSockets") as CosmeticSocketPresenter
		if not is_instance_valid(presenter):
			continue
		var key := str(fighter.get_instance_id())
		if _known_presenters.has(key):
			continue
		_known_presenters[key] = presenter
		var loadout := _ledger.loadout_for(_profile_id(fighter.player_index), fighter.build.character_id)
		presenter.apply_loadout(loadout)
	for key in _known_presenters.keys():
		if not is_instance_valid(_known_presenters[key]):
			_known_presenters.erase(key)

func _presenter_for_player(player_index: int) -> CosmeticSocketPresenter:
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as FighterController
		if is_instance_valid(fighter) and fighter.player_index == player_index:
			return fighter.get_node_or_null("CosmeticSockets") as CosmeticSocketPresenter
	return null

func _profile_id(player_index: int) -> String:
	return "player_%d" % player_index

func _build_panel() -> void:
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 245
	_panel_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_panel_layer)
	_panel = ColorRect.new()
	_panel.offset_left = 260.0
	_panel.offset_top = 95.0
	_panel.offset_right = 1020.0
	_panel.offset_bottom = 625.0
	_panel.color = Color(0.025, 0.032, 0.052, 0.98)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_layer.add_child(_panel)

	_title = Label.new()
	_title.offset_left = 24.0
	_title.offset_top = 20.0
	_title.offset_right = 736.0
	_title.offset_bottom = 72.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 25)
	_title.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
	_panel.add_child(_title)

	_details = Label.new()
	_details.offset_left = 36.0
	_details.offset_top = 88.0
	_details.offset_right = 724.0
	_details.offset_bottom = 430.0
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 17)
	_details.add_theme_color_override("font_color", Color(0.88, 0.90, 0.96))
	_panel.add_child(_details)

	_feedback = Label.new()
	_feedback.offset_left = 30.0
	_feedback.offset_top = 448.0
	_feedback.offset_right = 730.0
	_feedback.offset_bottom = 502.0
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", 14)
	_feedback.add_theme_color_override("font_color", Color(1.0, 0.80, 0.40))
	_panel.add_child(_feedback)

func _refresh_panel(message: String) -> void:
	if not is_instance_valid(_title) or not is_instance_valid(_details):
		return
	var presenter := _presenter_for_player(_selected_player)
	var socket_id := CosmeticSocketCatalog.SOCKET_IDS[_socket_index]
	_title.text = "LOADOUT COSMÉTICO — P%d" % _selected_player
	if not is_instance_valid(presenter):
		_details.text = "Lutador indisponível."
		_feedback.text = message
		return
	var fighter := presenter.get_parent() as FighterController
	var item_id := presenter.current_item(socket_id)
	_details.text = "%s — %s\n\nSOCKET: ◀ %s ▶\nITEM: ▲ %s ▼\n\n%s\n\nTAB jogador • R padrão • ENTER salvar • J fechar" % [
		fighter.build.character_name.to_upper(),
		fighter.build.display_name,
		CosmeticSocketCatalog.socket_label(socket_id),
		CosmeticSocketCatalog.item_label(item_id),
		presenter.loadout_summary()
	]
	_feedback.text = message

func _exit_tree() -> void:
	_ledger.save_to_disk()
	if _active:
		get_tree().paused = _previous_pause_state
