extends Node

signal reward_choices_ready(player_index: int, choices: Array[Dictionary])
signal reward_chosen(player_index: int, reward: Dictionary)
signal inventory_changed(player_index: int, inventory: Array[Dictionary])

const REWARD_POOL := [
	{"id":"ember_edge","label":"Lâmina da Brasa","type":"weapon","rarity":"rare","stat":"strength","amount":8.0},
	{"id":"stone_aegis","label":"Égide de Pedra","type":"armor","rarity":"rare","stat":"defense","amount":9.0},
	{"id":"gale_boots","label":"Botas do Vendaval","type":"relic","rarity":"rare","stat":"agility","amount":10.0},
	{"id":"seer_emblem","label":"Emblema do Vidente","type":"relic","rarity":"epic","stat":"focus","amount":12.0},
	{"id":"echo_codex","label":"Códice do Eco","type":"skill","rarity":"epic","technique":"fu_reversal"},
	{"id":"titan_core","label":"Núcleo Titânico","type":"relic","rarity":"legendary","stat":"resistance","amount":15.0}
]

const MAX_INVENTORY := 5
const CHOICE_COUNT := 3
const LOSS_FRACTION := 0.4

var _fighters: Dictionary = {}
var _inventories := {1: [], 2: []}
var _pending_choices := {1: [], 2: []}
var _round_wins := {1: 0, 2: 0}
var _connected: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _scan_timer := 0.0

func _ready() -> void:
	_rng.randomize()
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.3
		_discover_fighters()

func _discover_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		if not node is FighterController:
			continue
		var fighter := node as FighterController
		var player_index := int(fighter.player_index)
		_fighters[player_index] = fighter
		var key := str(fighter.get_instance_id())
		if not _connected.has(key):
			_connected[key] = fighter
			fighter.defeated.connect(_on_fighter_defeated)
			_apply_inventory_to_fighter(player_index, fighter)

func _on_fighter_defeated(defeated: FighterController) -> void:
	var loser := int(defeated.player_index)
	var winner := 1 if loser == 2 else 2
	_round_wins[winner] = int(_round_wins.get(winner, 0)) + 1
	_apply_defeat_loss(loser)
	_generate_reward_choices(winner)
	_show_reward_panel(winner)

func _generate_reward_choices(player_index: int) -> void:
	var pool := REWARD_POOL.duplicate(true)
	pool.shuffle()
	var choices: Array[Dictionary] = []
	for i in range(mini(CHOICE_COUNT, pool.size())):
		choices.append(Dictionary(pool[i]).duplicate(true))
	_pending_choices[player_index] = choices
	reward_choices_ready.emit(player_index, choices)

func choose_reward(player_index: int, choice_index: int) -> bool:
	var choices: Array = _pending_choices.get(player_index, [])
	if choice_index < 0 or choice_index >= choices.size():
		return false
	var reward: Dictionary = Dictionary(choices[choice_index]).duplicate(true)
	var inventory: Array = _inventories.get(player_index, [])
	if inventory.size() >= MAX_INVENTORY:
		inventory.pop_front()
	inventory.append(reward)
	_inventories[player_index] = inventory
	_pending_choices[player_index] = []
	var fighter: FighterController = _fighters.get(player_index)
	if is_instance_valid(fighter):
		_apply_reward_to_fighter(fighter, reward)
	reward_chosen.emit(player_index, reward)
	inventory_changed.emit(player_index, inventory_snapshot(player_index))
	return true

func _apply_defeat_loss(player_index: int) -> void:
	var inventory: Array = _inventories.get(player_index, [])
	if inventory.is_empty():
		return
	var loss_count := maxi(1, int(ceil(inventory.size() * LOSS_FRACTION)))
	for i in range(loss_count):
		if inventory.is_empty():
			break
		inventory.remove_at(_rng.randi_range(0, inventory.size() - 1))
	_inventories[player_index] = inventory
	inventory_changed.emit(player_index, inventory_snapshot(player_index))

func _apply_inventory_to_fighter(player_index: int, fighter: FighterController) -> void:
	for reward in _inventories.get(player_index, []):
		_apply_reward_to_fighter(fighter, reward)

func _apply_reward_to_fighter(fighter: FighterController, reward: Dictionary) -> void:
	if String(reward.get("type", "")) == "skill":
		fighter.borrowed_technique_id = StringName(reward.get("technique", "fu_reversal"))
	else:
		var stat := String(reward.get("stat", ""))
		if not stat.is_empty() and fighter.build.get(stat) != null:
			fighter.build.set(stat, clampf(float(fighter.build.get(stat)) + float(reward.get("amount", 0.0)), 1.0, 100.0))
	fighter.health = minf(fighter.build.max_health(), fighter.health + 8.0)
	fighter.stamina = minf(100.0, fighter.stamina + 12.0)
	fighter.combat_state_changed.emit(fighter)

func _show_reward_panel(player_index: int) -> void:
	if get_tree().current_scene == null:
		return
	var choices: Array = _pending_choices.get(player_index, [])
	if choices.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.name = "SeriesRewardChoice"
	layer.layer = 150
	get_tree().current_scene.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(390, 170)
	panel.size = Vector2(500, 300)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "P%d • ESCOLHA UMA RECOMPENSA" % player_index
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	for i in range(choices.size()):
		var reward: Dictionary = choices[i]
		var button := Button.new()
		button.text = "%d — %s • %s" % [i + 1, String(reward["label"]), String(reward["rarity"]).to_upper()]
		button.custom_minimum_size = Vector2(460, 52)
		button.pressed.connect(func():
			if choose_reward(player_index, i):
				layer.queue_free()
		)
		box.add_child(button)
	var timer := get_tree().create_timer(7.0)
	timer.timeout.connect(func():
		if is_instance_valid(layer):
			choose_reward(player_index, 0)
			layer.queue_free()
	)

func inventory_snapshot(player_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _inventories.get(player_index, []):
		result.append(Dictionary(item).duplicate(true))
	return result

func pending_choices(player_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _pending_choices.get(player_index, []):
		result.append(Dictionary(item).duplicate(true))
	return result

func round_wins(player_index: int) -> int:
	return int(_round_wins.get(player_index, 0))

func reset_series() -> void:
	_inventories = {1: [], 2: []}
	_pending_choices = {1: [], 2: []}
	_round_wins = {1: 0, 2: 0}
