extends Node

signal series_started(best_of: int)
signal intermission_opened(round_number: int, winner_index: int)
signal series_finished(champion_index: int, summary: Dictionary)

const SUPPORTED_FORMATS := [3, 5]
const DEFAULT_BEST_OF := 3

var best_of := DEFAULT_BEST_OF
var wins_required := 2
var round_number := 1
var _loot_runtime: Node
var _intermission_layer: CanvasLayer
var _series_over := false
var _history: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_loot_runtime = get_node_or_null("/root/SeriesLootProgressionRuntime")
	if _loot_runtime != null and not _loot_runtime.round_resolved.is_connected(_on_round_resolved):
		_loot_runtime.round_resolved.connect(_on_round_resolved)
	start_series(DEFAULT_BEST_OF)

func start_series(format_best_of: int) -> void:
	best_of = format_best_of if SUPPORTED_FORMATS.has(format_best_of) else DEFAULT_BEST_OF
	wins_required = int(best_of / 2) + 1
	round_number = 1
	_series_over = false
	_history.clear()
	if _loot_runtime != null:
		_loot_runtime.reset_series()
	series_started.emit(best_of)

func set_series_format(format_best_of: int) -> bool:
	if not SUPPORTED_FORMATS.has(format_best_of) or round_number > 1:
		return false
	start_series(format_best_of)
	return true

func _on_round_resolved(winner_index: int, loser_index: int) -> void:
	if _series_over:
		return
	var entry := {
		"round": round_number,
		"winner": winner_index,
		"loser": loser_index,
		"score_p1": _loot_runtime.round_wins(1),
		"score_p2": _loot_runtime.round_wins(2),
		"inventory_p1": _loot_runtime.inventory_snapshot(1),
		"inventory_p2": _loot_runtime.inventory_snapshot(2)
	}
	_history.append(entry)
	var champion := _champion_if_complete()
	await get_tree().create_timer(0.45, true).timeout
	get_tree().paused = true
	if champion > 0:
		_series_over = true
		_show_final_panel(champion)
	else:
		_show_intermission(winner_index)
		intermission_opened.emit(round_number, winner_index)

func _champion_if_complete() -> int:
	for player_index in [1, 2]:
		if _loot_runtime.round_wins(player_index) >= wins_required:
			return player_index
	return 0

func _show_intermission(winner_index: int) -> void:
	_close_panel()
	_intermission_layer = CanvasLayer.new()
	_intermission_layer.name = "SeriesIntermission"
	_intermission_layer.layer = 220
	_intermission_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_intermission_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(220, 70)
	panel.size = Vector2(840, 580)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_intermission_layer.add_child(panel)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	panel.add_child(root_box)
	var title := Label.new()
	title.text = "INTERVALO • ROUND %d CONCLUÍDO" % round_number
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	root_box.add_child(title)
	var score := Label.new()
	score.text = "P1 %d  ×  %d P2  •  VENCEDOR: P%d  •  MELHOR DE %d" % [_loot_runtime.round_wins(1), _loot_runtime.round_wins(2), winner_index, best_of]
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(score)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	root_box.add_child(columns)
	for player_index in [1, 2]:
		columns.add_child(_build_inventory_column(player_index))
	var hint := Label.new()
	hint.text = "Proteja um item contra a próxima perda ou descarte um item para abrir espaço."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(hint)
	var continue_button := Button.new()
	continue_button.text = "INICIAR ROUND %d" % (round_number + 1)
	continue_button.custom_minimum_size = Vector2(0, 52)
	continue_button.process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(_continue_series)
	root_box.add_child(continue_button)

func _build_inventory_column(player_index: int) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(390, 380)
	var heading := Label.new()
	heading.text = "P%d • INVENTÁRIO DA SÉRIE" % player_index
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 17)
	box.add_child(heading)
	var inventory: Array = _loot_runtime.inventory_snapshot(player_index)
	var protected_id := _loot_runtime.protected_item_id(player_index)
	if inventory.is_empty():
		var empty := Label.new()
		empty.text = "Nenhum item acumulado."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(empty)
		return box
	for index in range(inventory.size()):
		var item: Dictionary = inventory[index]
		var row := HBoxContainer.new()
		var item_label := Label.new()
		var protected_mark := " • PROTEGIDO" if String(item.get("id", "")) == protected_id else ""
		item_label.text = "%s • %s%s" % [String(item.get("label", "ITEM")), String(item.get("rarity", "common")).to_upper(), protected_mark]
		item_label.custom_minimum_size = Vector2(205, 40)
		row.add_child(item_label)
		var protect := Button.new()
		protect.text = "PROTEGER"
		protect.process_mode = Node.PROCESS_MODE_ALWAYS
		protect.pressed.connect(func():
			_loot_runtime.protect_item(player_index, index)
			_show_intermission(_history.back()["winner"])
		)
		row.add_child(protect)
		var discard := Button.new()
		discard.text = "DESCARTAR"
		discard.process_mode = Node.PROCESS_MODE_ALWAYS
		discard.pressed.connect(func():
			_loot_runtime.discard_item(player_index, index)
			_show_intermission(_history.back()["winner"])
		)
		row.add_child(discard)
		box.add_child(row)
	return box

func _continue_series() -> void:
	round_number += 1
	_close_panel()
	get_tree().paused = false

func _show_final_panel(champion_index: int) -> void:
	_close_panel()
	_intermission_layer = CanvasLayer.new()
	_intermission_layer.name = "SeriesFinal"
	_intermission_layer.layer = 230
	_intermission_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_intermission_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(270, 90)
	panel.size = Vector2(740, 540)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_intermission_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := Label.new()
	title.text = "P%d • CAMPEÃO DA SÉRIE" % champion_index
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var score := Label.new()
	score.text = "PLACAR FINAL  •  P1 %d × %d P2  •  MELHOR DE %d" % [_loot_runtime.round_wins(1), _loot_runtime.round_wins(2), best_of]
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(score)
	var summary := Label.new()
	summary.text = _series_summary_text(champion_index)
	summary.custom_minimum_size = Vector2(690, 290)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(summary)
	var restart := Button.new()
	restart.text = "NOVA SÉRIE • MELHOR DE %d" % best_of
	restart.custom_minimum_size = Vector2(0, 52)
	restart.process_mode = Node.PROCESS_MODE_ALWAYS
	restart.pressed.connect(func():
		start_series(best_of)
		_close_panel()
		get_tree().paused = false
	)
	box.add_child(restart)
	series_finished.emit(champion_index, series_summary())

func _series_summary_text(champion_index: int) -> String:
	var winner_inventory: Array = _loot_runtime.inventory_snapshot(champion_index)
	var labels: Array[String] = []
	for item in winner_inventory:
		labels.append(String(item.get("label", "Item")))
	var build_line := "Sem itens finais" if labels.is_empty() else ", ".join(labels)
	return "Rounds disputados: %d\nVitórias do campeão: %d\nItens finais: %d/%d\nBuild final: %s\n\nA série registrou a evolução de inventário e as perdas de cada round." % [_history.size(), _loot_runtime.round_wins(champion_index), winner_inventory.size(), _loot_runtime.MAX_INVENTORY, build_line]

func series_summary() -> Dictionary:
	return {
		"best_of": best_of,
		"wins_required": wins_required,
		"rounds_played": _history.size(),
		"score": {1: _loot_runtime.round_wins(1), 2: _loot_runtime.round_wins(2)},
		"history": _history.duplicate(true),
		"inventories": {1: _loot_runtime.inventory_snapshot(1), 2: _loot_runtime.inventory_snapshot(2)}
	}

func _close_panel() -> void:
	if is_instance_valid(_intermission_layer):
		_intermission_layer.queue_free()
	_intermission_layer = null

func is_series_over() -> bool:
	return _series_over
