class_name MatchHistoryLedger
extends RefCounted

const SAVE_PATH := "user://match_history.json"
const VERSION := 3
const MAX_SERIES := 100
const RESULT_FILTERS: Array[StringName] = [&"all", &"p1_win", &"p2_win", &"ko", &"time", &"sudden_death"]
const TAG_OPTIONS: Array[StringName] = [&"technical", &"rematch", &"tournament", &"highlight"]
const CURATION_FILTERS: Array[StringName] = [&"all", &"favorites", &"technical", &"rematch", &"tournament", &"highlight"]

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
	return filtered({}, limit)

func filtered(filters: Dictionary, limit: int = 20) -> Array[Dictionary]:
	var matches: Array = data.get("matches", [])
	var result: Array[Dictionary] = []
	for index in range(matches.size() - 1, -1, -1):
		if not (matches[index] is Dictionary):
			continue
		var record: Dictionary = matches[index]
		if not _matches_filters(record, filters):
			continue
		result.append(record.duplicate(true))
		if limit > 0 and result.size() >= limit:
			break
	return result

func match_by_id(match_id: String) -> Dictionary:
	for value in data.get("matches", []):
		if value is Dictionary and String((value as Dictionary).get("match_id", "")) == match_id:
			return (value as Dictionary).duplicate(true)
	return {}

func toggle_favorite(match_id: String) -> bool:
	var matches: Array = data.get("matches", [])
	for index in range(matches.size()):
		if not (matches[index] is Dictionary):
			continue
		var record: Dictionary = matches[index]
		if String(record.get("match_id", "")) != match_id:
			continue
		record["favorite"] = not bool(record.get("favorite", false))
		matches[index] = record
		data["matches"] = matches
		save_to_disk()
		return bool(record["favorite"])
	return false

func toggle_tag(match_id: String, tag_id: StringName) -> Array[StringName]:
	if tag_id not in TAG_OPTIONS:
		return []
	var matches: Array = data.get("matches", [])
	for index in range(matches.size()):
		if not (matches[index] is Dictionary):
			continue
		var record: Dictionary = matches[index]
		if String(record.get("match_id", "")) != match_id:
			continue
		var tags := _sanitize_tags(record.get("tags", []))
		if tag_id in tags:
			tags.erase(tag_id)
		else:
			tags.append(tag_id)
		record["tags"] = tags.duplicate()
		matches[index] = record
		data["matches"] = matches
		save_to_disk()
		return tags
	return []

func metadata(match_id: String) -> Dictionary:
	var record := match_by_id(match_id)
	if record.is_empty():
		return {"favorite": false, "tags": []}
	return {
		"favorite": bool(record.get("favorite", false)),
		"tags": _sanitize_tags(record.get("tags", []))
	}

func match_count(filters: Dictionary = {}) -> int:
	if filters.is_empty():
		return (data.get("matches", []) as Array).size()
	return filtered(filters, 0).size()

func clear() -> void:
	data = {"version": VERSION, "matches": []}
	save_to_disk()

func aggregate(filters: Dictionary = {}) -> Dictionary:
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
		"parries_p2": 0,
		"highlights": 0,
		"favorites": 0,
		"tag_counts": {}
	}
	var source := filtered(filters, 0) if not filters.is_empty() else _all_matches()
	for record in source:
		result["series"] = int(result["series"]) + 1
		if bool(record.get("favorite", false)):
			result["favorites"] = int(result["favorites"]) + 1
		var tag_counts: Dictionary = result["tag_counts"]
		for tag_id in _sanitize_tags(record.get("tags", [])):
			tag_counts[String(tag_id)] = int(tag_counts.get(String(tag_id), 0)) + 1
		result["tag_counts"] = tag_counts
		var winner := int(record.get("winner_index", 0))
		if winner == 1:
			result["p1_wins"] = int(result["p1_wins"]) + 1
		elif winner == 2:
			result["p2_wins"] = int(result["p2_wins"]) + 1
		var config: Dictionary = record.get("config", {})
		var arena_id := String(config.get("arena_id", "triple_ruins"))
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
			result["highlights"] = int(result["highlights"]) + (round_data.get("highlights", []) as Array).size()
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

func _matches_filters(record: Dictionary, filters: Dictionary) -> bool:
	var query := normalize_search(String(filters.get("text_query", "")))
	if query != "" and not search_blob(record).contains(query):
		return false
	var character_id := StringName(filters.get("character_id", &"all"))
	if character_id != &"all":
		var found := false
		for player_value in record.get("players", []):
			if player_value is Dictionary and StringName((player_value as Dictionary).get("character_id", &"")) == character_id:
				found = true
				break
		if not found:
			return false
	var arena_id := StringName(filters.get("arena_id", &"all"))
	if arena_id != &"all":
		var config: Dictionary = record.get("config", {})
		if StringName(config.get("arena_id", &"triple_ruins")) != arena_id:
			return false
	var result_id := StringName(filters.get("result_id", &"all"))
	if result_id not in RESULT_FILTERS:
		result_id = &"all"
	match result_id:
		&"p1_win":
			if int(record.get("winner_index", 0)) != 1: return false
		&"p2_win":
			if int(record.get("winner_index", 0)) != 2: return false
		&"ko":
			if not _has_reason(record, "KO"): return false
		&"time":
			if not _has_reason(record, "TEMPO"): return false
		&"sudden_death":
			if not _has_reason_fragment(record, "PRORGAÇÃO") and not _has_reason_fragment(record, "PRORROGAÇÃO"): return false
		_:
			pass
	var curation_id := StringName(filters.get("curation_id", &"all"))
	if curation_id not in CURATION_FILTERS:
		curation_id = &"all"
	if curation_id == &"favorites" and not bool(record.get("favorite", false)):
		return false
	if curation_id in TAG_OPTIONS and curation_id not in _sanitize_tags(record.get("tags", [])):
		return false
	return true

static func normalize_search(value: String) -> String:
	var clean := value.to_lower().strip_edges()
	clean = clean.replace("á", "a").replace("à", "a").replace("ã", "a").replace("â", "a")
	clean = clean.replace("é", "e").replace("ê", "e").replace("í", "i")
	clean = clean.replace("ó", "o").replace("ô", "o").replace("õ", "o")
	clean = clean.replace("ú", "u").replace("ç", "c")
	while clean.contains("  "):
		clean = clean.replace("  ", " ")
	return clean

static func search_blob(record: Dictionary) -> String:
	var parts: Array[String] = [String(record.get("match_id", ""))]
	var config_source: Variant = record.get("config", {})
	if config_source is Dictionary:
		var config: Dictionary = config_source
		parts.append(CompetitiveMatchCatalog.arena_label(config))
		parts.append(CompetitiveMatchCatalog.config_summary(config))
	for player_value in record.get("players", []):
		if player_value is Dictionary:
			var player: Dictionary = player_value
			parts.append(String(player.get("profile_name", "")))
			parts.append(String(player.get("character_name", "")))
			parts.append(String(player.get("build_name", "")))
	for tag_value in record.get("tags", []):
		parts.append(String(tag_value))
	for round_value in record.get("rounds", []):
		if not (round_value is Dictionary):
			continue
		var round_data: Dictionary = round_value
		parts.append(String(round_data.get("reason", "")))
		for highlight_value in round_data.get("highlights", []):
			if highlight_value is Dictionary:
				parts.append(String((highlight_value as Dictionary).get("label", "")))
				parts.append(String((highlight_value as Dictionary).get("event_id", "")))
	return normalize_search(" ".join(parts))

func _has_reason(record: Dictionary, expected: String) -> bool:
	for value in record.get("rounds", []):
		if value is Dictionary and String((value as Dictionary).get("reason", "")) == expected:
			return true
	return false

func _has_reason_fragment(record: Dictionary, expected: String) -> bool:
	for value in record.get("rounds", []):
		if value is Dictionary and String((value as Dictionary).get("reason", "")).contains(expected):
			return true
	return false

func _all_matches() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in data.get("matches", []):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
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
	var totals_source: Variant = source.get("totals", [])
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
		"totals": (totals_source as Array).duplicate(true) if totals_source is Array else [],
		"favorite": bool(source.get("favorite", false)),
		"tags": _sanitize_tags(source.get("tags", []))
	}

func _sanitize_tags(source: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not (source is Array):
		return result
	for value in source:
		var tag_id := StringName(value)
		if tag_id in TAG_OPTIONS and tag_id not in result:
			result.append(tag_id)
	return result
