class_name MatchTelemetry
extends RefCounted

const TELEMETRY_DIR := "user://telemetry"
const TELEMETRY_SCHEMA := "tehkne/taijifu-match-telemetry/v4"
const TELEMETRY_VERSION := 4
const CANONICAL_FIRST_PLAYABLE_ARENA := "Mountain Dojo Night"
const LEGACY_FIRST_PLAYABLE_ARENAS := [
	"Ruínas do Caminho Triplo",
	"RUÍNAS DO CAMINHO TRIPLO",
]

var _session_id := ""
var _round_index := 0
var _session_started_unix := 0
var _round_started_msec := 0
var _players: Dictionary = {}
var _round_events: Array[Dictionary] = []
var _rounds: Array[Dictionary] = []
var _last_round: Dictionary = {}
var _session_metadata: Dictionary = {}
var _round_metadata: Dictionary = {}
var _last_written_path := ""

func begin_session(metadata: Dictionary = {}) -> void:
	_session_started_unix = int(Time.get_unix_time_from_system())
	_session_id = "%d-%d" % [_session_started_unix, randi_range(1000, 9999)]
	_round_index = 0
	_rounds.clear()
	_last_round.clear()
	_session_metadata = metadata.duplicate(true)
	_attach_first_playable_identity()
	_last_written_path = ""
	begin_round()

func begin_round(metadata: Dictionary = {}) -> void:
	_round_index += 1
	_round_started_msec = Time.get_ticks_msec()
	_players = {
		"p1": _new_player_metrics(),
		"p2": _new_player_metrics()
	}
	_round_events.clear()
	_round_metadata = metadata.duplicate(true)

func set_session_metadata(metadata: Dictionary, overwrite := true) -> void:
	_session_metadata.merge(metadata, overwrite)

func set_round_metadata(metadata: Dictionary, overwrite := true) -> void:
	_round_metadata.merge(metadata, overwrite)

func record_route(profile_id: StringName, route_id: StringName, delta: float) -> void:
	var metrics := _player_metrics(profile_id)
	var route_seconds: Dictionary = metrics["route_seconds"]
	route_seconds[String(route_id)] = float(route_seconds.get(String(route_id), 0.0)) + delta
	metrics["route_seconds"] = route_seconds
	_players[String(profile_id)] = metrics

func record_event(
	profile_id: StringName,
	event_id: StringName,
	value_id: StringName = &"",
	amount: float = 1.0
) -> void:
	var metrics := _player_metrics(profile_id)
	var counters: Dictionary = metrics["counters"]
	var key := String(event_id)
	if value_id != &"":
		key = "%s:%s" % [key, String(value_id)]
	counters[key] = float(counters.get(key, 0.0)) + amount
	metrics["counters"] = counters
	_players[String(profile_id)] = metrics

	_round_events.append({
		"at_msec": Time.get_ticks_msec() - _round_started_msec,
		"profile_id": String(profile_id),
		"event_id": String(event_id),
		"value_id": String(value_id),
		"amount": amount
	})

func record_combat_metric(profile_id: StringName, metric_id: StringName, amount: float = 1.0) -> void:
	var metrics := _player_metrics(profile_id)
	var combat: Dictionary = metrics["combat"]
	var key := String(metric_id)
	combat[key] = float(combat.get(key, 0.0)) + amount
	metrics["combat"] = combat
	_players[String(profile_id)] = metrics

func record_combat_peak(profile_id: StringName, metric_id: StringName, value: float) -> void:
	var metrics := _player_metrics(profile_id)
	var combat: Dictionary = metrics["combat"]
	var key := String(metric_id)
	combat[key] = maxf(float(combat.get(key, 0.0)), value)
	metrics["combat"] = combat
	_players[String(profile_id)] = metrics

# Compatibilidade explícita para runtimes do First Playable que usam a nomenclatura
# anterior. Mantém um único comportamento: máximo observado, nunca soma.
func record_combat_max(profile_id: StringName, metric_id: StringName, value: float) -> void:
	record_combat_peak(profile_id, metric_id, value)

func finish_round(
	winner_profile_id: StringName = &"",
	result_metadata: Dictionary = {}
) -> String:
	var metadata := _round_metadata.duplicate(true)
	metadata.merge(result_metadata, true)
	_normalize_first_playable_metadata(metadata)
	_apply_pilot_round_integrity(metadata)
	var round_data := {
		"round_index": _round_index,
		"duration_msec": Time.get_ticks_msec() - _round_started_msec,
		"winner_profile_id": String(winner_profile_id),
		"metadata": metadata,
		"players": _players.duplicate(true),
		"events": _round_events.duplicate(true)
	}
	_last_round = round_data.duplicate(true)
	_rounds.append(round_data)
	return _write_session()

func annotate_last_round(annotation: Dictionary) -> String:
	if _rounds.is_empty():
		return ""
	var last_index := _rounds.size() - 1
	var round_data: Dictionary = _rounds[last_index]
	var metadata: Dictionary = round_data.get("metadata", {}).duplicate(true)
	metadata.merge(annotation, true)
	round_data["metadata"] = metadata
	_rounds[last_index] = round_data
	_last_round = round_data.duplicate(true)
	return _write_session()

func last_round_snapshot() -> Dictionary:
	return _last_round.duplicate(true)

func current_round_snapshot() -> Dictionary:
	var metadata := _round_metadata.duplicate(true)
	_normalize_first_playable_metadata(metadata)
	return {
		"round_index": _round_index,
		"duration_msec": Time.get_ticks_msec() - _round_started_msec,
		"winner_profile_id": "",
		"metadata": metadata,
		"players": _players.duplicate(true),
		"events": _round_events.duplicate(true)
	}

func session_snapshot() -> Dictionary:
	return {
		"schema": TELEMETRY_SCHEMA,
		"version": TELEMETRY_VERSION,
		"session_id": _session_id,
		"started_unix": _session_started_unix,
		"updated_unix": int(Time.get_unix_time_from_system()),
		"metadata": _session_metadata.duplicate(true),
		"rounds": _rounds.duplicate(true)
	}

func session_json() -> String:
	return JSON.stringify(session_snapshot(), "\t")

func session_id() -> String:
	return _session_id

func last_written_path() -> String:
	return _last_written_path

func current_route_summary(profile_id: StringName) -> String:
	var metrics := _player_metrics(profile_id)
	var routes: Dictionary = metrics["route_seconds"]
	var best_route := "fu"
	var best_seconds := -1.0
	for route_key in routes:
		var seconds := float(routes[route_key])
		if seconds > best_seconds:
			best_seconds = seconds
			best_route = String(route_key)
	return "%s %.1fs" % [best_route.to_upper(), maxf(0.0, best_seconds)]

func _player_metrics(profile_id: StringName) -> Dictionary:
	var key := String(profile_id)
	if not _players.has(key):
		_players[key] = _new_player_metrics()
	return _players[key]

func _new_player_metrics() -> Dictionary:
	return {
		"route_seconds": {"tai": 0.0, "ji": 0.0, "fu": 0.0},
		"counters": {},
		"combat": {
			"techniques_started": 0.0,
			"confirmed_hits": 0.0,
			"damage_dealt": 0.0,
			"posture_damage_dealt": 0.0,
			"posture_breaks": 0.0,
			"max_combo": 0.0,
			"max_flow": 0.0,
			"code_steps": 0.0,
			"climax_started": 0.0,
			"climax_resolved": 0.0
		}
	}

func _attach_first_playable_identity() -> void:
	if String(_session_metadata.get("experience", "")) != "first_playable":
		return
	var participant_code := FirstPlayableSession.normalize_participant_code(
		FirstPlayableSession.participant_code
	)
	if participant_code == "":
		return
	_session_metadata["participant_code"] = participant_code
	_session_metadata["pilot_id"] = FirstPlayableSession.PILOT_ID

func _normalize_first_playable_metadata(metadata: Dictionary) -> void:
	if String(_session_metadata.get("experience", "")) != "first_playable":
		return
	var arena_label := String(metadata.get("arena", ""))
	if arena_label == "" or arena_label in LEGACY_FIRST_PLAYABLE_ARENAS:
		metadata["arena"] = CANONICAL_FIRST_PLAYABLE_ARENA

func _apply_pilot_round_integrity(metadata: Dictionary) -> void:
	if String(_session_metadata.get("experience", "")) != "first_playable":
		return
	if not FirstPlayableSession.has_valid_participant_code():
		metadata["pilot_sequence_valid"] = false
		metadata["pilot_sequence_error"] = "missing_or_unassigned_participant_code"
		return
	var expected_difficulty := FirstPlayableSession.pilot_required_difficulty()
	var actual_difficulty := StringName(String(metadata.get("difficulty_id", "")))
	var sequence_valid := actual_difficulty == expected_difficulty
	var completed_result := String(metadata.get("result_reason", "")) != "abandoned"
	metadata["pilot_id"] = FirstPlayableSession.PILOT_ID
	metadata["participant_code"] = FirstPlayableSession.participant_code
	metadata["pilot_round_number"] = FirstPlayableSession.pilot_round_number()
	metadata["pilot_expected_matches"] = FirstPlayableSession.pilot_expected_matches()
	metadata["pilot_expected_difficulty"] = String(expected_difficulty)
	metadata["pilot_sequence_valid"] = sequence_valid
	metadata["pilot_completed_matches_before_round"] = FirstPlayableSession.pilot_completed_matches
	if not sequence_valid:
		metadata["pilot_sequence_error"] = "difficulty_out_of_sequence"
	elif completed_result:
		FirstPlayableSession.mark_pilot_round_complete(actual_difficulty)
	metadata["pilot_completed_matches_after_round"] = FirstPlayableSession.pilot_completed_matches
	metadata["pilot_complete"] = FirstPlayableSession.pilot_complete()
	if not FirstPlayableSession.pilot_complete():
		metadata["pilot_next_difficulty"] = String(FirstPlayableSession.pilot_required_difficulty())

func _participant_filename_prefix() -> String:
	var participant_code := FirstPlayableSession.normalize_participant_code(
		String(_session_metadata.get("participant_code", ""))
	)
	if participant_code == "":
		return ""
	return "%s__" % participant_code

func _write_session() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TELEMETRY_DIR))
	var filename := "%staijifu_%s.json" % [_participant_filename_prefix(), _session_id]
	var path := "%s/%s" % [TELEMETRY_DIR, filename]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(session_json())
	file.close()
	_last_written_path = path
	return path

# Tehkné Solutions
