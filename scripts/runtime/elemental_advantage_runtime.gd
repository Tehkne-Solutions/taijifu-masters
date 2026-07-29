extends Node

signal elemental_matchup_applied(attacker_index: int, defender_index: int, element_id: String, multiplier: float)
signal elemental_status_scaled(player_index: int, status_id: String, duration_multiplier: float)
signal elemental_reaction_presented(player_index: int, interaction_id: String, element_id: String)

const ADVANTAGE := {
	"fire": "air",
	"air": "earth",
	"earth": "water",
	"water": "fire"
}
const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.36, 0.16),
	"water": Color(0.22, 0.62, 1.0),
	"earth": Color(0.62, 0.46, 0.25),
	"air": Color(0.62, 0.92, 1.0)
}
const STATUS_ELEMENT := {
	"burning": "fire",
	"wet": "water",
	"anchored": "earth",
	"air_unstable": "air"
}
const STRONG_MULTIPLIER := 1.18
const WEAK_MULTIPLIER := 0.86
const SAME_MULTIPLIER := 0.78
const EFFECT_WINDOW := 0.95

var _connected: Dictionary = {}
var _temporary_profiles: Dictionary = {}
var _visual_timers: Dictionary = {}
var _scan_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.25
		_connect_fighters()
	_update_temporary_profiles(delta)
	_update_visuals(delta)

func matchup_multiplier(attacking_element: String, defending_element: String) -> float:
	if attacking_element == "" or defending_element == "":
		return 1.0
	if attacking_element == defending_element:
		return SAME_MULTIPLIER
	if String(ADVANTAGE.get(attacking_element, "")) == defending_element:
		return STRONG_MULTIPLIER
	if String(ADVANTAGE.get(defending_element, "")) == attacking_element:
		return WEAK_MULTIPLIER
	return 1.0

func _connect_fighters() -> void:
	for fighter in _find_fighters():
		var id := fighter.get_instance_id()
		if _connected.has(id):
			continue
		_connected[id] = true
		if fighter.has_signal("technique_started"):
			fighter.technique_started.connect(_on_technique_started)
		if fighter.has_signal("elemental_state_changed"):
			fighter.elemental_state_changed.connect(_on_elemental_state_changed)
		if fighter.has_signal("elemental_interaction"):
			fighter.elemental_interaction.connect(_on_elemental_interaction)

func _on_technique_started(attacker: FighterController, technique_id: StringName) -> void:
	var technique := TechniqueCatalog.get_technique(technique_id)
	if not is_instance_valid(technique) or not technique.has_element():
		return
	var defender := _opponent_for(attacker)
	if defender == null or defender.build == null:
		return
	var attacking_element := String(technique.element_id)
	var defending_element := String(defender.build.element_id)
	var multiplier := matchup_multiplier(attacking_element, defending_element)
	_apply_temporary_matchup(attacker, defender, multiplier)
	_apply_visual(attacker, attacking_element, EFFECT_WINDOW)
	elemental_matchup_applied.emit(attacker.player_index, defender.player_index, attacking_element, multiplier)

func _apply_temporary_matchup(attacker: FighterController, defender: FighterController, multiplier: float) -> void:
	var attacker_id := attacker.get_instance_id()
	var defender_id := defender.get_instance_id()
	_store_profile(attacker)
	_store_profile(defender)
	var attacker_original: Dictionary = _temporary_profiles[attacker_id].original
	var defender_original: Dictionary = _temporary_profiles[defender_id].original
	attacker.build.strength = clampf(float(attacker_original.strength) * multiplier, 1.0, 100.0)
	attacker.build.technique = clampf(float(attacker_original.technique) * lerpf(1.0, multiplier, 0.65), 1.0, 100.0)
	var defensive_factor := clampf(2.0 - multiplier, 0.82, 1.22)
	defender.build.defense = clampf(float(defender_original.defense) * defensive_factor, 1.0, 100.0)
	defender.build.resistance = clampf(float(defender_original.resistance) * lerpf(1.0, defensive_factor, 0.72), 1.0, 100.0)
	_temporary_profiles[attacker_id].timer = EFFECT_WINDOW
	_temporary_profiles[defender_id].timer = EFFECT_WINDOW

func _store_profile(fighter: FighterController) -> void:
	var id := fighter.get_instance_id()
	if _temporary_profiles.has(id):
		return
	_temporary_profiles[id] = {
		"fighter": fighter,
		"timer": 0.0,
		"original": {
			"strength": fighter.build.strength,
			"technique": fighter.build.technique,
			"defense": fighter.build.defense,
			"resistance": fighter.build.resistance
		}
	}

func _update_temporary_profiles(delta: float) -> void:
	for id in _temporary_profiles.keys().duplicate():
		var entry: Dictionary = _temporary_profiles[id]
		var fighter: FighterController = entry.fighter
		if not is_instance_valid(fighter) or fighter.build == null:
			_temporary_profiles.erase(id)
			continue
		entry.timer = float(entry.timer) - delta
		_temporary_profiles[id] = entry
		if float(entry.timer) > 0.0:
			continue
		var original: Dictionary = entry.original
		fighter.build.strength = float(original.strength)
		fighter.build.technique = float(original.technique)
		fighter.build.defense = float(original.defense)
		fighter.build.resistance = float(original.resistance)
		_temporary_profiles.erase(id)

func _on_elemental_state_changed(fighter: FighterController, status_id: StringName) -> void:
	var source_element := String(STATUS_ELEMENT.get(String(status_id), ""))
	if source_element == "" or fighter.build == null:
		return
	var own_element := String(fighter.build.element_id)
	var duration_multiplier := 1.0
	if own_element == source_element:
		duration_multiplier = 0.72
	elif String(ADVANTAGE.get(source_element, "")) == own_element:
		duration_multiplier = 0.88
	elif String(ADVANTAGE.get(own_element, "")) == source_element:
		duration_multiplier = 1.14
	_scale_status_timer(fighter, String(status_id), duration_multiplier)
	_apply_visual(fighter, source_element, 0.55)
	elemental_status_scaled.emit(fighter.player_index, String(status_id), duration_multiplier)

func _scale_status_timer(fighter: FighterController, status_id: String, multiplier: float) -> void:
	var property_name := {
		"burning": "burning_timer",
		"wet": "wet_timer",
		"anchored": "anchored_timer",
		"air_unstable": "air_unstable_timer"
	}.get(status_id, "")
	if property_name == "":
		return
	fighter.set(property_name, float(fighter.get(property_name)) * multiplier)

func _on_elemental_interaction(fighter: FighterController, interaction_id: StringName, element_id: StringName) -> void:
	_apply_visual(fighter, String(element_id), 0.85)
	elemental_reaction_presented.emit(fighter.player_index, String(interaction_id), String(element_id))

func _apply_visual(fighter: FighterController, element_id: String, duration: float) -> void:
	var color: Color = ELEMENT_COLORS.get(element_id, Color.WHITE)
	fighter.modulate = color.lightened(0.28)
	_visual_timers[fighter.get_instance_id()] = {"fighter": fighter, "timer": duration}

func _update_visuals(delta: float) -> void:
	for id in _visual_timers.keys().duplicate():
		var entry: Dictionary = _visual_timers[id]
		var fighter: FighterController = entry.fighter
		if not is_instance_valid(fighter):
			_visual_timers.erase(id)
			continue
		entry.timer = float(entry.timer) - delta
		_visual_timers[id] = entry
		if float(entry.timer) <= 0.0:
			fighter.modulate = Color.WHITE
			_visual_timers.erase(id)

func _opponent_for(attacker: FighterController) -> FighterController:
	for fighter in _find_fighters():
		if fighter != attacker and fighter.player_index != attacker.player_index:
			return fighter
	return null

func _find_fighters() -> Array[FighterController]:
	var result: Array[FighterController] = []
	var scene := get_tree().current_scene
	if scene != null:
		_collect_fighters(scene, result)
	return result

func _collect_fighters(node: Node, result: Array[FighterController]) -> void:
	if node is FighterController:
		result.append(node)
	for child in node.get_children():
		_collect_fighters(child, result)

func system_snapshot() -> Dictionary:
	return {
		"elements": ADVANTAGE.keys(),
		"advantage_cycle": ADVANTAGE.duplicate(true),
		"multipliers": {"strong": STRONG_MULTIPLIER, "weak": WEAK_MULTIPLIER, "same": SAME_MULTIPLIER},
		"existing_reactions_preserved": true,
		"status_scaling": true,
		"visual_feedback": true
	}
