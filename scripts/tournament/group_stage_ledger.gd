class_name GroupStageLedger
extends RefCounted

const SAVE_PATH := "user://group_stage_state.json"
const VERSION := 1
const PARTICIPANT_COUNT := 8
const GROUP_SIZE := 4
const GROUP_SEEDS := {
	"A": [1, 4, 5, 8],
	"B": [2, 3, 6, 7]
}
const ROUND_ROBIN_PAIRS := [[0, 3], [1, 2], [0, 2], [3, 1], [0, 1], [2, 3]]

var data: Dictionary = default_state()

static func default_state() -> Dictionary:
	return {
		"version": VERSION,
		"active": false,
		"finished": false,
		"participants": [],
		"matches": [],
		"current_match_index": 0,
		"standings": {},
		"qualifiers": [],
		"updated_unix": 0
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

func reset() -> void:
	data = default_state()
	save_to_disk()

func set_participants(participants: Array[Dictionary]) -> bool:
	if participants.size() != PARTICIPANT_COUNT:
		return false
	var helper := TournamentLedger.new()
	var clean: Array[Dictionary] = []
	for index in range(PARTICIPANT_COUNT):
		var participant := helper.sanitize_participant(participants[index], index)
		if participant.is_empty():
			return false
		participant["seed"] = index + 1
		participant["group_id"] = _group_for_seed(index + 1)
		clean.append(participant)
	data = default_state()
	data["participants"] = clean
	data["matches"] = _build_schedule(clean)
	data["standings"] = _build_standings(clean)
	save_to_disk()
	return true

func start() -> bool:
	var participants: Array = data.get("participants", [])
	var matches: Array = data.get("matches", [])
	if participants.size() != PARTICIPANT_COUNT or matches.size() != 12:
		return false
	data["active"] = true
	data["finished"] = false
	data["current_match_index"] = 0
	data["qualifiers"] = []
	save_to_disk()
	return true

func is_active() -> bool:
	return bool(data.get("active", false)) and not bool(data.get("finished", false))

func is_finished() -> bool:
	return bool(data.get("finished", false))

func current_match() -> Dictionary:
	if not is_active():
		return {}
	var matches: Array = data.get("matches", [])
	var index := int(data.get("current_match_index", 0))
	if index < 0 or index >= matches.size() or not (matches[index] is Dictionary):
		return {}
	return (matches[index] as Dictionary).duplicate(true)

func current_pair() -> Array[Dictionary]:
	var match_data := current_match()
	if match_data.is_empty():
		return []
	var p1_source: Variant = match_data.get("p1", {})
	var p2_source: Variant = match_data.get("p2", {})
	if not (p1_source is Dictionary) or not (p2_source is Dictionary):
		return []
	return [(p1_source as Dictionary).duplicate(true), (p2_source as Dictionary).duplicate(true)]

func record_result(winner_index: int, score_p1: int, score_p2: int) -> Dictionary:
	if not is_active():
		return {"ok": false, "error": "Fase de grupos inativa"}
	var matches: Array = data.get("matches", [])
	var index := int(data.get("current_match_index", 0))
	if index < 0 or index >= matches.size() or not (matches[index] is Dictionary):
		return {"ok": false, "error": "Confronto atual inválido"}
	var clean_winner := clampi(winner_index, 1, 2)
	var match_data: Dictionary = matches[index]
	if int(match_data.get("winner_index", 0)) != 0:
		return {"ok": false, "error": "Confronto já registrado"}
	match_data["winner_index"] = clean_winner
	match_data["score_p1"] = maxi(0, score_p1)
	match_data["score_p2"] = maxi(0, score_p2)
	match_data["winner"] = (match_data.get("p1", {}) as Dictionary).duplicate(true) if clean_winner == 1 else (match_data.get("p2", {}) as Dictionary).duplicate(true)
	matches[index] = match_data
	data["matches"] = matches
	_apply_result_to_standings(match_data)
	if index + 1 < matches.size():
		data["current_match_index"] = index + 1
		save_to_disk()
		return {
			"ok": true,
			"finished": false,
			"winner": (match_data.get("winner", {}) as Dictionary).duplicate(true),
			"next_match": current_match(),
			"stage_label": stage_label()
		}
	data["active"] = false
	data["finished"] = true
	data["current_match_index"] = matches.size()
	data["qualifiers"] = _build_qualifiers()
	save_to_disk()
	return {
		"ok": true,
		"finished": true,
		"winner": (match_data.get("winner", {}) as Dictionary).duplicate(true),
		"qualifiers": qualifiers()
	}

func stage_label() -> String:
	if is_finished():
		return "FASE DE GRUPOS CONCLUÍDA"
	var current := current_match()
	if current.is_empty():
		return "FASE DE GRUPOS"
	return "GRUPO %s • RODADA %d • JOGO %d/12" % [
		String(current.get("group_id", "A")), int(current.get("round_number", 1)), int(data.get("current_match_index", 0)) + 1
	]

func standings(group_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var table_source: Variant = data.get("standings", {})
	var table: Dictionary = table_source as Dictionary if table_source is Dictionary else {}
	for value in table.values():
		if value is Dictionary and String((value as Dictionary).get("group_id", "")) == group_id:
			var entry: Dictionary = (value as Dictionary).duplicate(true)
			entry["round_diff"] = int(entry.get("rounds_for", 0)) - int(entry.get("rounds_against", 0))
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var points_a := int(a.get("points", 0))
		var points_b := int(b.get("points", 0))
		if points_a != points_b:
			return points_a > points_b
		var wins_a := int(a.get("wins", 0))
		var wins_b := int(b.get("wins", 0))
		if wins_a != wins_b:
			return wins_a > wins_b
		var diff_a := int(a.get("round_diff", 0))
		var diff_b := int(b.get("round_diff", 0))
		if diff_a != diff_b:
			return diff_a > diff_b
		var rounds_a := int(a.get("rounds_for", 0))
		var rounds_b := int(b.get("rounds_for", 0))
		if rounds_a != rounds_b:
			return rounds_a > rounds_b
		return int(a.get("seed", 99)) < int(b.get("seed", 99))
	)
	for index in range(result.size()):
		result[index]["position"] = index + 1
	return result

func qualifiers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in data.get("qualifiers", []):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result

func semifinal_participants() -> Array[Dictionary]:
	var qualified := qualifiers()
	if qualified.size() != 4:
		return []
	var by_label: Dictionary = {}
	for participant in qualified:
		by_label[String(participant.get("qualification", ""))] = participant
	var order := ["A1", "B1", "A2", "B2"]
	var result: Array[Dictionary] = []
	for label in order:
		if not by_label.has(label):
			return []
		result.append((by_label[label] as Dictionary).duplicate(true))
	return result

func snapshot() -> Dictionary:
	return data.duplicate(true)

func all_matches() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in data.get("matches", []):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result

func sanitize_state(source: Dictionary) -> Dictionary:
	var result := default_state()
	var helper := TournamentLedger.new()
	var participants: Array[Dictionary] = []
	var participants_source: Variant = source.get("participants", [])
	if participants_source is Array:
		for index in range(mini(PARTICIPANT_COUNT, participants_source.size())):
			if not (participants_source[index] is Dictionary):
				continue
			var clean := helper.sanitize_participant(participants_source[index] as Dictionary, index)
			if clean.is_empty():
				continue
			clean["seed"] = index + 1
			clean["group_id"] = _group_for_seed(index + 1)
			participants.append(clean)
	result["participants"] = participants
	var matches: Array = []
	var matches_source: Variant = source.get("matches", [])
	if matches_source is Array:
		for value in matches_source:
			if value is Dictionary:
				var clean_match := _sanitize_match(value as Dictionary, helper)
				if not clean_match.is_empty():
					matches.append(clean_match)
	if matches.is_empty() and participants.size() == PARTICIPANT_COUNT:
		matches = _build_schedule(participants)
	result["matches"] = matches
	var standings_source: Variant = source.get("standings", {})
	result["standings"] = (standings_source as Dictionary).duplicate(true) if standings_source is Dictionary else _build_standings(participants)
	var qualifiers_source: Variant = source.get("qualifiers", [])
	result["qualifiers"] = (qualifiers_source as Array).duplicate(true) if qualifiers_source is Array else []
	result["current_match_index"] = clampi(int(source.get("current_match_index", 0)), 0, matches.size())
	result["finished"] = bool(source.get("finished", false))
	result["active"] = bool(source.get("active", false)) and participants.size() == PARTICIPANT_COUNT and not bool(result["finished"])
	result["updated_unix"] = int(source.get("updated_unix", 0))
	return result

func _build_schedule(participants: Array[Dictionary]) -> Array:
	var groups := {
		"A": _participants_for_group(participants, "A"),
		"B": _participants_for_group(participants, "B")
	}
	var matches: Array = []
	for pair_index in range(ROUND_ROBIN_PAIRS.size()):
		for group_id in ["A", "B"]:
			var group: Array = groups[group_id]
			var pair: Array = ROUND_ROBIN_PAIRS[pair_index]
			matches.append({
				"match_id": "group_%s_%d" % [String(group_id).to_lower(), pair_index + 1],
				"group_id": group_id,
				"round_number": int(pair_index / 2) + 1,
				"p1": (group[int(pair[0])] as Dictionary).duplicate(true),
				"p2": (group[int(pair[1])] as Dictionary).duplicate(true),
				"winner_index": 0,
				"winner": {},
				"score_p1": 0,
				"score_p2": 0
			})
	return matches

func _build_standings(participants: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for participant in participants:
		var participant_id := String(participant.get("participant_id", ""))
		result[participant_id] = {
			"participant_id": participant_id,
			"name": String(participant.get("name", "COMPETIDOR")),
			"seed": int(participant.get("seed", 0)),
			"group_id": String(participant.get("group_id", "A")),
			"played": 0,
			"points": 0,
			"wins": 0,
			"losses": 0,
			"rounds_for": 0,
			"rounds_against": 0
		}
	return result

func _apply_result_to_standings(match_data: Dictionary) -> void:
	var table: Dictionary = data.get("standings", {})
	var p1: Dictionary = match_data.get("p1", {})
	var p2: Dictionary = match_data.get("p2", {})
	var p1_id := String(p1.get("participant_id", ""))
	var p2_id := String(p2.get("participant_id", ""))
	if not table.has(p1_id) or not table.has(p2_id):
		return
	var entry_p1: Dictionary = table[p1_id]
	var entry_p2: Dictionary = table[p2_id]
	var score_p1 := int(match_data.get("score_p1", 0))
	var score_p2 := int(match_data.get("score_p2", 0))
	entry_p1["played"] = int(entry_p1.get("played", 0)) + 1
	entry_p2["played"] = int(entry_p2.get("played", 0)) + 1
	entry_p1["rounds_for"] = int(entry_p1.get("rounds_for", 0)) + score_p1
	entry_p1["rounds_against"] = int(entry_p1.get("rounds_against", 0)) + score_p2
	entry_p2["rounds_for"] = int(entry_p2.get("rounds_for", 0)) + score_p2
	entry_p2["rounds_against"] = int(entry_p2.get("rounds_against", 0)) + score_p1
	if int(match_data.get("winner_index", 0)) == 1:
		entry_p1["wins"] = int(entry_p1.get("wins", 0)) + 1
		entry_p1["points"] = int(entry_p1.get("points", 0)) + 3
		entry_p2["losses"] = int(entry_p2.get("losses", 0)) + 1
	else:
		entry_p2["wins"] = int(entry_p2.get("wins", 0)) + 1
		entry_p2["points"] = int(entry_p2.get("points", 0)) + 3
		entry_p1["losses"] = int(entry_p1.get("losses", 0)) + 1
	table[p1_id] = entry_p1
	table[p2_id] = entry_p2
	data["standings"] = table

func _build_qualifiers() -> Array:
	var group_a := standings("A")
	var group_b := standings("B")
	if group_a.size() < 2 or group_b.size() < 2:
		return []
	var labels := [[group_a[0], "A1"], [group_a[1], "A2"], [group_b[0], "B1"], [group_b[1], "B2"]]
	var result: Array[Dictionary] = []
	for pair in labels:
		var standing: Dictionary = pair[0]
		var participant := _participant_by_id(String(standing.get("participant_id", "")))
		if participant.is_empty():
			continue
		participant["qualification"] = String(pair[1])
		participant["group_position"] = int(standing.get("position", 0))
		participant["group_points"] = int(standing.get("points", 0))
		result.append(participant)
	return result

func _participants_for_group(participants: Array[Dictionary], group_id: String) -> Array:
	var result: Array = []
	for seed in GROUP_SEEDS[group_id]:
		result.append(_participant_by_seed(participants, int(seed)))
	return result

func _participant_by_seed(participants: Array[Dictionary], seed: int) -> Dictionary:
	for participant in participants:
		if int(participant.get("seed", 0)) == seed:
			return participant.duplicate(true)
	return {}

func _participant_by_id(participant_id: String) -> Dictionary:
	for value in data.get("participants", []):
		if value is Dictionary and String((value as Dictionary).get("participant_id", "")) == participant_id:
			return (value as Dictionary).duplicate(true)
	return {}

func _group_for_seed(seed: int) -> String:
	return "A" if seed in GROUP_SEEDS["A"] else "B"

func _sanitize_match(source: Dictionary, helper: TournamentLedger) -> Dictionary:
	var p1_source: Variant = source.get("p1", {})
	var p2_source: Variant = source.get("p2", {})
	if not (p1_source is Dictionary) or not (p2_source is Dictionary):
		return {}
	var p1 := helper.sanitize_participant(p1_source as Dictionary, 0)
	var p2 := helper.sanitize_participant(p2_source as Dictionary, 1)
	if p1.is_empty() or p2.is_empty():
		return {}
	p1["group_id"] = String(source.get("group_id", "A"))
	p2["group_id"] = String(source.get("group_id", "A"))
	var winner_source: Variant = source.get("winner", {})
	return {
		"match_id": String(source.get("match_id", "group_match")),
		"group_id": String(source.get("group_id", "A")),
		"round_number": maxi(1, int(source.get("round_number", 1))),
		"p1": p1,
		"p2": p2,
		"winner_index": clampi(int(source.get("winner_index", 0)), 0, 2),
		"winner": (winner_source as Dictionary).duplicate(true) if winner_source is Dictionary else {},
		"score_p1": maxi(0, int(source.get("score_p1", 0))),
		"score_p2": maxi(0, int(source.get("score_p2", 0)))
	}
