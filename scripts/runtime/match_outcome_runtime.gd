class_name MatchOutcomeRuntime
extends Node

const CONNECT_INTERVAL := 0.30

@onready var main: Node = get_parent()

var _connect_timer := 0.0
var _connected_fighters: Dictionary = {}
var _outcome_active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_fighters()

func _process(delta: float) -> void:
	_connect_timer -= delta
	if _connect_timer <= 0.0:
		_connect_timer = CONNECT_INTERVAL
		_connect_fighters()
	if _outcome_active and _round_has_been_reset():
		_reset_all_outcomes()

func _connect_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as FighterController
		if not is_instance_valid(fighter):
			continue
		var key := str(fighter.get_instance_id())
		if _connected_fighters.has(key):
			continue
		_connected_fighters[key] = fighter
		var callback := Callable(self, "_on_fighter_defeated")
		if not fighter.defeated.is_connected(callback):
			fighter.defeated.connect(callback)
	for key in _connected_fighters.keys():
		if not is_instance_valid(_connected_fighters[key]):
			_connected_fighters.erase(key)

func _on_fighter_defeated(defeated_fighter: FighterController) -> void:
	if _outcome_active:
		return
	_outcome_active = true
	var defeated_outcome := defeated_fighter.get_node_or_null("OutcomeRuntime") as FighterOutcomeRuntime
	if is_instance_valid(defeated_outcome):
		defeated_outcome.play_defeat()
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as FighterController
		if not is_instance_valid(fighter) or fighter == defeated_fighter:
			continue
		var winner_outcome := fighter.get_node_or_null("OutcomeRuntime") as FighterOutcomeRuntime
		if is_instance_valid(winner_outcome):
			winner_outcome.play_victory()

func _round_has_been_reset() -> bool:
	if bool(main.get("_resetting_round")):
		return false
	var fighters := get_tree().get_nodes_in_group("fighters")
	if fighters.size() < 2:
		return false
	for node in fighters:
		var fighter := node as FighterController
		if not is_instance_valid(fighter) or not is_instance_valid(fighter.build):
			return false
		if fighter.health < fighter.build.max_health() - 0.01:
			return false
	return true

func _reset_all_outcomes() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as FighterController
		if not is_instance_valid(fighter):
			continue
		var outcome := fighter.get_node_or_null("OutcomeRuntime") as FighterOutcomeRuntime
		if is_instance_valid(outcome):
			outcome.reset_outcome()
	_outcome_active = false

func force_preview(defeated_player_index: int) -> void:
	_outcome_active = true
	for node in get_tree().get_nodes_in_group("fighters"):
		var fighter := node as FighterController
		if not is_instance_valid(fighter):
			continue
		var outcome := fighter.get_node_or_null("OutcomeRuntime") as FighterOutcomeRuntime
		if not is_instance_valid(outcome):
			continue
		if fighter.player_index == defeated_player_index:
			outcome.play_defeat()
		else:
			outcome.play_victory()
