class_name CompetitiveSeasonLedger
extends RefCounted

const SAVE_PATH := "user://competitive_seasons.json"
const VERSION := 1
const MAX_SEASONS := 12

var data: Dictionary = default_state()

static func default_state() -> Dictionary:
	return {
		"version": VERSION,
		"active_season_id": "season_1",
		"seasons": [{
			"season_id": "season_1",
			"name": "TEMPORADA 1",
			"created_unix": 0,
			"closed_unix": 0,
			"status": "active"
		}]
	}

func load_from_disk() -> void:
	data = default_state()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = sanitize_state(parsed as Dictionary)

func save_to_disk() -> String:
	data = sanitize_state(data)
	data["updated_unix"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(data, "\t"))
	return SAVE_PATH

func seasons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in data.get("seasons", []):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result

func active_season() -> Dictionary:
	var active_id := String(data.get("active_season_id", "season_1"))
	var found := season_by_id(active_id)
	if not found.is_empty():
		return found
	var source := seasons()
	return source[0] if not source.is_empty() else default_state()["seasons"][0]

func active_context() -> Dictionary:
	var season := active_season()
	return {
		"season_id": String(season.get("season_id", "season_1")),
		"season_name": String(season.get("name", "TEMPORADA 1"))
	}

func season_by_id(season_id: String) -> Dictionary:
	for season in seasons():
		if String(season.get("season_id", "")) == season_id:
			return season
	return {}

func create_season(name: String) -> Dictionary:
	var source := seasons()
	if source.size() >= MAX_SEASONS:
		return {}
	var now := int(Time.get_unix_time_from_system())
	var season := {
		"season_id": "season_%d_%d" % [now, Time.get_ticks_msec() % 100000],
		"name": sanitize_name(name, "TEMPORADA %d" % (source.size() + 1)),
		"created_unix": now,
		"closed_unix": 0,
		"status": "active"
	}
	for index in range(source.size()):
		var existing: Dictionary = source[index]
		if String(existing.get("status", "closed")) == "active":
			existing["status"] = "closed"
			existing["closed_unix"] = now
			source[index] = existing
	source.append(season)
	data["seasons"] = source
	data["active_season_id"] = String(season["season_id"])
	save_to_disk()
	return season.duplicate(true)

func activate(season_id: String) -> bool:
	var source: Array = data.get("seasons", [])
	var target_found := false
	var now := int(Time.get_unix_time_from_system())
	for index in range(source.size()):
		if not (source[index] is Dictionary):
			continue
		var season: Dictionary = source[index]
		var current_id := String(season.get("season_id", ""))
		if current_id == season_id:
			season["status"] = "active"
			season["closed_unix"] = 0
			target_found = true
		elif String(season.get("status", "closed")) == "active":
			season["status"] = "closed"
			season["closed_unix"] = now
		source[index] = season
	if not target_found:
		return false
	data["seasons"] = source
	data["active_season_id"] = season_id
	save_to_disk()
	return true

func close_active() -> Dictionary:
	var active := active_season()
	var active_id := String(active.get("season_id", ""))
	var source: Array = data.get("seasons", [])
	for index in range(source.size()):
		if not (source[index] is Dictionary):
			continue
		var season: Dictionary = source[index]
		if String(season.get("season_id", "")) != active_id:
			continue
		season["status"] = "closed"
		season["closed_unix"] = int(Time.get_unix_time_from_system())
		source[index] = season
		data["seasons"] = source
		data["active_season_id"] = active_id
		save_to_disk()
		return season.duplicate(true)
	return {}

func rename(season_id: String, name: String) -> bool:
	var source: Array = data.get("seasons", [])
	for index in range(source.size()):
		if not (source[index] is Dictionary):
			continue
		var season: Dictionary = source[index]
		if String(season.get("season_id", "")) != season_id:
			continue
		season["name"] = sanitize_name(name, String(season.get("name", "TEMPORADA")))
		source[index] = season
		data["seasons"] = source
		save_to_disk()
		return true
	return false

func sanitize_state(source: Dictionary) -> Dictionary:
	var result := default_state()
	var clean: Array[Dictionary] = []
	var seen: Dictionary = {}
	var source_seasons: Variant = source.get("seasons", [])
	if source_seasons is Array:
		for value in source_seasons:
			if not (value is Dictionary) or clean.size() >= MAX_SEASONS:
				continue
			var season: Dictionary = value
			var season_id := String(season.get("season_id", "")).strip_edges().left(64)
			if season_id == "" or seen.has(season_id):
				continue
			seen[season_id] = true
			clean.append({
				"season_id": season_id,
				"name": sanitize_name(String(season.get("name", "TEMPORADA")), "TEMPORADA"),
				"created_unix": int(season.get("created_unix", 0)),
				"closed_unix": int(season.get("closed_unix", 0)),
				"status": "active" if String(season.get("status", "closed")) == "active" else "closed"
			})
	if clean.is_empty():
		clean = default_state()["seasons"].duplicate(true)
		seen["season_1"] = true
	var requested := String(source.get("active_season_id", clean[0].get("season_id", "season_1")))
	if not seen.has(requested):
		requested = String(clean[0].get("season_id", "season_1"))
	for index in range(clean.size()):
		clean[index]["status"] = "active" if String(clean[index].get("season_id", "")) == requested else "closed"
	result["seasons"] = clean
	result["active_season_id"] = requested
	result["updated_unix"] = int(source.get("updated_unix", 0))
	return result

static func sanitize_name(value: String, fallback: String = "TEMPORADA") -> String:
	var clean := value.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	while clean.contains("  "):
		clean = clean.replace("  ", " ")
	return (clean if clean != "" else fallback).left(40)
