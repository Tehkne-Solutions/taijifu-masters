extends Node

signal combat_scaling_applied(difficulty_id: String, unit_count: int)
signal training_objective_changed(focus_id: String, progress: float, target: float)
signal training_objective_completed(focus_id: String)

const TRAINING_TARGETS := {
	"free": {"label":"SOBREVIVA E PRATIQUE","target":30.0,"metric":"seconds"},
	"tai": {"label":"PERCORRA A ARENA","target":1200.0,"metric":"distance"},
	"ji": {"label":"EXECUTE 3 PROJEÇÕES","target":3.0,"metric":"grabs"},
	"fu": {"label":"REALIZE 3 APAROS","target":3.0,"metric":"parries"},
	"ghost": {"label":"COMPLETE 45 SEGUNDOS CONTRA O FANTASMA","target":45.0,"metric":"seconds"}
}

var _scaled_units: Dictionary = {}
var _fighters: Dictionary = {}
var _connected: Dictionary = {}
var _last_positions: Dictionary = {}
var _progress := {"free":0.0,"tai":0.0,"ji":0.0,"fu":0.0,"ghost":0.0}
var _completed: Dictionary = {}
var _scan_timer := 0.0
var _hud_layer: CanvasLayer
var _hud_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.2
		_discover_fighters()
		_apply_unit_scaling()
		_apply_pickup_frequency()
	_update_training(delta)

func _discover_fighters() -> void:
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if not fighter is FighterController:
			continue
		var player_index := int(fighter.player_index)
		_fighters[player_index] = fighter
		var key := str(fighter.get_instance_id())
		if not _connected.has(key):
			_connected[key] = fighter
			_last_positions[key] = fighter.global_position
			if fighter.has_signal("parry_performed"):
				fighter.parry_performed.connect(_on_parry)
			if fighter.has_signal("grab_finished"):
				fighter.grab_finished.connect(_on_grab_finished)

func _difficulty_config() -> Dictionary:
	var preparation := get_node_or_null("/root/ModeAwarePreparationRuntime")
	if preparation != null and preparation.has_method("context_snapshot"):
		return Dictionary(preparation.context_snapshot().get("champion_config", {}))
	return {"unit_scale":1.0,"champion_scale":1.0,"pickup_interval":9.0}

func _difficulty_id() -> String:
	var preparation := get_node_or_null("/root/ModeAwarePreparationRuntime")
	return String(preparation.selected_champion_difficulty()) if preparation != null else "master"

func _apply_unit_scaling() -> void:
	var runtime := get_node_or_null("/root/Pack08ArenaUnitRuntime")
	if runtime == null:
		return
	var units: Array = runtime.get("_units") if runtime.get("_units") != null else []
	var config := _difficulty_config()
	var applied := 0
	for unit in units:
		if not unit is Dictionary:
			continue
		var node := unit.get("node") as Node2D
		if not is_instance_valid(node):
			continue
		var key := str(node.get_instance_id())
		if _scaled_units.has(key):
			continue
		var champion := String(unit.get("archetype", "")) == "champion_dragon"
		var scale := float(config.get("champion_scale" if champion else "unit_scale", 1.0))
		unit["health"] = float(unit.get("health", 1.0)) * scale
		unit["max_health"] = float(unit.get("max_health", 1.0)) * scale
		unit["damage"] = float(unit.get("damage", 1.0)) * scale
		unit["posture"] = float(unit.get("posture", 1.0)) * scale
		node.scale = Vector2.ONE * clampf(0.9 + (scale - 1.0) * 0.5, 0.8, 1.18)
		_scaled_units[key] = true
		applied += 1
	if applied > 0:
		combat_scaling_applied.emit(_difficulty_id(), applied)

func _apply_pickup_frequency() -> void:
	var runtime := get_node_or_null("/root/ProceduralArenaPickupRuntime")
	if runtime == null:
		return
	var desired := float(_difficulty_config().get("pickup_interval", 9.0))
	var current := float(runtime.get("_spawn_timer"))
	if current > desired:
		runtime.set("_spawn_timer", desired)

func _training_focus() -> String:
	var preparation := get_node_or_null("/root/ModeAwarePreparationRuntime")
	return String(preparation.selected_training_focus()) if preparation != null else "free"

func _training_active() -> bool:
	var modes := get_node_or_null("/root/GameModeRuntime")
	return modes != null and String(modes.current_mode) == "training"

func _update_training(delta: float) -> void:
	if not _training_active():
		_hide_hud()
		return
	var focus := _training_focus()
	if not TRAINING_TARGETS.has(focus):
		return
	if focus in ["free", "ghost"]:
		_add_progress(focus, delta)
	elif focus == "tai":
		var distance := 0.0
		for fighter in _fighters.values():
			if not is_instance_valid(fighter):
				continue
			var key := str(fighter.get_instance_id())
			var previous: Vector2 = _last_positions.get(key, fighter.global_position)
			distance += previous.distance_to(fighter.global_position)
			_last_positions[key] = fighter.global_position
		_add_progress(focus, distance)
	_show_hud(focus)

func _on_parry(_fighter: FighterController) -> void:
	if _training_active() and _training_focus() == "fu":
		_add_progress("fu", 1.0)

func _on_grab_finished(_attacker: FighterController, _target: FighterController) -> void:
	if _training_active() and _training_focus() == "ji":
		_add_progress("ji", 1.0)

func _add_progress(focus: String, amount: float) -> void:
	if bool(_completed.get(focus, false)):
		return
	var target := float(TRAINING_TARGETS[focus]["target"])
	_progress[focus] = minf(target, float(_progress.get(focus, 0.0)) + amount)
	training_objective_changed.emit(focus, float(_progress[focus]), target)
	if float(_progress[focus]) >= target:
		_completed[focus] = true
		training_objective_completed.emit(focus)

func _show_hud(focus: String) -> void:
	if not is_instance_valid(_hud_layer):
		_hud_layer = CanvasLayer.new()
		_hud_layer.layer = 260
		get_tree().root.add_child(_hud_layer)
		_hud_label = Label.new()
		_hud_label.position = Vector2(410, 18)
		_hud_label.size = Vector2(460, 54)
		_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hud_label.add_theme_font_size_override("font_size", 16)
		_hud_layer.add_child(_hud_label)
	_hud_layer.visible = true
	var spec: Dictionary = TRAINING_TARGETS[focus]
	var progress := float(_progress.get(focus, 0.0))
	var target := float(spec["target"])
	var suffix := "s" if String(spec["metric"]) == "seconds" else "m" if String(spec["metric"]) == "distance" else ""
	_hud_label.text = "%s  •  %.0f/%.0f%s%s" % [String(spec["label"]), progress, target, suffix, "  •  CONCLUÍDO" if bool(_completed.get(focus, false)) else ""]

func _hide_hud() -> void:
	if is_instance_valid(_hud_layer):
		_hud_layer.visible = false

func objective_snapshot() -> Dictionary:
	var focus := _training_focus()
	var spec: Dictionary = TRAINING_TARGETS.get(focus, TRAINING_TARGETS["free"])
	return {"focus":focus,"label":spec["label"],"progress":float(_progress.get(focus,0.0)),"target":float(spec["target"]),"completed":bool(_completed.get(focus,false))}

func reset_objectives() -> void:
	_progress = {"free":0.0,"tai":0.0,"ji":0.0,"fu":0.0,"ghost":0.0}
	_completed.clear()
	_last_positions.clear()
