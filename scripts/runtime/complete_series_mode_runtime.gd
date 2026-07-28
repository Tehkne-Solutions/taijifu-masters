extends Node

signal series_started(best_of: int)
signal intermission_opened(round_number: int, winner_index: int)
signal series_finished(champion_index: int, summary: Dictionary)

const SUPPORTED_FORMATS := [3, 5]
const DEFAULT_BEST_OF := 3

var best_of := DEFAULT_BEST_OF
var wins_required := 2
var round_number := 1
var _loot: Node
var _layer: CanvasLayer
var _history: Array[Dictionary] = []
var _series_over := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_loot = get_node_or_null("/root/SeriesLootProgressionRuntime")
	if _loot != null and not _loot.round_resolved.is_connected(_on_round_resolved):
		_loot.round_resolved.connect(_on_round_resolved)
	start_series(DEFAULT_BEST_OF)

func start_series(format_best_of: int) -> void:
	best_of = format_best_of if SUPPORTED_FORMATS.has(format_best_of) else DEFAULT_BEST_OF
	wins_required = int(best_of / 2) + 1
	round_number = 1
	_series_over = false
	_history.clear()
	if _loot != null:
		_loot.reset_series()
	series_started.emit(best_of)

func set_series_format(format_best_of: int) -> bool:
	if round_number > 1 or not SUPPORTED_FORMATS.has(format_best_of):
		return false
	start_series(format_best_of)
	return true

func _on_round_resolved(winner_index: int, loser_index: int) -> void:
	if _series_over:
		return
	_history.append({"round":round_number,"winner":winner_index,"loser":loser_index,"score":{1:_loot.round_wins(1),2:_loot.round_wins(2)}})
	await get_tree().create_timer(0.45, true).timeout
	get_tree().paused = true
	var champion := _champion()
	if champion > 0:
		_series_over = true
		_show_final(champion)
	else:
		_show_intermission(winner_index)
		intermission_opened.emit(round_number, winner_index)

func _champion() -> int:
	for player_index in [1, 2]:
		if _loot.round_wins(player_index) >= wins_required:
			return player_index
	return 0

func _show_intermission(winner_index: int) -> void:
	_close_panel()
	_layer = _new_layer("SeriesIntermission", 220)
	var panel := _new_panel(Vector2(170, 35), Vector2(940, 650))
	_layer.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	root.add_child(_label("INTERVALO • ROUND %d" % round_number, 24))
	root.add_child(_label("P1 %d × %d P2 • VENCEDOR P%d • MELHOR DE %d" % [_loot.round_wins(1), _loot.round_wins(2), winner_index, best_of], 16))
	root.add_child(_reward_row(winner_index))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.add_child(_inventory_column(1, winner_index))
	columns.add_child(_inventory_column(2, winner_index))
	root.add_child(columns)
	var next := Button.new()
	next.text = "INICIAR ROUND %d" % (round_number + 1)
	next.custom_minimum_size = Vector2(0, 50)
	next.process_mode = Node.PROCESS_MODE_ALWAYS
	next.disabled = not _loot.pending_choices(winner_index).is_empty()
	next.pressed.connect(_continue_series)
	root.add_child(next)

func _reward_row(winner_index: int) -> Control:
	var box := VBoxContainer.new()
	box.add_child(_label("P%d • ESCOLHA A RECOMPENSA" % winner_index, 16))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var choices: Array = _loot.pending_choices(winner_index)
	for index in range(choices.size()):
		var selected := index
		var reward: Dictionary = choices[index]
		var button := Button.new()
		button.text = "%s\n%s" % [String(reward.get("label", "ITEM")), String(reward.get("rarity", "common")).to_upper()]
		button.custom_minimum_size = Vector2(275, 58)
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.pressed.connect(func():
			if _loot.choose_reward(winner_index, selected):
				_show_intermission(winner_index)
		)
		row.add_child(button)
	if choices.is_empty():
		row.add_child(_label("Recompensa selecionada.", 14))
	box.add_child(row)
	return box

func _inventory_column(player_index: int, winner_index: int) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(450, 350)
	box.add_child(_label("P%d • INVENTÁRIO" % player_index, 17))
	var inventory: Array = _loot.inventory_snapshot(player_index)
	if inventory.is_empty():
		box.add_child(_label("Nenhum item acumulado.", 13))
		return box
	for index in range(inventory.size()):
		var item_index := index
		var item: Dictionary = inventory[index]
		var row := HBoxContainer.new()
		var protected := " • PROTEGIDO" if String(item.get("id", "")) == _loot.protected_item_id(player_index) else ""
		var name := Label.new()
		name.text = "%s%s" % [String(item.get("label", "ITEM")), protected]
		name.custom_minimum_size = Vector2(235, 38)
		row.add_child(name)
		var protect := Button.new()
		protect.text = "PROTEGER"
		protect.process_mode = Node.PROCESS_MODE_ALWAYS
		protect.pressed.connect(func():
			_loot.protect_item(player_index, item_index)
			_show_intermission(winner_index)
		)
		row.add_child(protect)
		var discard := Button.new()
		discard.text = "DESCARTAR"
		discard.process_mode = Node.PROCESS_MODE_ALWAYS
		discard.pressed.connect(func():
			_loot.discard_item(player_index, item_index)
			_show_intermission(winner_index)
		)
		row.add_child(discard)
		box.add_child(row)
	return box

func _continue_series() -> void:
	round_number += 1
	_close_panel()
	get_tree().paused = false

func _show_final(champion_index: int) -> void:
	_close_panel()
	_layer = _new_layer("SeriesFinal", 230)
	var panel := _new_panel(Vector2(270, 90), Vector2(740, 540))
	_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(_label("P%d • CAMPEÃO DA SÉRIE" % champion_index, 30))
	box.add_child(_label("PLACAR FINAL • P1 %d × %d P2 • MELHOR DE %d" % [_loot.round_wins(1), _loot.round_wins(2), best_of], 18))
	var items: Array[String] = []
	for item in _loot.inventory_snapshot(champion_index):
		items.append(String(item.get("label", "Item")))
	var build_line := "Sem itens finais" if items.is_empty() else ", ".join(items)
	box.add_child(_label("Rounds: %d\nVitórias do campeão: %d\nBuild final: %s" % [_history.size(), _loot.round_wins(champion_index), build_line], 18))
	var restart := Button.new()
	restart.text = "NOVA SÉRIE"
	restart.custom_minimum_size = Vector2(0, 52)
	restart.process_mode = Node.PROCESS_MODE_ALWAYS
	restart.pressed.connect(func():
		start_series(best_of)
		_close_panel()
		get_tree().paused = false
	)
	box.add_child(restart)
	series_finished.emit(champion_index, series_summary())

func _new_layer(layer_name: String, layer_index: int) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = layer_name
	layer.layer = layer_index
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	return layer

func _new_panel(position: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position
	panel.size = size
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	return panel

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label

func series_summary() -> Dictionary:
	return {"best_of":best_of,"wins_required":wins_required,"rounds_played":_history.size(),"score":{1:_loot.round_wins(1),2:_loot.round_wins(2)},"history":_history.duplicate(true),"inventories":{1:_loot.inventory_snapshot(1),2:_loot.inventory_snapshot(2)}}

func is_series_over() -> bool:
	return _series_over

func _close_panel() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
