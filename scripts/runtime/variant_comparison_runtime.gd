class_name VariantComparisonRuntime
extends Node

const SAVE_PATH := "user://variant_comparison.json"
const CONNECT_INTERVAL := 0.35

@onready var dojo_runtime: DojoTrainingRuntime = get_node("../DojoTrainingRuntime")
@onready var hud: CanvasLayer = get_node("../HUD")

var _stats: Dictionary = {}
var _connect_timer := 0.0
var _was_dojo_active := false
var _dirty := false
var _panel_layer: CanvasLayer
var _panel: ColorRect
var _report: RichTextLabel

func _ready() -> void:
	_register_key_action(&"toggle_variant_comparison", KEY_M)
	_register_key_action(&"clear_variant_comparison", KEY_K)
	_create_panel()
	_load_stats()
	_connect_fighters()

func _process(delta: float) -> void:
	_connect_timer -= delta
	if _connect_timer <= 0.0:
		_connect_timer = CONNECT_INTERVAL
		_connect_fighters()

	if Input.is_action_just_pressed(&"toggle_variant_comparison"):
		_panel.visible = not _panel.visible
		if _panel.visible:
			_refresh_panel()
			_save_stats()
	if Input.is_action_just_pressed(&"clear_variant_comparison"):
		_clear_stats()

	if _was_dojo_active and not dojo_runtime.active and _dirty:
		_save_stats()
	_was_dojo_active = dojo_runtime.active

func _connect_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		if node.has_signal("technique_executed"):
			var technique_callback := Callable(self, "_on_technique_executed")
			if not node.is_connected("technique_executed", technique_callback):
				node.connect("technique_executed", technique_callback)
		if node.has_signal("impact_resolved"):
			var impact_callback := Callable(self, "_on_impact_resolved")
			if not node.is_connected("impact_resolved", impact_callback):
				node.connect("impact_resolved", impact_callback)

func _on_technique_executed(
	fighter: MasteredWeaponFighterController,
	technique: TechniqueData,
	variant_id: StringName
) -> void:
	if not dojo_runtime.active or fighter.player_index != 1 or not is_instance_valid(technique):
		return
	var entry := _entry_for(technique, variant_id)
	entry["executions"] = int(entry["executions"]) + 1
	entry["stamina_total"] = float(entry["stamina_total"]) + technique.stamina_cost
	entry["startup_total"] = float(entry["startup_total"]) + technique.startup_seconds()
	entry["active_total"] = float(entry["active_total"]) + technique.active_seconds()
	entry["recovery_total"] = float(entry["recovery_total"]) + technique.recovery_seconds()
	_stats[_entry_key(technique.technique_id, variant_id)] = entry
	_dirty = true
	if _panel.visible:
		_refresh_panel()

func _on_impact_resolved(
	target: MasteredWeaponFighterController,
	attacker: FighterController,
	technique: TechniqueData,
	result_id: StringName,
	damage_applied: float,
	posture_applied: float,
	intensity: float,
	world_position: Vector2
) -> void:
	if not dojo_runtime.active or not is_instance_valid(attacker) or attacker.player_index != 1:
		return
	if not is_instance_valid(technique):
		return

	var variant_id := _active_variant_for(attacker, technique.technique_id)
	var entry := _entry_for(technique, variant_id)
	entry["contacts"] = int(entry["contacts"]) + 1
	entry["damage_total"] = float(entry["damage_total"]) + damage_applied
	entry["posture_total"] = float(entry["posture_total"]) + posture_applied
	match result_id:
		&"hit":
			entry["hits"] = int(entry["hits"]) + 1
		&"posture_break":
			entry["hits"] = int(entry["hits"]) + 1
			entry["posture_breaks"] = int(entry["posture_breaks"]) + 1
		&"blocked":
			entry["blocked"] = int(entry["blocked"]) + 1
		&"parried":
			entry["parried"] = int(entry["parried"]) + 1
		&"evaded":
			entry["evaded"] = int(entry["evaded"]) + 1
	_stats[_entry_key(technique.technique_id, variant_id)] = entry
	_dirty = true
	if _panel.visible:
		_refresh_panel()

func _entry_for(technique: TechniqueData, variant_id: StringName) -> Dictionary:
	var key := _entry_key(technique.technique_id, variant_id)
	if _stats.has(key):
		return (_stats[key] as Dictionary).duplicate(true)
	return {
		"technique_id": String(technique.technique_id),
		"technique_label": technique.display_name,
		"variant_id": String(variant_id),
		"variant_label": MasterTrainingCatalog.variant_label(variant_id),
		"executions": 0,
		"contacts": 0,
		"hits": 0,
		"blocked": 0,
		"parried": 0,
		"evaded": 0,
		"posture_breaks": 0,
		"damage_total": 0.0,
		"posture_total": 0.0,
		"stamina_total": 0.0,
		"startup_total": 0.0,
		"active_total": 0.0,
		"recovery_total": 0.0
	}

func _active_variant_for(attacker: FighterController, technique_id: StringName) -> StringName:
	if not (attacker is WeaponKitFighterController):
		return &""
	var weapon_fighter := attacker as WeaponKitFighterController
	var selected := weapon_fighter.selected_training_variant()
	if selected == &"":
		return &""
	if weapon_fighter.unlocked_variant_for(technique_id) != selected:
		return &""
	return selected

func _entry_key(technique_id: StringName, variant_id: StringName) -> String:
	var mode := String(variant_id)
	if mode == "":
		mode = "base"
	return "%s|%s" % [String(technique_id), mode]

func _create_panel() -> void:
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 42
	add_child(_panel_layer)

	_panel = ColorRect.new()
	_panel.offset_left = 150.0
	_panel.offset_top = 78.0
	_panel.offset_right = 1130.0
	_panel.offset_bottom = 638.0
	_panel.color = Color(0.018, 0.023, 0.04, 0.96)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	_panel_layer.add_child(_panel)

	_report = RichTextLabel.new()
	_report.offset_left = 26.0
	_report.offset_top = 20.0
	_report.offset_right = 954.0
	_report.offset_bottom = 536.0
	_report.bbcode_enabled = true
	_report.fit_content = false
	_report.scroll_active = true
	_report.add_theme_font_size_override("normal_font_size", 15)
	_report.add_theme_font_size_override("bold_font_size", 17)
	_panel.add_child(_report)

func _refresh_panel() -> void:
	if not is_instance_valid(_report):
		return
	var lines: Array[String] = []
	lines.append("[center][font_size=24][b]COMPARAÇÃO TÉCNICA DO DOJO[/b][/font_size][/center]")
	lines.append("[center]M fecha • K limpa • dados acumulados somente no Dojo[/center]\n")
	if _stats.is_empty():
		lines.append("Nenhuma amostra. Execute uma técnica-base e depois equipe sua variante na preparação.")
		_report.text = "\n".join(lines)
		return

	var technique_ids: Array[String] = []
	for value in _stats.values():
		if not (value is Dictionary):
			continue
		var technique_id := String((value as Dictionary).get("technique_id", ""))
		if technique_id != "" and technique_id not in technique_ids:
			technique_ids.append(technique_id)
	technique_ids.sort()

	for technique_id in technique_ids:
		var entries := _entries_for_technique(technique_id)
		if entries.is_empty():
			continue
		var title := String(entries[0].get("technique_label", technique_id))
		lines.append("[color=#f2d879][font_size=19][b]%s[/b][/font_size][/color]" % title)
		var base_entry: Dictionary = {}
		var variant_entries: Array[Dictionary] = []
		for entry in entries:
			if String(entry.get("variant_id", "")) == "":
				base_entry = entry
			else:
				variant_entries.append(entry)
		if not base_entry.is_empty():
			lines.append(_entry_line("BASE", base_entry))
		for variant_entry in variant_entries:
			var label := String(variant_entry.get("variant_label", "VARIANTE"))
			lines.append(_entry_line(label, variant_entry))
			if not base_entry.is_empty():
				lines.append(_delta_line(base_entry, variant_entry))
		lines.append("")
	_report.text = "\n".join(lines)

func _entries_for_technique(technique_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in _stats.values():
		if value is Dictionary and String((value as Dictionary).get("technique_id", "")) == technique_id:
			result.append((value as Dictionary).duplicate(true))
	result.sort_custom(_sort_entries)
	return result

func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("variant_id", "")) < String(b.get("variant_id", ""))

func _entry_line(label: String, entry: Dictionary) -> String:
	var executions := maxi(1, int(entry.get("executions", 0)))
	var contacts := int(entry.get("contacts", 0))
	var contact_rate := float(contacts) / float(executions) * 100.0
	var avg_damage := _safe_average(float(entry.get("damage_total", 0.0)), contacts)
	var avg_posture := _safe_average(float(entry.get("posture_total", 0.0)), contacts)
	var avg_cost := _safe_average(float(entry.get("stamina_total", 0.0)), executions)
	var startup_ms := _safe_average(float(entry.get("startup_total", 0.0)), executions) * 1000.0
	var total_ms := (
		_safe_average(float(entry.get("startup_total", 0.0)), executions)
		+ _safe_average(float(entry.get("active_total", 0.0)), executions)
		+ _safe_average(float(entry.get("recovery_total", 0.0)), executions)
	) * 1000.0
	return "[b]%s[/b] — execuções %d • contato %.0f%% • dano/contato %.1f • postura/contato %.1f • custo %.1f • startup %.0fms • ciclo %.0fms • bloqueios %d • aparos %d • esquivas %d" % [
		label,
		int(entry.get("executions", 0)),
		contact_rate,
		avg_damage,
		avg_posture,
		avg_cost,
		startup_ms,
		total_ms,
		int(entry.get("blocked", 0)),
		int(entry.get("parried", 0)),
		int(entry.get("evaded", 0))
	]

func _delta_line(base_entry: Dictionary, variant_entry: Dictionary) -> String:
	var base_exec := maxi(1, int(base_entry.get("executions", 0)))
	var variant_exec := maxi(1, int(variant_entry.get("executions", 0)))
	var base_contacts := maxi(1, int(base_entry.get("contacts", 0)))
	var variant_contacts := maxi(1, int(variant_entry.get("contacts", 0)))
	var cost_delta := _safe_average(float(variant_entry.get("stamina_total", 0.0)), variant_exec) - _safe_average(float(base_entry.get("stamina_total", 0.0)), base_exec)
	var startup_delta := (_safe_average(float(variant_entry.get("startup_total", 0.0)), variant_exec) - _safe_average(float(base_entry.get("startup_total", 0.0)), base_exec)) * 1000.0
	var damage_delta := _safe_average(float(variant_entry.get("damage_total", 0.0)), variant_contacts) - _safe_average(float(base_entry.get("damage_total", 0.0)), base_contacts)
	var posture_delta := _safe_average(float(variant_entry.get("posture_total", 0.0)), variant_contacts) - _safe_average(float(base_entry.get("posture_total", 0.0)), base_contacts)
	var contact_delta := float(variant_entry.get("contacts", 0)) / float(variant_exec) * 100.0 - float(base_entry.get("contacts", 0)) / float(base_exec) * 100.0
	return "[color=#9eb8d7]Δ variante − base: custo %+.1f • startup %+.0fms • dano/contato %+.1f • postura/contato %+.1f • contato %+.0f pp[/color]" % [
		cost_delta,
		startup_delta,
		damage_delta,
		posture_delta,
		contact_delta
	]

func _safe_average(total: float, count: int) -> float:
	if count <= 0:
		return 0.0
	return total / float(count)

func _clear_stats() -> void:
	_stats.clear()
	_dirty = true
	_save_stats()
	_refresh_panel()

func _save_stats() -> void:
	if not _dirty and FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"version": 1, "stats": _stats}, "\t"))
	_dirty = false

func _load_stats() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed := JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("stats", {}) is Dictionary:
		_stats = (parsed.get("stats", {}) as Dictionary).duplicate(true)

func _register_key_action(action_id: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == physical_keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_id, event)

func _exit_tree() -> void:
	_save_stats()
