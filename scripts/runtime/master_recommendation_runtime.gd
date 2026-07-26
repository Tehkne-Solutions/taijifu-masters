class_name MasterRecommendationRuntime
extends Node

@onready var intelligence_runtime: PrototypeIntelligenceRuntime = get_node("../PrototypeIntelligenceRuntime")
@onready var weapon_mastery_runtime: WeaponMasteryRuntime = get_node("../WeaponMasteryRuntime")
@onready var master_training_runtime: MasterTrainingRuntime = get_node("../MasterTrainingRuntime")
@onready var hud: CanvasLayer = get_node("../HUD")

var _observation := MartialObservationLedger.new()
var _last_report: Dictionary = {}
var _recommendations: Dictionary = {"p1": "SEM DADOS", "p2": "SEM DADOS"}
var _panel: ColorRect
var _title_label: Label
var _body_label: Label
var _visible := false

func _ready() -> void:
	_register_key_action(&"recommendation_toggle", KEY_F6)
	_create_panel()
	if not intelligence_runtime.round_report_ready.is_connected(_on_round_report_ready):
		intelligence_runtime.round_report_ready.connect(_on_round_report_ready)
	_rebuild_recommendations()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"recommendation_toggle"):
		_visible = not _visible
		_panel.visible = _visible
		_update_panel()

func _on_round_report_ready(report: Dictionary, _saved_path: String) -> void:
	_last_report = report.duplicate(true)
	_observation = MartialObservationLedger.new()
	_rebuild_recommendations()
	_visible = true
	_panel.visible = true
	_update_panel()

func recommendation_for(profile_id: String) -> String:
	return String(_recommendations.get(profile_id, "SEM RECOMENDAÇÃO"))

func _rebuild_recommendations() -> void:
	for profile_id in ["p1", "p2"]:
		_recommendations[profile_id] = _build_recommendation(profile_id)
	_update_panel()

func _build_recommendation(profile_id: String) -> String:
	var training_ledger := master_training_runtime.ledger
	var selected := training_ledger.selected_variant(profile_id)
	var unlocked := training_ledger.unlocked_variants(profile_id)
	if selected == &"" and not unlocked.is_empty():
		var first_variant := StringName(unlocked[0])
		return "PREPARAÇÃO: equipe %s com Z/X ou Num8/Num9. %s" % [
			MasterTrainingCatalog.variant_label(first_variant),
			MasterTrainingCatalog.variant_summary(first_variant)
		]

	var player_metrics := _player_metrics(profile_id)
	var counters: Dictionary = player_metrics.get("counters", {})
	var routes: Dictionary = player_metrics.get("route_seconds", {})
	var defense_responses := (
		float(counters.get("technique_experienced:blocked", 0.0))
		+ float(counters.get("technique_experienced:parried", 0.0))
		+ float(counters.get("technique_experienced:evaded", 0.0))
	)
	var weakest_route := _weakest_route(routes)

	var eligible := _eligible_master(profile_id, weakest_route, defense_responses)
	if not eligible.is_empty():
		return "%s: %s. Abra T, selecione o mestre e inicie a prova com I." % [
			String(eligible.get("name", "MESTRE")),
			String(eligible.get("recommendation_reason", eligible.get("description", "Prova disponível")))
		]

	var observation_gap := _largest_observation_gap(profile_id)
	if not observation_gap.is_empty():
		var technique := TechniqueCatalog.get_technique(StringName(observation_gap.get("technique_id", &"")))
		return "DOJO: configure o boneco em APARO ou ESQUIVA e treine contra %s; a técnica foi vista %d vezes e ainda não foi defendida." % [
			technique.display_name.to_upper(),
			int(observation_gap.get("exposure", 0))
		]

	var closest := _closest_master(profile_id)
	if not closest.is_empty():
		return "DOMÍNIO: use %s até %s para liberar %s (%d XP atuais)." % [
			WeaponKitCatalog.label_for(StringName(closest.get("weapon_id", &"unarmed"))),
			String(closest.get("required_stage", &"trained")).to_upper(),
			String(closest.get("name", "MESTRE")),
			roundi(float(closest.get("xp", 0.0)))
		]

	if selected != &"":
		return "VARIANTE ATIVA: %s. Use o Dojo F8 para comparar a técnica-base e a variação em defesa, alcance e recuperação." % MasterTrainingCatalog.variant_label(selected)
	return "TREINO LIVRE: alterne Tai, Ji e Fu e gere uma rodada completa para obter uma recomendação mais precisa."

func _eligible_master(profile_id: String, weakest_route: StringName, defense_responses: float) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -999.0
	for master_id in MasterTrainingCatalog.available_masters():
		var master := MasterTrainingCatalog.master(master_id)
		var variant_id := StringName(master.get("variant_id", &""))
		if master_training_runtime.ledger.is_unlocked(profile_id, variant_id):
			continue
		var weapon_id := _best_eligible_weapon(profile_id, master)
		if weapon_id == &"":
			continue
		var path := StringName(String(master.get("path", "fu")).to_lower())
		var score := 1.0
		if path == weakest_route:
			score += 2.0
		if path == &"ji" and defense_responses < 2.0:
			score += 2.5
		if path == &"fu" and weakest_route == &"fu":
			score += 1.0
		if score > best_score:
			best_score = score
			best = master
			best["weapon_id"] = weapon_id
			best["recommendation_reason"] = _master_reason(path, weakest_route, defense_responses)
	return best

func _best_eligible_weapon(profile_id: String, master: Dictionary) -> StringName:
	var required_stage := StringName(master.get("required_stage", &"trained"))
	var best_weapon := &""
	var best_xp := -1.0
	var weapon_ids: Array = master.get("weapon_ids", [])
	for weapon_value in weapon_ids:
		var weapon_id := StringName(weapon_value)
		var progress := weapon_mastery_runtime.ledger.progress_for(profile_id, weapon_id)
		var stage_id := StringName(progress.get("stage_id", &"unfamiliar"))
		if not MasterTrainingCatalog.stage_meets(stage_id, required_stage):
			continue
		var xp := float(progress.get("xp", 0.0))
		if xp > best_xp:
			best_xp = xp
			best_weapon = weapon_id
	return best_weapon

func _closest_master(profile_id: String) -> Dictionary:
	var best: Dictionary = {}
	var best_xp := -1.0
	for master_id in MasterTrainingCatalog.available_masters():
		var master := MasterTrainingCatalog.master(master_id)
		var variant_id := StringName(master.get("variant_id", &""))
		if master_training_runtime.ledger.is_unlocked(profile_id, variant_id):
			continue
		var weapon_ids: Array = master.get("weapon_ids", [])
		for weapon_value in weapon_ids:
			var weapon_id := StringName(weapon_value)
			var progress := weapon_mastery_runtime.ledger.progress_for(profile_id, weapon_id)
			var xp := float(progress.get("xp", 0.0))
			if xp > best_xp:
				best_xp = xp
				best = master.duplicate(true)
				best["weapon_id"] = weapon_id
				best["xp"] = xp
	return best

func _largest_observation_gap(profile_id: String) -> Dictionary:
	var snapshot := _observation.profile_snapshot(StringName(profile_id))
	var best: Dictionary = {}
	var best_exposure := 0
	for technique_key in snapshot.keys():
		var entry: Dictionary = snapshot[technique_key]
		var events: Dictionary = entry.get("events", {})
		var exposure := int(events.get("seen", 0)) + int(events.get("recognized", 0)) + int(events.get("understood", 0))
		var defended := int(events.get("defended", 0))
		if defended == 0 and exposure >= 3 and exposure > best_exposure:
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
	var lowest := INF
	for route_id in [&"tai", &"ji", &"fu"]:
		var value := float(routes.get(String(route_id), 0.0))
		if value < lowest:
			lowest = value
			selected = route_id
	return selected

func _master_reason(path: StringName, weakest_route: StringName, defense_responses: float) -> String:
	if path == &"ji" and defense_responses < 2.0:
		return "suas respostas defensivas estão baixas; a Fundação Invertida treina aparo, centro e pressão"
	if path == weakest_route:
		return "o caminho %s foi o menos utilizado na última rodada" % String(path).to_upper()
	return "seu domínio já permite iniciar esta prova especializada"

func _create_panel() -> void:
	_panel = ColorRect.new()
	_panel.offset_left = 170.0
	_panel.offset_top = 205.0
	_panel.offset_right = 1110.0
	_panel.offset_bottom = 555.0
	_panel.color = Color(0.028, 0.035, 0.055, 0.97)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	hud.add_child(_panel)

	_title_label = Label.new()
	_title_label.offset_left = 30.0
	_title_label.offset_top = 20.0
	_title_label.offset_right = 910.0
	_title_label.offset_bottom = 68.0
	_title_label.text = "RECOMENDAÇÕES DOS MESTRES"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.46))
	_panel.add_child(_title_label)

	_body_label = Label.new()
	_body_label.offset_left = 48.0
	_body_label.offset_top = 82.0
	_body_label.offset_right = 892.0
	_body_label.offset_bottom = 318.0
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 17)
	_body_label.add_theme_color_override("font_color", Color(0.86, 0.91, 0.98))
	_panel.add_child(_body_label)

	var footer := Label.new()
	footer.offset_left = 30.0
	footer.offset_top = 310.0
	footer.offset_right = 910.0
	footer.offset_bottom = 342.0
	footer.text = "F6 FECHA • F8 ABRE DOJO • T ABRE MESTRES"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.62, 0.82, 1.0))
	_panel.add_child(footer)

func _update_panel() -> void:
	if not is_instance_valid(_body_label):
		return
	_body_label.text = "P1\n%s\n\nP2\n%s" % [
		recommendation_for("p1"),
		recommendation_for("p2")
	]

func _register_key_action(action_id: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	for existing in InputMap.action_get_events(action_id):
		if existing is InputEventKey and existing.physical_keycode == physical_keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_id, event)
