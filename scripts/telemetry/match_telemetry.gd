class_name MatchTelemetry
extends RefCounted

const TELEMETRY_DIR := "user://telemetry"

var _session_id := ""
var _round_index := 0
var _session_started_unix := 0
var _round_started_msec := 0
var _players: Dictionary = {}
var _round_events: Array[Dictionary] = []
var _rounds: Array[Dictionary] = []
var _last_round: Dictionary = {}

func begin_session() -> void:
	_session_started_unix = int(Time.get_unix_time_from_system())
	_session_id = "%d-%d" % [_session_started_unix, randi_range(1000, 9999)]
	_round_index = 0
	_rounds.clear()
	_last_round.clear()
	begin_round()

func begin_round() -> void:
	_round_index += 1
	_round_started_msec = Time.get_ticks_msec()
	_players = {
		"p1": _new_player_metrics(),
		"p2": _new_player_metrics()
	}
	_round_events.clear()

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

func finish_round(winner_profile_id: StringName = &"") -> String:
	var round_data := {
		"round_index": _round_index,
		"duration_msec": Time.get_ticks_msec() - _round_started_msec,
		"winner_profile_id": String(winner_profile_id),
		"players": _players.duplicate(true),
		"events": _round_events.duplicate(true)
	}
	_last_round = round_data.duplicate(true)
	_rounds.append(round_data)
	return _write_session()

func last_round_snapshot() -> Dictionary:
	return _last_round.duplicate(true)

func current_round_snapshot() -> Dictionary:
	return {
		"round_index": _round_index,
		"duration_msec": Time.get_ticks_msec() - _round_started_msec,
		"winner_profile_id": "",
		"players": _players.duplicate(true),
		"events": _round_events.duplicate(true)
	}

func session_snapshot() -> Dictionary:
	return {
		"version": 2,
		"session_id": _session_id,
		"started_unix": _session_started_unix,
		"rounds": _rounds.duplicate(true)
	}

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
		"counters": {}
	}

func _write_session() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TELEMETRY_DIR))
	var path := "%s/taijifu_%s.json" % [TELEMETRY_DIR, _session_id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify({
		"version": 2,
		"session_id": _session_id,
		"started_unix": _session_started_unix,
		"updated_unix": int(Time.get_unix_time_from_system()),
		"rounds": _rounds
	}, "\t"))
	return path
