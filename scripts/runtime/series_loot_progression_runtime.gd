extends Node

signal reward_choices_ready(player_index: int, choices: Array[Dictionary])
signal reward_chosen(player_index: int, reward: Dictionary)
signal inventory_changed(player_index: int, inventory: Array[Dictionary])
signal round_resolved(winner_index: int, loser_index: int)
signal item_protection_changed(player_index: int, item_id: String)

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
var _protected_item_ids := {1: "", 2: ""}
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
	round_resolved.emit(winner, loser)

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
		var remove_index := 0
		if String(inventory[0].get("id", "")) == protected_item_id(player_index) and inventory.size() > 1:
			remove_index = 1
		inventory.remove_at(remove_index)
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
	var candidates: Array[int] = []
	for index in range(inventory.size()):
		if String(inventory[index].get("id", "")) != protected_item_id(player_index):
			candidates.append(index)
	var loss_count := mini(candidates.size(), maxi(1, int(ceil(inventory.size() * LOSS_FRACTION))))
	candidates.shuffle()
	var selected := candidates.slice(0, loss_count)
	selected.sort()
	selected.reverse()
	for index in selected:
		inventory.remove_at(index)
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

func protect_item(player_index: int, item_index: int) -> bool:
	var inventory: Array = _inventories.get(player_index, [])
	if item_index < 0 or item_index >= inventory.size():
		return false
	var item_id := String(inventory[item_index].get("id", ""))
	_protected_item_ids[player_index] = item_id
	item_protection_changed.emit(player_index, item_id)
	return true

func discard_item(player_index: int, item_index: int) -> bool:
	var inventory: Array = _inventories.get(player_index, [])
	if item_index < 0 or item_index >= inventory.size():
		return false
	var removed: Dictionary = inventory[item_index]
	inventory.remove_at(item_index)
	_inventories[player_index] = inventory
	if protected_item_id(player_index) == String(removed.get("id", "")):
		_protected_item_ids[player_index] = ""
	inventory_changed.emit(player_index, inventory_snapshot(player_index))
	return true

func protected_item_id(player_index: int) -> String:
	return String(_protected_item_ids.get(player_index, ""))

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
	_protected_item_ids = {1: "", 2: ""}
