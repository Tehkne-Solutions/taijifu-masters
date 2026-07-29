extends Node

signal combat_attributes_applied(player_index: int, snapshot: Dictionary)
signal combat_balance_refreshed(snapshot: Dictionary)

const BASELINE := 50.0
const MIN_MULTIPLIER := 0.82
const MAX_MULTIPLIER := 1.22

var _scan_timer := 0.0
var _last_signature := ""
var _phase_tokens: Dictionary = {}
var _dodge_tokens: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.18
		_refresh_fighters()
	_apply_runtime_recovery(delta)

func _refresh_fighters() -> void:
	var preparation := _find_preparation()
	if preparation == null or not preparation.has_method("loadout_for_player"):
		return
	var comparison := get_node_or_null("/root/PreparationBuildComparisonRuntime")
	if comparison == null or not comparison.has_method("comparison_snapshot"):
		return
	var snapshot: Dictionary = comparison.comparison_snapshot(preparation)
	var signature := JSON.stringify(snapshot)
	var fighters := _find_fighters()
	if fighters.is_empty():
		return
	for fighter in fighters:
		var player_index := int(fighter.get("player_index"))
		var data := _player_data(snapshot, player_index)
		if data.is_empty():
			continue
		_apply_build_attributes(fighter, data)
		_apply_timing_attributes(fighter, data)
	if signature != _last_signature:
		_last_signature = signature
		combat_balance_refreshed.emit(snapshot)

func _apply_build_attributes(fighter: Node, data: Dictionary) -> void:
	var build: BuildProfile = fighter.get("build")
	if build == null:
		return
	if not fighter.has_meta("combat_attribute_original_build"):
		fighter.set_meta("combat_attribute_original_build", {
			"strength":build.strength,"defense":build.defense,"agility":build.agility,
			"resistance":build.resistance,"technique":build.technique,"control":build.control,
			"perception":build.perception,"focus":build.focus
		})
	var original: Dictionary = fighter.get_meta("combat_attribute_original_build")
	var str_score := float(data.get("str", BASELINE))
	var def_score := float(data.get("def", BASELINE))
	var agi_score := float(data.get("agi", BASELINE))
	var str_factor := _factor(str_score)
	var def_factor := _factor(def_score)
	var agi_factor := _factor(agi_score)
	build.strength = clampf(float(original.strength) * str_factor, 1.0, 100.0)
	build.technique = clampf(float(original.technique) * lerpf(1.0, str_factor, 0.35), 1.0, 100.0)
	build.defense = clampf(float(original.defense) * def_factor, 1.0, 100.0)
	build.resistance = clampf(float(original.resistance) * lerpf(1.0, def_factor, 0.72), 1.0, 100.0)
	build.control = clampf(float(original.control) * lerpf(1.0, def_factor, 0.62), 1.0, 100.0)
	build.agility = clampf(float(original.agility) * agi_factor, 1.0, 100.0)
	build.perception = clampf(float(original.perception) * lerpf(1.0, agi_factor, 0.35), 1.0, 100.0)
	build.focus = clampf(float(original.focus) * lerpf(1.0, agi_factor, 0.28), 1.0, 100.0)
	fighter.set_meta("combat_attribute_snapshot", data.duplicate(true))
	combat_attributes_applied.emit(int(fighter.get("player_index")), data)

func _apply_timing_attributes(fighter: Node, data: Dictionary) -> void:
	var instance_id := fighter.get_instance_id()
	var agi_score := float(data.get("agi", BASELINE))
	var str_score := float(data.get("str", BASELINE))
	var phase := int(fighter.get("_attack_phase"))
	var phase_token := "%d:%d" % [instance_id, phase]
	if phase != 0 and _phase_tokens.get(instance_id, "") != phase_token:
		_phase_tokens[instance_id] = phase_token
		var timer := float(fighter.get("_attack_phase_timer"))
		if phase == 1:
			timer *= clampf(1.08 - (agi_score - BASELINE) * 0.0025, 0.88, 1.12)
		elif phase == 3:
			timer *= clampf(1.10 - (agi_score - BASELINE) * 0.0035, 0.78, 1.16)
		elif phase == 2:
			timer *= clampf(1.0 + (str_score - BASELINE) * 0.0015, 0.94, 1.08)
		fighter.set("_attack_phase_timer", timer)
	elif phase == 0:
		_phase_tokens.erase(instance_id)
	var dodge_timer := float(fighter.get("_dodge_timer"))
	if dodge_timer > 0.0 and not _dodge_tokens.has(instance_id):
		_dodge_tokens[instance_id] = true
		fighter.set("_dodge_timer", dodge_timer * clampf(1.0 + (agi_score - BASELINE) * 0.0022, 0.90, 1.14))
		var cooldown := float(fighter.get("_dodge_cooldown_timer"))
		fighter.set("_dodge_cooldown_timer", cooldown * clampf(1.0 - (agi_score - BASELINE) * 0.0025, 0.82, 1.14))
	elif dodge_timer <= 0.0:
		_dodge_tokens.erase(instance_id)

func _apply_runtime_recovery(delta: float) -> void:
	for fighter in _find_fighters():
		if not fighter.has_meta("combat_attribute_snapshot"):
			continue
		var data: Dictionary = fighter.get_meta("combat_attribute_snapshot")
		var agi_bonus := clampf((float(data.get("agi", BASELINE)) - BASELINE) * 0.055, -1.5, 2.4)
		var def_bonus := clampf((float(data.get("def", BASELINE)) - BASELINE) * 0.035, -1.0, 1.8)
		fighter.set("stamina", minf(100.0, float(fighter.get("stamina")) + agi_bonus * delta))
		var build: BuildProfile = fighter.get("build")
		if build != null and int(fighter.get("_attack_phase")) == 0:
			fighter.set("posture", minf(build.max_posture(), float(fighter.get("posture")) + def_bonus * delta))

func _factor(score: float) -> float:
	return clampf(1.0 + (score - BASELINE) * 0.004, MIN_MULTIPLIER, MAX_MULTIPLIER)

func _player_data(snapshot: Dictionary, player_index: int) -> Dictionary:
	for value in Array(snapshot.get("players", [])):
		var data: Dictionary = value
		if int(data.get("player", 0)) == player_index:
			return data
	return {}

func _find_preparation() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_preparation_recursive(scene)

func _find_preparation_recursive(node: Node) -> Node:
	if node is BattlePreparationRuntime:
		return node
	for child in node.get_children():
		var found := _find_preparation_recursive(child)
		if found != null:
			return found
	return null

func _find_fighters() -> Array[Node]:
	var result: Array[Node] = []
	var scene := get_tree().current_scene
	if scene != null:
		_collect_fighters(scene, result)
	return result

func _collect_fighters(node: Node, result: Array[Node]) -> void:
	if node is FighterController:
		result.append(node)
	for child in node.get_children():
		_collect_fighters(child, result)

func integration_snapshot() -> Dictionary:
	return {
		"effects":["damage","posture","movement","dodge","recovery","technique"],
		"attribute_range":[MIN_MULTIPLIER,MAX_MULTIPLIER],
		"dynamic":true,
		"non_destructive":true
	}
