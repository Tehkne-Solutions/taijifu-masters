class_name PrototypeIntelligenceRuntime
extends Node

@onready var arena: TriplePathArena = get_node("../Arena")
@onready var knowledge_label: Label = get_node("../HUD/KnowledgeInfo")

var _ledger := MartialObservationLedger.new()
var _telemetry := MatchTelemetry.new()
var _connected_fighters: Dictionary = {}
var _flash_text := ""
var _flash_timer := 0.0
var _ui_timer := 0.0
var _round_closed := false

func _ready() -> void:
	_telemetry.begin_session()

func _process(delta: float) -> void:
	_discover_fighters()
	_track_routes(delta)
	_flash_timer = maxf(0.0, _flash_timer - delta)
	_ui_timer -= delta
	if _ui_timer <= 0.0:
		_ui_timer = 0.16
		_update_knowledge_hud()

func _discover_fighters() -> void:
	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is FighterController):
			continue
		var fighter := node as FighterController
		var instance_key := fighter.get_instance_id()
		if _connected_fighters.has(instance_key):
			continue
		_connected_fighters[instance_key] = fighter
		_connect_fighter(fighter)

func _connect_fighter(fighter: FighterController) -> void:
	if fighter.has_signal("technique_started"):
		fighter.connect("technique_started", Callable(self, "_on_technique_started"))
	if fighter.has_signal("technique_experienced"):
		fighter.connect("technique_experienced", Callable(self, "_on_technique_experienced"))
	if fighter.has_signal("technique_reproduced"):
		fighter.connect("technique_reproduced", Callable(self, "_on_technique_reproduced"))
	if fighter.has_signal("grab_escape_progress_changed"):
		fighter.connect("grab_escape_progress_changed", Callable(self, "_on_grab_escape_progress"))
	if fighter.has_signal("grab_escaped"):
		fighter.connect("grab_escaped", Callable(self, "_on_grab_escaped"))
	if fighter.has_signal("elemental_interaction"):
		fighter.connect("elemental_interaction", Callable(self, "_on_elemental_interaction"))

	fighter.grab_started.connect(_on_grab_started)
	fighter.grab_finished.connect(_on_grab_finished)
	fighter.defeated.connect(_on_fighter_defeated)

func _track_routes(delta: float) -> void:
	for fighter_variant in _connected_fighters.values():
		if not is_instance_valid(fighter_variant):
			continue
		var fighter := fighter_variant as FighterController
		_telemetry.record_route(_profile_id(fighter), _route_for_position(fighter.global_position), delta)

func _route_for_position(position: Vector2) -> StringName:
	if position.y <= 430.0:
		return &"tai"
	if position.y >= 610.0:
		return &"ji"
	return &"fu"

func _on_technique_started(fighter: FighterController, technique_id: StringName) -> void:
	_telemetry.record_event(_profile_id(fighter), &"technique_started", technique_id)
	var technique := TechniqueCatalog.get_technique(technique_id)
	if technique.has_element():
		_telemetry.record_event(
			_profile_id(fighter),
			&"element_cast",
			StringName(technique.element_id)
		)

	for observer_variant in _connected_fighters.values():
		if not is_instance_valid(observer_variant):
			continue
		var observer := observer_variant as FighterController
		if observer == fighter or observer.global_position.distance_to(fighter.global_position) > 760.0:
			continue
		_record_observation(observer, technique_id, &"seen")

func _on_technique_experienced(
	fighter: FighterController,
	_opponent: FighterController,
	technique_id: StringName,
	outcome_id: StringName
) -> void:
	var event_id := &"recognized"
	if outcome_id == &"blocked" or outcome_id == &"parried":
		event_id = &"defended"
	elif outcome_id == &"evaded":
		event_id = &"understood"
	_record_observation(fighter, technique_id, event_id)
	_telemetry.record_event(_profile_id(fighter), &"technique_experienced", outcome_id)

func _on_technique_reproduced(fighter: FighterController, technique_id: StringName) -> void:
	var profile_id := _profile_id(fighter)
	var previous_stage := _ledger.stage_for(profile_id, technique_id)
	_record_observation(fighter, technique_id, &"reproduced")
	if previous_stage in [&"defended", &"reproduced", &"adapted", &"mastered"]:
		_record_observation(fighter, technique_id, &"adapted")
	_telemetry.record_event(profile_id, &"technique_reproduced", technique_id)

func _record_observation(
	fighter: FighterController,
	technique_id: StringName,
	event_id: StringName
) -> void:
	var update := _ledger.record_event(_profile_id(fighter), technique_id, event_id)
	if update.is_empty() or not bool(update.get("advanced", false)):
		return
	var technique := TechniqueCatalog.get_technique(technique_id)
	_flash_text = "%s • %s: %s" % [
		String(_profile_id(fighter)).to_upper(),
		technique.display_name.to_upper(),
		update.get("stage_label", "VISTA")
	]
	_flash_timer = 1.5

func _on_grab_started(attacker: FighterController, target: FighterController) -> void:
	_telemetry.record_event(_profile_id(attacker), &"grab_started")
	_telemetry.record_event(_profile_id(target), &"grab_received")

func _on_grab_finished(attacker: FighterController, target: FighterController) -> void:
	_telemetry.record_event(_profile_id(attacker), &"grab_finished")
	_telemetry.record_event(_profile_id(target), &"grab_released")

func _on_grab_escape_progress(
	fighter: FighterController,
	progress: float,
	threshold: float
) -> void:
	_telemetry.record_event(
		_profile_id(fighter),
		&"grab_escape_input",
		&"progress",
		minf(1.0, progress / maxf(1.0, threshold))
	)

func _on_grab_escaped(fighter: FighterController, attacker: FighterController) -> void:
	_telemetry.record_event(_profile_id(fighter), &"grab_escaped")
	_telemetry.record_event(_profile_id(attacker), &"grab_lost")
	_flash_text = "%s • FUGA FU CONCLUÍDA" % String(_profile_id(fighter)).to_upper()
	_flash_timer = 1.15

func _on_elemental_interaction(
	fighter: FighterController,
	interaction_id: StringName,
	element_id: StringName
) -> void:
	_telemetry.record_event(_profile_id(fighter), &"elemental_interaction", interaction_id)
	_telemetry.record_event(_profile_id(fighter), &"element_received", element_id)

func _on_fighter_defeated(defeated_fighter: FighterController) -> void:
	if _round_closed:
		return
	_round_closed = true
	var winner_profile := &""
	for fighter_variant in _connected_fighters.values():
		if is_instance_valid(fighter_variant) and fighter_variant != defeated_fighter:
			winner_profile = _profile_id(fighter_variant as FighterController)
			break
	var saved_path := _telemetry.finish_round(winner_profile)
	_flash_text = "TELEMETRIA SALVA • %s" % saved_path.get_file()
	_flash_timer = 2.0
	await get_tree().create_timer(2.1).timeout
	_telemetry.begin_round()
	_round_closed = false

func _update_knowledge_hud() -> void:
	if _flash_timer > 0.0:
		knowledge_label.text = _flash_text
		return
	knowledge_label.text = "P1 %s • %s    |    P2 %s • %s" % [
		_ledger.latest_summary(&"p1"),
		_telemetry.current_route_summary(&"p1"),
		_ledger.latest_summary(&"p2"),
		_telemetry.current_route_summary(&"p2")
	]

func _profile_id(fighter: FighterController) -> StringName:
	return StringName("p%d" % fighter.player_index)
