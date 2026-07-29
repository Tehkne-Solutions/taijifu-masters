extends Node

signal comparison_refreshed(snapshot: Dictionary)
signal dominant_attribute_changed(player_index: int, attribute_id: String)

const WEAPON_MODIFIERS := {
	"training_staff": {"str":1,"def":1,"agi":2},
	"wind_wraps": {"str":0,"def":1,"agi":3},
	"seismic_gauntlets": {"str":3,"def":2,"agi":-1},
	"breaker_gauntlets": {"str":4,"def":0,"agi":-1},
	"unarmed": {"str":1,"def":1,"agi":1}
}
const ELEMENT_MODIFIERS := {
	"fire": {"str":2,"def":0,"agi":0},
	"water": {"str":0,"def":2,"agi":0},
	"earth": {"str":1,"def":3,"agi":-1},
	"air": {"str":0,"def":0,"agi":3}
}

var _last_signature := ""
var _last_dominant := ["", ""]
var _scan_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = 0.15
	var preparation := _find_preparation()
	if preparation == null or not preparation.has_method("is_active") or not preparation.is_active():
		return
	var snapshot := comparison_snapshot(preparation)
	var signature := JSON.stringify(snapshot)
	if signature == _last_signature:
		return
	_last_signature = signature
	_apply_to_preparation(preparation, snapshot)
	comparison_refreshed.emit(snapshot)

func comparison_snapshot(preparation: Node = null) -> Dictionary:
	if preparation == null:
		preparation = _find_preparation()
	if preparation == null or not preparation.has_method("loadout_for_player"):
		return {"players":[],"advantage":{}}
	var players: Array[Dictionary] = []
	for player_index in [1, 2]:
		players.append(_player_snapshot(preparation, player_index))
	return {"players":players,"advantage":_advantage(players[0], players[1])}

func _player_snapshot(preparation: Node, player_index: int) -> Dictionary:
	var loadout: Dictionary = preparation.loadout_for_player(player_index)
	var build := BuildProfile.prototype_preset(StringName(loadout.get("preset_id", &"adaptive_staff")))
	var stats := {
		"str": roundi(build.tai_index()),
		"def": roundi(build.fu_index()),
		"agi": roundi(build.ji_index())
	}
	_apply_modifier(stats, WEAPON_MODIFIERS.get(String(loadout.get("primary_weapon_id", "unarmed")), {}))
	_apply_modifier(stats, WEAPON_MODIFIERS.get(String(loadout.get("secondary_weapon_id", "unarmed")), {}), 0.5)
	_apply_modifier(stats, ELEMENT_MODIFIERS.get(String(loadout.get("element_id", "air")), {}))
	var dominant := _dominant(stats)
	var slot := player_index - 1
	if _last_dominant[slot] != dominant:
		_last_dominant[slot] = dominant
		dominant_attribute_changed.emit(player_index, dominant)
	return {
		"player":player_index,
		"character":String(loadout.get("character_id", "kael")),
		"build":String(loadout.get("preset_id", "adaptive_staff")),
		"primary":String(loadout.get("primary_weapon_id", "unarmed")),
		"secondary":String(loadout.get("secondary_weapon_id", "unarmed")),
		"element":String(loadout.get("element_id", "air")),
		"variant":String(loadout.get("variant_id", "")),
		"str":maxi(1, int(stats.str)),
		"def":maxi(1, int(stats.def)),
		"agi":maxi(1, int(stats.agi)),
		"dominant":dominant,
		"power":maxi(1, int(stats.str)+int(stats.def)+int(stats.agi))
	}

func _apply_modifier(stats: Dictionary, modifier: Dictionary, scale: float = 1.0) -> void:
	for key in ["str", "def", "agi"]:
		stats[key] = int(stats.get(key, 0)) + roundi(float(modifier.get(key, 0)) * scale)

func _dominant(stats: Dictionary) -> String:
	var result := "str"
	for key in ["def", "agi"]:
		if int(stats.get(key, 0)) > int(stats.get(result, 0)):
			result = key
	return result

func _advantage(p1: Dictionary, p2: Dictionary) -> Dictionary:
	var result := {}
	for key in ["str", "def", "agi", "power"]:
		var delta := int(p1.get(key, 0)) - int(p2.get(key, 0))
		result[key] = {"leader":1 if delta > 0 else (2 if delta < 0 else 0),"delta":absi(delta)}
	return result

func _apply_to_preparation(preparation: Node, snapshot: Dictionary) -> void:
	var labels: Array = preparation.get("_player_stats")
	var summaries: Array = preparation.get("_player_summaries")
	var players: Array = snapshot.get("players", [])
	for slot in range(mini(2, players.size())):
		var data: Dictionary = players[slot]
		if slot < labels.size() and is_instance_valid(labels[slot]):
			labels[slot].text = "FOR %d   DEF %d   AGI %d   •   PODER %d   •   FOCO %s" % [data.str, data.def, data.agi, data.power, String(data.dominant).to_upper()]
		if slot < summaries.size() and is_instance_valid(summaries[slot]):
			var current := String(summaries[slot].text).split("\n")[0]
			summaries[slot].text = "%s\nBUILD %s • %s / %s • ELEMENTO %s" % [current, String(data.build).replace("_", " ").to_upper(), WeaponKitCatalog.label_for(StringName(data.primary)), WeaponKitCatalog.label_for(StringName(data.secondary)), String(data.element).to_upper()]

func _find_preparation() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return _find_by_class(scene)

func _find_by_class(node: Node) -> Node:
	if node is BattlePreparationRuntime:
		return node
	for child in node.get_children():
		var found := _find_by_class(child)
		if found != null:
			return found
	return null

func system_snapshot() -> Dictionary:
	return {"attributes":["str","def","agi"],"weapon_modifiers":WEAPON_MODIFIERS.size(),"element_modifiers":ELEMENT_MODIFIERS.size(),"dynamic":true}
