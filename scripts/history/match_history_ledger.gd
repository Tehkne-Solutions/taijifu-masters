class_name MatchHistoryLedger
extends RefCounted

const SAVE_PATH := "user://match_history.json"
const VERSION := 1
const MAX_SERIES := 100

var data: Dictionary = {"version": VERSION, "matches": []}

func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var root: Dictionary = parsed
		var source: Variant = root.get("matches", [])
		if source is Array:
			data = {"version": VERSION, "matches": source}
	_sanitize()

func save_to_disk() -> String:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
	data["version"] = VERSION
	data["updated_unix"] = int(Time.get_unix_time_from_system())
	file.store_string(JSON.stringify(data, "\t"))
	return SAVE_PATH

func append_series(record: Dictionary) -> Dictionary:
	var matches: Array = data.get("matches", [])
	var clean := _sanitize_record(record)
	matches.append(clean)
	while matches.size() > MAX_SERIES:
		matches.pop_front()
	data["matches"] = matches
	save_to_disk()
	return clean.duplicate(true)

func recent(limit: int = 10) -> Array[Dictionary]:
	var matches: Array = data.get("matches", [])
	var result: Array[Dictionary] = []
	var start := maxi(0, matches.size() - maxi(0, limit))
	for index in range(matches.size() - 1, start - 1, -1):
		if matches[index] is Dictionary:
			result.append((matches[index] as Dictionary).duplicate(true))
	return result

func match_count() -> int:
	return (data.get("matches", []) as Array).size()

func clear() -> void:
	data = {"version": VERSION, "matches": []}
	save_to_disk()

func aggregate() -> Dictionary:
	var result := {
		"series": 0,
		"rounds": 0,
		"p1_wins": 0,
		"p2_wins": 0,
		"ko_rounds": 0,
		"time_rounds": 0,
		"sudden_death_rounds": 0,
		"total_duration": 0.0,
		"arena_counts": {},
		"character_wins": {},
		"damage_p1": 0.0,
		"damage_p2": 0.0,
		"parries_p1": 0,
		"parries_p2": 0
	}
	for value in data.get("matches", []):
		if not (value is Dictionary):
			continue
		var record: Dictionary = value
		result["series"] = int(result["series"]) + 1
		var winner := int(record.get("winner_index", 0))
		if winner == 1:
			result["p1_wins"] = int(result["p1_wins"]) + 1
		elif winner == 2:
			result["p2_wins"] = int(result["p2_wins"]) + 1
		var config: Dictionary = record.get("config", {})
		var arena_id := String(config.get("arena_id", "triple_path"))
		var arena_counts: Dictionary = result["arena_counts"]
		arena_counts[arena_id] = int(arena_counts.get(arena_id, 0)) + 1
		result["arena_counts"] = arena_counts
		var players: Array = record.get("players", [])
		if winner in [1, 2] and players.size() >= winner and players[winner - 1] is Dictionary:
			var player: Dictionary = players[winner - 1]
			var character_id := String(player.get("character_id", "unknown"))
			var character_wins: Dictionary = result["character_wins"]
			character_wins[character_id] = int(character_wins.get(character_id, 0)) + 1
			result["character_wins"] = character_wins
		for round_value in record.get("rounds", []):
			if not (round_value is Dictionary):
				continue
			var round_data: Dictionary = round_value
			result["rounds"] = int(result["rounds"]) + 1
			result["total_duration"] = float(result["total_duration"]) + float(round_data.get("duration_seconds", 0.0))
			var reason := String(round_data.get("reason", ""))
			if reason == "KO":
				result["ko_rounds"] = int(result["ko_rounds"]) + 1
			elif reason == "TEMPO":
				result["time_rounds"] = int(result["time_rounds"]) + 1
			elif reason.contains("PRORROGAÇÃO"):
				result["sudden_death_rounds"] = int(result["sudden_death_rounds"]) + 1
			var stats: Array = round_data.get("stats", [])
			if stats.size() >= 2:
				if stats[0] is Dictionary:
					result["damage_p1"] = float(result["damage_p1"]) + float((stats[0] as Dictionary).get("damage_dealt", 0.0))
					result["parries_p1"] = int(result["parries_p1"]) + int((stats[0] as Dictionary).get("parries", 0))
				if stats[1] is Dictionary:
					result["damage_p2"] = float(result["damage_p2"]) + float((stats[1] as Dictionary).get("damage_dealt", 0.0))
					result["parries_p2"] = int(result["parries_p2"]) + int((stats[1] as Dictionary).get("parries", 0))
	var series_count := int(result["series"])
	var round_count := int(result["rounds"])
	result["average_rounds"] = float(round_count) / float(series_count) if series_count > 0 else 0.0
	result["average_round_seconds"] = float(result["total_duration"]) / float(round_count) if round_count > 0 else 0.0
	return result

func _sanitize() -> void:
	var clean: Array = []
	for value in data.get("matches", []):
		if value is Dictionary:
			clean.append(_sanitize_record(value as Dictionary))
	while clean.size() > MAX_SERIES:
		clean.pop_front()
	data["matches"] = clean

func _sanitize_record(source: Dictionary) -> Dictionary:
	var config_source: Variant = source.get("config", {})
	var players_source: Variant = source.get("players", [])
	var rounds_source: Variant = source.get("rounds", [])
	return {
		"match_id": String(source.get("match_id", "match_%d" % int(Time.get_unix_time_from_system()))),
		"started_unix": int(source.get("started_unix", 0)),
		"completed_unix": int(source.get("completed_unix", Time.get_unix_time_from_system())),
		"winner_index": clampi(int(source.get("winner_index", 0)), 0, 2),
		"score_p1": maxi(0, int(source.get("score_p1", 0))),
		"score_p2": maxi(0, int(source.get("score_p2", 0))),
		"config": CompetitiveMatchCatalog.sanitize(config_source as Dictionary if config_source is Dictionary else {}),
		"players": (players_source as Array).duplicate(true) if players_source is Array else [],
		"rounds": (rounds_source as Array).duplicate(true) if rounds_source is Array else [],
		"totals": (source.get("totals", {}) as Dictionary).duplicate(true) if source.get("totals", {}) is Dictionary else {}
	}
