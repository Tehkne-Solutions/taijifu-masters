class_name MasterRecommendationRuntime
extends Node

@onready var intelligence_runtime: PrototypeIntelligenceRuntime = get_node("../PrototypeIntelligenceRuntime")
@onready var weapon_mastery_runtime: WeaponMasteryRuntime = get_node("../WeaponMasteryRuntime")
@onready var master_training_runtime: MasterTrainingRuntime = get_node("../MasterTrainingRuntime")
@onready var hud: CanvasLayer = get_node("../HUD")

var _observation := MartialObservationLedger.new()
var _last_report: Dictionary = {}
var _recommendations := {"p1": "SEM DADOS", "p2": "SEM DADOS"}
var _panel: ColorRect
var _body: Label
var _visible := false

func _ready() -> void:
	_register_key_action(&"recommendation_toggle", KEY_F6)
	_create_panel()
	intelligence_runtime.round_report_ready.connect(_on_round_report_ready)
	_rebuild()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"recommendation_toggle"):
		_visible = not _visible
		_panel.visible = _visible
		_update_panel()

func _on_round_report_ready(report: Dictionary, _saved_path: String) -> void:
	_last_report = report.duplicate(true)
	_observation = MartialObservationLedger.new()
	_rebuild()
	_panel.visible = _visible

func recommendation_for(profile_id: String) -> String:
	return String(_recommendations.get(profile_id, "SEM RECOMENDAÇÃO"))

func _rebuild() -> void:
	for profile_id in ["p1", "p2"]:
		_recommendations[profile_id] = _recommend(profile_id)
	_update_panel()

func _recommend(profile_id: String) -> String:
	var training := master_training_runtime.ledger
	var selected := training.selected_variant(profile_id)
	var unlocked := training.unlocked_variants(profile_id)
	if selected == &"" and not unlocked.is_empty():
		var variant := StringName(unlocked[0])
		return "PREPARAÇÃO: equipe %s. %s" % [
			MasterTrainingCatalog.variant_label(variant),
			MasterTrainingCatalog.variant_summary(variant)
		]

	var metrics := _player_metrics(profile_id)
	var counters: Dictionary = metrics.get("counters", {})
	var routes: Dictionary = metrics.get("route_seconds", {})
	var defenses := (
		float(counters.get("technique_experienced:blocked", 0.0))
		+ float(counters.get("technique_experienced:parried", 0.0))
		+ float(counters.get("technique_experienced:evaded", 0.0))
	)
	var weakest_route := _weakest_route(routes)
	var eligible := _eligible_master(profile_id, weakest_route, defenses)
	if not eligible.is_empty():
		return "%s: %s. Abra T e inicie com I." % [
			String(eligible.get("name", "MESTRE")),
			String(eligible.get("reason", "prova disponível"))
		]

	var gap := _observation_gap(profile_id)
	if not gap.is_empty():
		var technique := TechniqueCatalog.get_technique(StringName(gap.get("technique_id", &"")))
		return "DOJO: treine APARO ou ESQUIVA contra %s; vista %d vezes sem defesa." % [
			technique.display_name.to_upper(),
			int(gap.get("exposure", 0))
		]

	var closest := _closest_master(profile_id)
	if not closest.is_empty():
		return "DOMÍNIO: use %s até %s para liberar %s (%d XP)." % [
			WeaponKitCatalog.label_for(StringName(closest.get("weapon_id", &"unarmed"))),
			String(closest.get("required_stage", &"trained")).to_upper(),
			String(closest.get("name", "MESTRE")),
			roundi(float(closest.get("xp", 0.0)))
		]

	if selected != &"":
		return "VARIANTE ATIVA: %s. Compare-a com a técnica-base no Dojo F8." % MasterTrainingCatalog.variant_label(selected)
	return "TREINO LIVRE: alterne Tai, Ji e Fu para gerar uma recomendação mais precisa."

func _eligible_master(profile_id: String, weakest_route: StringName, defenses: float) -> Dictionary:
	var best := {}
	var best_score := -999.0
	for master_id in MasterTrainingCatalog.available_masters():
		var master := MasterTrainingCatalog.master(master_id)
		if master_training_runtime.ledger.is_unlocked(profile_id, StringName(master.get("variant_id", &""))):
			continue
		var weapon_id := _eligible_weapon(profile_id, master)
		if weapon_id == &"":
			continue
		var path := StringName(String(master.get("path", "fu")).to_lower())
		var score := 1.0 + (2.0 if path == weakest_route else 0.0)
		if path == &"ji" and defenses < 2.0:
			score += 2.5
		if score > best_score:
			best_score = score
			best = master.duplicate(true)
			best["weapon_id"] = weapon_id
			best["reason"] = _reason(path, weakest_route, defenses)
	return best

func _eligible_weapon(profile_id: String, master: Dictionary) -> StringName:
	var required := StringName(master.get("required_stage", &"trained"))
	var selected := &""
	var best_xp := -1.0
	for weapon_value in master.get("weapon_ids", []):
		var weapon_id := StringName(weapon_value)
		var progress := weapon_mastery_runtime.ledger.progress_for(profile_id, weapon_id)
		if not MasterTrainingCatalog.stage_meets(StringName(progress.get("stage_id", &"unfamiliar")), required):
			continue
		var xp := float(progress.get("xp", 0.0))
		if xp > best_xp:
			best_xp = xp
			selected = weapon_id
	return selected

func _closest_master(profile_id: String) -> Dictionary:
	var best := {}
	var best_xp := -1.0
	for master_id in MasterTrainingCatalog.available_masters():
		var master := MasterTrainingCatalog.master(master_id)
		if master_training_runtime.ledger.is_unlocked(profile_id, StringName(master.get("variant_id", &""))):
			continue
		for weapon_value in master.get("weapon_ids", []):
			var weapon_id := StringName(weapon_value)
			var xp := float(weapon_mastery_runtime.ledger.progress_for(profile_id, weapon_id).get("xp", 0.0))
			if xp > best_xp:
				best_xp = xp
				best = master.duplicate(true)
				best["weapon_id"] = weapon_id
				best["xp"] = xp
	return best

func _observation_gap(profile_id: String) -> Dictionary:
	var best := {}
	var best_exposure := 0
	for technique_key in _observation.profile_snapshot(StringName(profile_id)).keys():
		var entry: Dictionary = _observation.profile_snapshot(StringName(profile_id))[technique_key]
		var events: Dictionary = entry.get("events", {})
		var exposure := int(events.get("seen", 0)) + int(events.get("recognized", 0)) + int(events.get("understood", 0))
		if int(events.get("defended", 0)) == 0 and exposure >= 3 and exposure > best_exposure:
			best_exposure = exposure
			best = {"technique_id": String(technique_key), "exposure": exposure}
	return best

func _player_metrics(profile_id: String) -> Dictionary:
	var players: Dictionary = _last_report.get("players", {})
	var metrics = players.get(profile_id, {})
	return metrics if metrics is Dictionary else {}

func _weakest_route(routes: Dictionary) -> StringName:
	if routes.is_empty():
		return &"fu"
	var selected := &"fu"
	var lowest := 1.0e20
	for route_id in [&"tai", &"ji", &"fu"]:
		var value := float(routes.get(String(route_id), 0.0))
		if value < lowest:
			lowest = value
			selected = route_id
	return selected

func _reason(path: StringName, weakest_route: StringName, defenses: float) -> String:
	if path == &"ji" and defenses < 2.0:
		return "suas respostas defensivas estão baixas"
	if path == weakest_route:
		return "o caminho %s foi o menos utilizado" % String(path).to_upper()
	return "seu domínio já permite esta prova"

func _create_panel() -> void:
	_panel = ColorRect.new()
	_panel.set_offsets_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-470.0, -175.0)
	_panel.size = Vector2(940.0, 350.0)
	_panel.color = Color(0.028, 0.035, 0.055, 0.97)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	hud.add_child(_panel)

	var title := Label.new()
	title.position = Vector2(30.0, 20.0)
	title.size = Vector2(880.0, 48.0)
	title.text = "RECOMENDAÇÕES DOS MESTRES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.46))
	_panel.add_child(title)

	_body = Label.new()
	_body.position = Vector2(48.0, 82.0)
	_body.size = Vector2(844.0, 215.0)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 17)
	_body.add_theme_color_override("font_color", Color(0.86, 0.91, 0.98))
	_panel.add_child(_body)

	var footer := Label.new()
	footer.position = Vector2(30.0, 310.0)
	footer.size = Vector2(880.0, 28.0)
	footer.text = "F6 FECHA • F8 ABRE DOJO • T ABRE MESTRES"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.62, 0.82, 1.0))
	_panel.add_child(footer)

func _update_panel() -> void:
	if is_instance_valid(_body):
		_body.text = "P1\n%s\n\nP2\n%s" % [recommendation_for("p1"), recommendation_for("p2")]

func _register_key_action(action_id: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == physical_keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_id, event)
