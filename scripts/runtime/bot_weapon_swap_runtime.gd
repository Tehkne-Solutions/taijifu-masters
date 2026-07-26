class_name BotWeaponSwapRuntime
extends Node

@onready var tactical_bot: TacticalBotRuntime = get_node("../TacticalBotRuntime")

var _bot: WeaponKitFighterController
var _opponent: FighterController
var _decision_timer := 0.0
var _tap_timer := 0.0

func _ready() -> void:
	_register_key_action(&"p2_swap", KEY_KP_7)

func _process(delta: float) -> void:
	_discover_fighters()
	_update_tap(delta)
	_decision_timer = maxf(0.0, _decision_timer - delta)
	if not tactical_bot.enabled or not is_instance_valid(_bot) or not is_instance_valid(_opponent):
		_release_swap()
		return
	if _decision_timer > 0.0:
		return
	_decision_timer = randf_range(0.85, 1.35)
	_consider_swap()

func _discover_fighters() -> void:
	if is_instance_valid(_bot) and is_instance_valid(_opponent):
		return
	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is FighterController):
			continue
		var fighter := node as FighterController
		if fighter.player_index == 1:
			_opponent = fighter
		elif fighter.player_index == 2 and fighter is WeaponKitFighterController:
			_bot = fighter as WeaponKitFighterController

func _consider_swap() -> void:
	if not _bot.can_swap_weapon():
		return
	var next_weapon := _bot.next_available_weapon_id()
	if next_weapon == &"" or next_weapon == _bot.equipped_weapon_id:
		return

	var distance := absf(_opponent.global_position.x - _bot.global_position.x)
	var desired_distance := _personality_target_distance()
	var current_range := WeaponKitCatalog.preferred_range(_bot.equipped_weapon_id)
	var next_range := WeaponKitCatalog.preferred_range(next_weapon)
	var current_error := absf(desired_distance - current_range) + absf(distance - current_range) * 0.35
	var next_error := absf(desired_distance - next_range) + absf(distance - next_range) * 0.35

	if _bot.equipped_weapon_id == &"unarmed":
		_tap_swap()
		return
	if tactical_bot.personality_id == &"chaotic" and randf() < 0.24:
		_tap_swap()
		return
	if next_error + 24.0 < current_error:
		_tap_swap()

func _personality_target_distance() -> float:
	match tactical_bot.personality_id:
		&"aggressive":
			return 78.0
		&"guardian":
			return 132.0
		&"chaotic":
			return randf_range(72.0, 158.0)
		_:
			return 112.0

func _tap_swap() -> void:
	var action := _bot._action("swap")
	Input.action_release(action)
	Input.action_press(action)
	_tap_timer = 0.09

func _update_tap(delta: float) -> void:
	if _tap_timer <= 0.0:
		return
	_tap_timer -= delta
	if _tap_timer <= 0.0:
		_release_swap()

func _release_swap() -> void:
	if not is_instance_valid(_bot):
		_tap_timer = 0.0
		return
	Input.action_release(_bot._action("swap"))
	_tap_timer = 0.0

func _register_key_action(action_id: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == physical_keycode:
			return
	InputMap.action_add_event(action_id, event)

func _exit_tree() -> void:
	_release_swap()