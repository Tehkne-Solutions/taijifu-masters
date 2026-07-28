extends Node

signal training_xp_awarded(focus_id: String, amount: int, total_xp: int)
signal medal_unlocked(medal_id: String)
signal certification_unlocked(certification_id: String)
signal training_reward_granted(focus_id: String, reward: Dictionary)
signal variant_reward_unlocked(variant_id: String)

const SAVE_PATH := "user://taijifu-training-progression.json"
const CERTIFICATION_REQUIREMENT := 3

const REWARDS := {
	"free": {"xp": 100, "tokens": 1, "medal": "medal_training_initiate", "label": "MEDALHA DO INICIADO"},
	"tai": {"xp": 180, "tokens": 2, "medal": "medal_tai", "certification": "certification_tai", "master_id": "lyenne", "variant_id": "lyenne_crossing_wing", "label": "MEDALHA TAI"},
	"ji": {"xp": 180, "tokens": 2, "medal": "medal_ji", "certification": "certification_ji", "master_id": "orra", "variant_id": "orra_inverted_foundation", "label": "MEDALHA JI"},
	"fu": {"xp": 180, "tokens": 2, "medal": "medal_fu", "certification": "certification_fu", "master_id": "han", "variant_id": "han_three_currents", "label": "MEDALHA FU"},
	"ghost": {"xp": 250, "tokens": 3, "medal": "medal_ghost_runner", "certification": "certification_ghost", "label": "MEDALHA DO CORREDOR FANTASMA"}
}

var _data: Dictionary = {
	"version": 1,
	"total_xp": 0,
	"training_tokens": 0,
	"completions": {},
	"medals": [],
	"certifications": [],
	"reward_history": []
}
var _toast_layer: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_from_disk()
	call_deferred("_connect_objective_runtime")

func _connect_objective_runtime() -> void:
	var objectives := get_node_or_null("/root/CombatDifficultyTrainingRuntime")
	if objectives != null and objectives.has_signal("training_objective_completed"):
		if not objectives.training_objective_completed.is_connected(_on_training_objective_completed):
			objectives.training_objective_completed.connect(_on_training_objective_completed)

func _on_training_objective_completed(focus_id: String) -> void:
	grant_completion(focus_id)

func grant_completion(focus_id: String) -> Dictionary:
	if not REWARDS.has(focus_id):
		return {}
	var spec: Dictionary = Dictionary(REWARDS[focus_id]).duplicate(true)
	var completions: Dictionary = _data.get("completions", {})
	var count := int(completions.get(focus_id, 0)) + 1
	completions[focus_id] = count
	_data["completions"] = completions

	var xp := int(spec.get("xp", 0))
	var tokens := int(spec.get("tokens", 0))
	_data["total_xp"] = int(_data.get("total_xp", 0)) + xp
	_data["training_tokens"] = int(_data.get("training_tokens", 0)) + tokens
	training_xp_awarded.emit(focus_id, xp, int(_data["total_xp"]))

	var newly_unlocked: Array[String] = []
	var medal_id := String(spec.get("medal", ""))
	if medal_id != "" and _unlock_collection_item("medals", medal_id):
		newly_unlocked.append(medal_id)
		medal_unlocked.emit(medal_id)

	var certification_id := String(spec.get("certification", ""))
	var variant_id := String(spec.get("variant_id", ""))
	if certification_id != "" and count >= CERTIFICATION_REQUIREMENT:
		if _unlock_collection_item("certifications", certification_id):
			newly_unlocked.append(certification_id)
			certification_unlocked.emit(certification_id)
			if variant_id != "" and _unlock_master_variant(spec):
				newly_unlocked.append(variant_id)
				variant_reward_unlocked.emit(variant_id)

	var reward := {
		"focus_id": focus_id,
		"completion": count,
		"xp": xp,
		"tokens": tokens,
		"total_xp": int(_data["total_xp"]),
		"new_unlocks": newly_unlocked,
		"timestamp": int(Time.get_unix_time_from_system())
	}
	var history: Array = _data.get("reward_history", [])
	history.append(reward)
	while history.size() > 50:
		history.pop_front()
	_data["reward_history"] = history
	_save_to_disk()
	training_reward_granted.emit(focus_id, reward.duplicate(true))
	_show_reward_toast(spec, reward)
	return reward

func _unlock_collection_item(field: String, item_id: String) -> bool:
	var collection: Array = _data.get(field, [])
	if item_id in collection:
		return false
	collection.append(item_id)
	_data[field] = collection
	return true

func _unlock_master_variant(spec: Dictionary) -> bool:
	var runtime := _find_master_training_runtime()
	if runtime == null:
		return false
	var ledger: Variant = runtime.get("ledger")
	if ledger == null or not ledger.has_method("unlock_variant"):
		return false
	var changed := false
	var master_id := StringName(spec.get("master_id", ""))
	var variant_id := StringName(spec.get("variant_id", ""))
	for profile_id in ["p1", "p2"]:
		changed = bool(ledger.unlock_variant(profile_id, master_id, variant_id)) or changed
	if ledger.has_method("save_to_disk"):
		ledger.save_to_disk()
	return changed

func _find_master_training_runtime() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		var local := scene.get_node_or_null("MasterTrainingRuntime")
		if local != null:
			return local
	var candidates := get_tree().get_nodes_in_group("master_training_runtime")
	return candidates[0] if not candidates.is_empty() else null

func _show_reward_toast(spec: Dictionary, reward: Dictionary) -> void:
	if is_instance_valid(_toast_layer):
		_toast_layer.queue_free()
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 500
	_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_toast_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(385, 235)
	panel.size = Vector2(510, 210)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_toast_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "TREINO CONCLUÍDO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	box.add_child(title)
	var summary := Label.new()
	summary.text = "%s\n+%d XP  •  +%d FICHAS DE TREINO" % [String(spec.get("label", "RECOMPENSA")), int(reward["xp"]), int(reward["tokens"])]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 17)
	box.add_child(summary)
	var unlocks: Array = reward.get("new_unlocks", [])
	if not unlocks.is_empty():
		var unlocked := Label.new()
		unlocked.text = "NOVO DESBLOQUEIO: %s" % " • ".join(unlocks).to_upper()
		unlocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlocked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(unlocked)
	var close := Button.new()
	close.text = "CONTINUAR"
	close.process_mode = Node.PROCESS_MODE_ALWAYS
	close.pressed.connect(func():
		if is_instance_valid(_toast_layer):
			_toast_layer.queue_free()
	)
	box.add_child(close)

func progression_snapshot() -> Dictionary:
	var level := 1 + int(floor(float(_data.get("total_xp", 0)) / 500.0))
	var result := _data.duplicate(true)
	result["level"] = level
	result["xp_into_level"] = int(_data.get("total_xp", 0)) % 500
	result["xp_per_level"] = 500
	return result

func completion_count(focus_id: String) -> int:
	return int(Dictionary(_data.get("completions", {})).get(focus_id, 0))

func has_medal(medal_id: String) -> bool:
	return medal_id in Array(_data.get("medals", []))

func has_certification(certification_id: String) -> bool:
	return certification_id in Array(_data.get("certifications", []))

func _load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_data.merge(parsed, true)

func _save_to_disk() -> String:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
	_data["version"] = 1
	_data["updated_unix"] = int(Time.get_unix_time_from_system())
	file.store_string(JSON.stringify(_data, "\t"))
	return SAVE_PATH
