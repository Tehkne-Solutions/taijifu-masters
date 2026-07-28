class_name GhostRivalRankingRuntime
extends Node

const BRIDGE_VERSION := 1
const SAVE_PATH := "user://taijifu-ghost-rival-ranking.json"
const MAX_ENTRIES := 100

var entries: Dictionary = {}
var processed_events: Dictionary = {}
var last_updated_unix := 0
var _poll_elapsed := 0.0
var _window: JavaScriptObject
var _callbacks: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_state()
	call_deferred("_seed_from_series")
	_register_web_bridge()

func _process(delta: float) -> void:
	_poll_elapsed += delta
	if _poll_elapsed < 0.5:
		return
	_poll_elapsed = 0.0
	_capture_latest_series()

func _capture_latest_series() -> void:
	var series := get_node_or_null("/root/TaijifuGhostRaceSeries")
	if not is_instance_valid(series):
		return
	var result: Dictionary = series.last_series
	if result.is_empty():
		return
	var event_key := _event_key(result)
	if event_key.is_empty() or processed_events.has(event_key):
		return
	record_series(result)

func record_series(result: Dictionary) -> Dictionary:
	var rival_id := String(result.get("target_id", ""))
	if rival_id.is_empty():
		return _result(false, "Resultado sem rival identificado.")
	var event_key := _event_key(result)
	if not event_key.is_empty() and processed_events.has(event_key):
		return _result(false, "Resultado já contabilizado.")
	var record := _ensure_entry(rival_id, String(result.get("target_name", "Fantasma")))
	var outcome := String(result.get("outcome", "perdeu"))
	var reward: Dictionary = result.get("reward", {})
	record["series_played"] = int(record.get("series_played", 0)) + 1
	if outcome == "venceu":
		record["series_won"] = int(record.get("series_won", 0)) + 1
	else:
		record["series_lost"] = int(record.get("series_lost", 0)) + 1
	if bool(result.get("sweep", false)):
		record["sweeps"] = int(record.get("sweeps", 0)) + 1
	record["xp"] = int(record.get("xp", 0)) + int(reward.get("xp", 0))
	record["tokens"] = int(record.get("tokens", 0)) + int(reward.get("tokens", 0))
	record["best_of_5_wins"] = int(record.get("best_of_5_wins", 0)) + (1 if outcome == "venceu" and int(result.get("best_of", 3)) == 5 else 0)
	record["last_outcome"] = outcome
	record["last_finished_unix"] = int(result.get("finished_unix", Time.get_unix_time_from_system()))
	record["rating"] = _calculate_rating(record)
	entries[rival_id] = record
	if not event_key.is_empty():
		processed_events[event_key] = true
	_trim_processed_events()
	last_updated_unix = int(Time.get_unix_time_from_system())
	_save_state()
	_sync_web_state()
	return _result(true, "Ranking atualizado.", {"rival": public_entry(rival_id), "leaderboard": leaderboard()})

func leaderboard(limit: int = 20) -> Array:
	var rows: Array = []
	for value in entries.values():
		if value is Dictionary:
			rows.append((value as Dictionary).duplicate(true))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rating_a := int(a.get("rating", 0))
		var rating_b := int(b.get("rating", 0))
		if rating_a != rating_b:
			return rating_a > rating_b
		var wins_a := int(a.get("series_won", 0))
		var wins_b := int(b.get("series_won", 0))
		if wins_a != wins_b:
			return wins_a > wins_b
		return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0
	)
	var capped := mini(maxi(1, limit), rows.size())
	var ranked: Array = []
	for index in range(capped):
		var row: Dictionary = rows[index]
		row["rank"] = index + 1
		row["win_rate"] = _win_rate(row)
		ranked.append(row)
	return ranked

func public_entry(id: String) -> Dictionary:
	if not entries.has(id):
		return {}
	var entry: Dictionary = (entries[id] as Dictionary).duplicate(true)
	entry["win_rate"] = _win_rate(entry)
	var rank := 0
	for row in leaderboard(MAX_ENTRIES):
		if String((row as Dictionary).get("id", "")) == id:
			rank = int((row as Dictionary).get("rank", 0))
			break
	entry["rank"] = rank
	return entry

func current_state() -> Dictionary:
	var board := leaderboard()
	return {
		"version": BRIDGE_VERSION,
		"ready": true,
		"tracked_rivals": entries.size(),
		"last_updated_unix": last_updated_unix,
		"champion": (board[0] as Dictionary).duplicate(true) if not board.is_empty() else {},
		"leaderboard": board
	}

func command(request: Dictionary) -> Dictionary:
	match StringName(request.get("command", "get_state")):
		&"refresh":
			_capture_latest_series()
			return current_state()
		&"get_rival":
			return public_entry(String(request.get("id", "")))
	return current_state()

func _ensure_entry(id: String, name: String) -> Dictionary:
	if entries.has(id):
		var existing: Dictionary = entries[id]
		existing["name"] = name
		return existing
	return {
		"id": id,
		"name": name,
		"rating": 1000,
		"xp": 0,
		"tokens": 0,
		"series_played": 0,
		"series_won": 0,
		"series_lost": 0,
		"sweeps": 0,
		"best_of_5_wins": 0,
		"last_outcome": "",
		"last_finished_unix": 0
	}

func _calculate_rating(record: Dictionary) -> int:
	var wins := int(record.get("series_won", 0))
	var losses := int(record.get("series_lost", 0))
	var xp := int(record.get("xp", 0))
	var sweeps := int(record.get("sweeps", 0))
	var best_of_5_wins := int(record.get("best_of_5_wins", 0))
	return maxi(100, 1000 + wins * 90 - losses * 35 + int(xp / 4.0) + sweeps * 40 + best_of_5_wins * 30)

func _win_rate(record: Dictionary) -> float:
	var played := int(record.get("series_played", 0))
	return 0.0 if played <= 0 else float(int(record.get("series_won", 0))) / float(played)

func _event_key(result: Dictionary) -> String:
	var rival_id := String(result.get("target_id", ""))
	var finished := int(result.get("finished_unix", 0))
	return "" if rival_id.is_empty() or finished <= 0 else "%s:%d" % [rival_id, finished]

func _seed_from_series() -> void:
	var series := get_node_or_null("/root/TaijifuGhostRaceSeries")
	if not is_instance_valid(series):
		return
	for rival_id in series.rivals.keys():
		if entries.has(rival_id):
			continue
		var source: Dictionary = series.rivals[rival_id]
		var record := _ensure_entry(String(rival_id), String(source.get("name", "Fantasma")))
		record["xp"] = int(source.get("xp", 0))
		record["tokens"] = int(source.get("tokens_earned", 0))
		record["series_played"] = int(source.get("series_played", 0))
		record["series_won"] = int(source.get("series_won", 0))
		record["series_lost"] = int(source.get("series_lost", 0))
		record["last_outcome"] = String(source.get("last_outcome", ""))
		record["last_finished_unix"] = int(source.get("updated_unix", 0))
		record["rating"] = _calculate_rating(record)
		entries[rival_id] = record
	if not entries.is_empty():
		_save_state()
		_sync_web_state()

func _trim_processed_events() -> void:
	if processed_events.size() <= 200:
		return
	var keys := processed_events.keys()
	for index in range(processed_events.size() - 200):
		processed_events.erase(keys[index])

func _save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"version": BRIDGE_VERSION,
			"entries": entries,
			"processed_events": processed_events,
			"last_updated_unix": last_updated_unix
		}))

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		return
	var data := parsed as Dictionary
	entries = data.get("entries", {})
	processed_events = data.get("processed_events", {})
	last_updated_unix = int(data.get("last_updated_unix", 0))

func _result(ok: bool, message: String, data: Dictionary = {}) -> Dictionary:
	return {"ok": ok, "message": message, "data": data}

func _register_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_window = JavaScriptBridge.get_interface("window")
	if _window == null:
		return
	var command_callback := JavaScriptBridge.create_callback(_web_command)
	var state_callback := JavaScriptBridge.create_callback(_web_state)
	_callbacks = [command_callback, state_callback]
	_window.taijifuGhostRivalRankingCommand = command_callback
	_window.taijifuGhostRivalRankingState = state_callback
	_window.taijifuGhostRivalRankingReady = true
	_sync_web_state()

func _web_command(args: Array) -> String:
	var parsed = JSON.parse_string(String(args[0])) if not args.is_empty() else {"command": "get_state"}
	return JSON.stringify(command(parsed as Dictionary)) if parsed is Dictionary else JSON.stringify(_result(false, "Comando inválido."))

func _web_state(_args: Array) -> String:
	return JSON.stringify(current_state())

func _sync_web_state() -> void:
	if OS.has_feature("web") and _window != null:
		_window.taijifuGhostRivalRankingStateJson = JSON.stringify(current_state())