extends Node

const HISTORY_WINDOW := 22.0
const MAX_STACKS_PER_ITEM := 3

const SYNERGIES := {
	"storm_dancer": {"requires": ["wind_step", "focus_charm"], "label": "DANÇARINO DA TEMPESTADE", "bonuses": {"agility": 12.0, "focus": 10.0}, "duration": 10.0, "vfx": "air"},
	"iron_titan": {"requires": ["iron_guard", "titan_force"], "label": "TITÃ DE FERRO", "bonuses": {"defense": 14.0, "strength": 12.0}, "duration": 11.0, "vfx": "earth"},
	"flowing_echo": {"requires": ["vital_orb", "echo_scroll"], "label": "ECO FLUIDO", "bonuses": {"focus": 12.0, "resistance": 10.0}, "duration": 10.0, "vfx": "water"},
	"perfect_balance": {"requires": ["wind_step", "iron_guard", "focus_charm"], "label": "EQUILÍBRIO PERFEITO", "bonuses": {"agility": 10.0, "defense": 10.0, "focus": 10.0}, "duration": 13.0, "vfx": "loot_skill"}
}

const LEGENDARY_EVOLUTIONS := {
	"wind_step": {"label": "PASSO DO TUFÃO", "stat": "agility", "amount": 18.0, "duration": 12.0, "vfx": "air"},
	"iron_guard": {"label": "BASTIÃO IMÓVEL", "stat": "defense", "amount": 18.0, "duration": 12.0, "vfx": "block"},
	"titan_force": {"label": "PUNHO DO COLOSSO", "stat": "strength", "amount": 20.0, "duration": 11.0, "vfx": "earth"},
	"focus_charm": {"label": "MENTE SEM LIMITE", "stat": "focus", "amount": 20.0, "duration": 12.0, "vfx": "loot_skill"}
}

const CURSE_CONFLICTS := {
	"blood_crown": {"blocked_by": "iron_guard", "label": "SANGUE CONTRA AÇO", "penalty_stat": "stamina", "penalty": 18.0},
	"void_feather": {"blocked_by": "wind_step", "label": "VENTO DEVORADO", "penalty_stat": "health", "penalty": 12.0},
	"oracle_mask": {"blocked_by": "titan_force", "label": "VISÃO SEM CORPO", "penalty_stat": "posture", "penalty": 16.0}
}

var _history: Dictionary = {}
var _triggered: Dictionary = {}
var _stack_counts: Dictionary = {}
var _pickup_runtime: Node

func _ready() -> void:
	_pickup_runtime = get_node_or_null("/root/ProceduralArenaPickupRuntime")
	if _pickup_runtime != null and not _pickup_runtime.pickup_collected.is_connected(_on_pickup_collected):
		_pickup_runtime.pickup_collected.connect(_on_pickup_collected)
	set_process(true)

func _process(delta: float) -> void:
	for player_key in _history.keys():
		var entries: Array = _history[player_key]
		for index in range(entries.size() - 1, -1, -1):
			entries[index]["remaining"] = float(entries[index]["remaining"]) - delta
			if float(entries[index]["remaining"]) <= 0.0:
				entries.remove_at(index)
		_history[player_key] = entries
		_cleanup_triggered(player_key, entries)

func _on_pickup_collected(fighter: FighterController, item_id: String, rarity: String, tags: Array[String]) -> void:
	var player_key := str(fighter.get_instance_id())
	if not _history.has(player_key):
		_history[player_key] = []
	var entries: Array = _history[player_key]
	entries.append({"item_id": item_id, "rarity": rarity, "tags": tags, "remaining": HISTORY_WINDOW})
	_history[player_key] = entries
	_increment_stack(player_key, item_id)
	_check_conflicts(fighter, player_key, item_id)
	_check_synergies(fighter, player_key)
	if rarity == "legendary":
		_apply_legendary_evolution(fighter, player_key, item_id)

func _increment_stack(player_key: String, item_id: String) -> void:
	var key := "%s:%s" % [player_key, item_id]
	_stack_counts[key] = mini(int(_stack_counts.get(key, 0)) + 1, MAX_STACKS_PER_ITEM)

func _check_synergies(fighter: FighterController, player_key: String) -> void:
	var active_items := _active_item_ids(player_key)
	for synergy_id in SYNERGIES:
		var spec: Dictionary = SYNERGIES[synergy_id]
		var satisfied := true
		for required in spec["requires"]:
			if not active_items.has(String(required)):
				satisfied = false
				break
		if satisfied:
			var trigger_key := "%s:synergy:%s" % [player_key, synergy_id]
			if not bool(_triggered.get(trigger_key, false)):
				_triggered[trigger_key] = true
				_apply_synergy(fighter, synergy_id, spec)

func _apply_synergy(fighter: FighterController, synergy_id: String, spec: Dictionary) -> void:
	if _pickup_runtime == null:
		return
	for stat in spec["bonuses"]:
		_pickup_runtime.add_external_buff(fighter, String(stat), float(spec["bonuses"][stat]), float(spec["duration"]), "synergy_%s" % synergy_id)
	fighter.stamina = minf(100.0, fighter.stamina + 16.0)
	_spawn_feedback(fighter, String(spec["label"]), String(spec["vfx"]))

func _apply_legendary_evolution(fighter: FighterController, player_key: String, item_id: String) -> void:
	if not LEGENDARY_EVOLUTIONS.has(item_id) or _pickup_runtime == null:
		return
	var trigger_key := "%s:legendary:%s" % [player_key, item_id]
	if bool(_triggered.get(trigger_key, false)):
		return
	_triggered[trigger_key] = true
	var spec: Dictionary = LEGENDARY_EVOLUTIONS[item_id]
	_pickup_runtime.add_external_buff(fighter, String(spec["stat"]), float(spec["amount"]), float(spec["duration"]), "legendary_%s" % item_id)
	fighter.health = minf(fighter.build.max_health(), fighter.health + 10.0)
	_spawn_feedback(fighter, String(spec["label"]), String(spec["vfx"]))

func _check_conflicts(fighter: FighterController, player_key: String, item_id: String) -> void:
	if not CURSE_CONFLICTS.has(item_id):
		return
	var conflict: Dictionary = CURSE_CONFLICTS[item_id]
	if not _active_item_ids(player_key).has(String(conflict["blocked_by"])):
		return
	match String(conflict["penalty_stat"]):
		"health": fighter.health = maxf(1.0, fighter.health - float(conflict["penalty"]))
		"posture": fighter.posture = maxf(0.0, fighter.posture - float(conflict["penalty"]))
		_: fighter.stamina = maxf(0.0, fighter.stamina - float(conflict["penalty"]))
	_spawn_feedback(fighter, String(conflict["label"]), "defeat")

func _spawn_feedback(fighter: FighterController, label_text: String, vfx: String) -> void:
	var event_runtime := get_node_or_null("/root/Pack99CombatEventRuntime")
	if event_runtime != null:
		event_runtime._spawn_event(fighter, vfx, Vector2(0, -76), 0.46)
	if get_tree().current_scene == null:
		return
	var label := Label.new()
	label.text = label_text
	label.position = fighter.global_position + Vector2(-120, -145)
	label.size = Vector2(240, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 120
	label.add_theme_font_size_override("font_size", 16)
	get_tree().current_scene.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 34.0, 0.85)
	tween.tween_property(label, "modulate:a", 0.0, 0.85)
	tween.chain().tween_callback(label.queue_free)

func _active_item_ids(player_key: String) -> Array[String]:
	var result: Array[String] = []
	for entry in _history.get(player_key, []):
		var item_id := String(entry["item_id"])
		if not result.has(item_id):
			result.append(item_id)
	return result

func _cleanup_triggered(player_key: String, entries: Array) -> void:
	var active := []
	for entry in entries:
		active.append(String(entry["item_id"]))
	for synergy_id in SYNERGIES:
		var still_valid := true
		for required in SYNERGIES[synergy_id]["requires"]:
			if not active.has(String(required)):
				still_valid = false
		if not still_valid:
			_triggered.erase("%s:synergy:%s" % [player_key, synergy_id])

func synergy_count() -> int:
	return SYNERGIES.size()

func cursed_conflict_count() -> int:
	return CURSE_CONFLICTS.size()

func stack_count_for(fighter: FighterController, item_id: String) -> int:
	return int(_stack_counts.get("%s:%s" % [str(fighter.get_instance_id()), item_id], 0))
