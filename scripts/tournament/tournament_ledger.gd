class_name TournamentLedger
extends RefCounted

const SAVE_PATH := "user://tournament_state.json"
const VERSION := 2
const VALID_SIZES: Array[int] = [4, 8]

var data: Dictionary = default_state()

static func default_state(bracket_size: int = 4) -> Dictionary:
	var clean_size := bracket_size if bracket_size in VALID_SIZES else 4
	return {
		"version": VERSION,
		"bracket_size": clean_size,
		"active": false,
		"finished": false,
		"participants": [],
		"rounds": [],
		"round_index": 0,
		"match_index": 0,
		"champion": {},
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
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
	data = sanitize_state(data)
	data["updated_unix"] = int(Time.get_unix_time_from_system())
	file.store_string(JSON.stringify(data, "\t"))
	return SAVE_PATH

func reset(bracket_size: int = -1) -> void:
	var size := current_bracket_size() if bracket_size < 0 else bracket_size
	data = default_state(size)
	save_to_disk()

func set_bracket_size(bracket_size: int) -> int:
	var clean_size := bracket_size if bracket_size in VALID_SIZES else 4
	if bool(data.get("active", false)):
		return current_bracket_size()
	if clean_size != current_bracket_size():
		data = default_state(clean_size)
		save_to_disk()
	return clean_size

func current_bracket_size() -> int:
	var size := int(data.get("bracket_size", 4))
	return size if size in VALID_SIZES else 4

func set_participants(participants: Array[Dictionary]) -> bool:
	var size := participants.size()
	if size not in VALID_SIZES:
		return false
	var clean: Array[Dictionary] = []
	for index in range(size):
		var participant := sanitize_participant(participants[index], index)
		if participant.is_empty():
			return false
		participant["seed"] = index + 1
		clean.append(participant)
	data = default_state(size)
	data["participants"] = clean
	save_to_disk()
	return true

func start() -> bool:
	var participants: Array = data.get("participants", [])
	var size := current_bracket_size()
	if participants.size() != size:
		return false
	var first_round := _build_seeded_round(participants, size)
	if first_round.is_empty():
		return false
	data["active"] = true
	data["finished"] = false
	data["rounds"] = [first_round]
	data["round_index"] = 0
	data["match_index"] = 0
	data["champion"] = {}
	save_to_disk()
	return true

func current_pair() -> Array[Dictionary]:
	if bool(data.get("finished", false)):
		return []
	var rounds: Array = data.get("rounds", [])
	var round_index := int(data.get("round_index", 0))
	var match_index := int(data.get("match_index", 0))
	if round_index < 0 or round_index >= rounds.size() or not (rounds[round_index] is Array):
		return []
	var round_matches: Array = rounds[round_index]
	if match_index < 0 or match_index >= round_matches.size() or not (round_matches[match_index] is Dictionary):
		return []
	var match_data: Dictionary = round_matches[match_index]
	var p1_source: Variant = match_data.get("p1", {})
	var p2_source: Variant = match_data.get("p2", {})
	if not (p1_source is Dictionary) or not (p2_source is Dictionary):
		return []
	return [(p1_source as Dictionary).duplicate(true), (p2_source as Dictionary).duplicate(true)]

func record_winner(winner_index: int) -> Dictionary:
	if not bool(data.get("active", false)) or bool(data.get("finished", false)):
		return {"ok": false, "error": "Torneio inativo"}
	var pair := current_pair()
	if pair.size() != 2:
		return {"ok": false, "error": "Confronto atual inválido"}
	var clean_index := clampi(winner_index, 1, 2)
	var winner: Dictionary = pair[clean_index - 1].duplicate(true)
	var rounds: Array = data.get("rounds", [])
	var round_index := int(data.get("round_index", 0))
	var match_index := int(data.get("match_index", 0))
	var round_matches: Array = rounds[round_index]
	var match_data: Dictionary = round_matches[match_index]
	match_data["winner"] = winner
	match_data["winner_index"] = clean_index
	round_matches[match_index] = match_data
	rounds[round_index] = round_matches
	data["rounds"] = rounds
	if match_index + 1 < round_matches.size():
		data["match_index"] = match_index + 1
		save_to_disk()
		return {
			"ok": true,
			"finished": false,
			"winner": winner,
			"round_completed": false,
			"next_pair": current_pair(),
			"stage_label": stage_label()
		}
	var winners := _winners_from_round(round_matches)
	if winners.size() == 1:
		data["champion"] = winners[0]
		data["finished"] = true
		data["active"] = false
		data["round_index"] = round_index + 1
		data["match_index"] = 0
		save_to_disk()
		return {"ok": true, "finished": true, "winner": winner, "champion": winners[0]}
	var next_round := _build_adjacent_round(winners)
	rounds.append(next_round)
	data["rounds"] = rounds
	data["round_index"] = round_index + 1
	data["match_index"] = 0
	data["active"] = true
	data["finished"] = false
	save_to_disk()
	return {
		"ok": true,
		"finished": false,
		"winner": winner,
		"round_completed": true,
		"next_pair": current_pair(),
		"stage_label": stage_label()
	}

func stage_label() -> String:
	if bool(data.get("finished", false)):
		return "TORNEIO CONCLUÍDO"
	var round_index := int(data.get("round_index", 0))
	var match_number := int(data.get("match_index", 0)) + 1
	var size := current_bracket_size()
	if size == 8:
		match round_index:
			0: return "QUARTAS DE FINAL %d/4" % match_number
			1: return "SEMIFINAL %d/2" % match_number
			2: return "FINAL"
			_: return "TORNEIO DE 8"
	match round_index:
		0: return "SEMIFINAL %d/2" % match_number
		1: return "FINAL"
		_: return "TORNEIO DE 4"

func champion() -> Dictionary:
	var source: Variant = data.get("champion", {})
	return (source as Dictionary).duplicate(true) if source is Dictionary else {}

func bracket_snapshot() -> Dictionary:
	return data.duplicate(true)

func all_matches() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for round_value in data.get("rounds", []):
		if not (round_value is Array):
			continue
		for match_value in round_value:
			if match_value is Dictionary:
				result.append((match_value as Dictionary).duplicate(true))
	return result

func sanitize_state(source: Dictionary) -> Dictionary:
	var size := int(source.get("bracket_size", 4))
	if size not in VALID_SIZES:
		size = 4
	var result := default_state(size)
	var participants_source: Variant = source.get("participants", [])
	var participants: Array[Dictionary] = []
	if participants_source is Array:
		for index in range(mini(size, participants_source.size())):
			if participants_source[index] is Dictionary:
				var clean := sanitize_participant(participants_source[index] as Dictionary, index)
				if not clean.is_empty():
					clean["seed"] = clampi(int(clean.get("seed", index + 1)), 1, size)
					participants.append(clean)
	result["participants"] = participants
	var rounds_source: Variant = source.get("rounds", [])
	var rounds: Array = []
	if rounds_source is Array:
		for round_value in rounds_source:
			if not (round_value is Array):
				continue
			var clean_round: Array = []
			for match_value in round_value:
				if match_value is Dictionary:
					var clean_match := _sanitize_match(match_value as Dictionary)
					if not clean_match.is_empty():
						clean_round.append(clean_match)
			if not clean_round.is_empty():
				rounds.append(clean_round)
	result["rounds"] = rounds
	var champion_source: Variant = source.get("champion", {})
	if champion_source is Dictionary and not (champion_source as Dictionary).is_empty():
		result["champion"] = sanitize_participant(champion_source as Dictionary, 0)
	result["round_index"] = clampi(int(source.get("round_index", 0)), 0, maxi(0, rounds.size()))
	var current_round_matches := 1
	if not rounds.is_empty() and int(result["round_index"]) < rounds.size() and rounds[int(result["round_index"])] is Array:
		current_round_matches = maxi(1, (rounds[int(result["round_index"])] as Array).size())
	result["match_index"] = clampi(int(source.get("match_index", 0)), 0, current_round_matches - 1)
	result["finished"] = bool(source.get("finished", false))
	result["active"] = bool(source.get("active", false)) and participants.size() == size and not bool(result["finished"])
	result["updated_unix"] = int(source.get("updated_unix", 0))
	return result

func sanitize_participant(source: Dictionary, ordinal: int = 0) -> Dictionary:
	var loadout_source: Variant = source.get("loadout", {})
	if not (loadout_source is Dictionary):
		return {}
	var loadout := BattleLoadoutCatalog.sanitize(loadout_source as Dictionary)
	var build := BuildProfile.prototype_preset(StringName(loadout.get("preset_id", &"adaptive_staff")))
	var name := String(source.get("name", build.character_name)).strip_edges()
	if name == "":
		name = "COMPETIDOR %d" % (ordinal + 1)
	var participant_id := String(source.get("participant_id", "slot_%d" % ordinal)).strip_edges().left(96)
	var profile_id := String(source.get("profile_id", "")).strip_edges().left(96)
	var profile_name := String(source.get("profile_name", name)).strip_edges().left(36)
	var result := {
		"participant_id": participant_id if participant_id != "" else "slot_%d" % ordinal,
		"name": name.left(36),
		"seed": maxi(1, int(source.get("seed", ordinal + 1))),
		"loadout": loadout,
		"source": String(source.get("source", "local"))
	}
	if profile_id != "":
		result["profile_id"] = profile_id
		result["profile_name"] = profile_name if profile_name != "" else name.left(36)
	if source.has("qualification"):
		result["qualification"] = String(source.get("qualification", "")).left(8)
	if source.has("group_id"):
		result["group_id"] = String(source.get("group_id", "")).left(8)
	return result

func _build_seeded_round(participants: Array, size: int) -> Array:
	var order := _seed_order(size)
	var matches: Array = []
	for index in range(0, order.size(), 2):
		var first_seed := order[index]
		var second_seed := order[index + 1]
		matches.append(_match_record(_participant_by_seed(participants, first_seed), _participant_by_seed(participants, second_seed), 0, matches.size()))
	return matches

func _build_adjacent_round(participants: Array[Dictionary]) -> Array:
	var matches: Array = []
	for index in range(0, participants.size(), 2):
		matches.append(_match_record(participants[index], participants[index + 1], int(data.get("round_index", 0)) + 1, matches.size()))
	return matches

func _match_record(p1: Dictionary, p2: Dictionary, round_index: int, match_index: int) -> Dictionary:
	if p1.is_empty() or p2.is_empty():
		return {}
	return {
		"round_index": round_index,
		"match_index": match_index,
		"p1": p1.duplicate(true),
		"p2": p2.duplicate(true),
		"winner_index": 0,
		"winner": {}
	}

func _sanitize_match(source: Dictionary) -> Dictionary:
	var p1_source: Variant = source.get("p1", {})
	var p2_source: Variant = source.get("p2", {})
	if not (p1_source is Dictionary) or not (p2_source is Dictionary):
		return {}
	var p1 := sanitize_participant(p1_source as Dictionary, 0)
	var p2 := sanitize_participant(p2_source as Dictionary, 1)
	if p1.is_empty() or p2.is_empty():
		return {}
	var result := {
		"round_index": maxi(0, int(source.get("round_index", 0))),
		"match_index": maxi(0, int(source.get("match_index", 0))),
		"p1": p1,
		"p2": p2,
		"winner_index": clampi(int(source.get("winner_index", 0)), 0, 2),
		"winner": {}
	}
	var winner_source: Variant = source.get("winner", {})
	if winner_source is Dictionary and not (winner_source as Dictionary).is_empty():
		result["winner"] = sanitize_participant(winner_source as Dictionary, 0)
	return result

func _winners_from_round(round_matches: Array) -> Array[Dictionary]:
	var winners: Array[Dictionary] = []
	for match_value in round_matches:
		if not (match_value is Dictionary):
			continue
		var winner_source: Variant = (match_value as Dictionary).get("winner", {})
		if winner_source is Dictionary and not (winner_source as Dictionary).is_empty():
			winners.append((winner_source as Dictionary).duplicate(true))
	return winners

func _participant_by_seed(participants: Array, seed: int) -> Dictionary:
	for value in participants:
		if value is Dictionary and int((value as Dictionary).get("seed", 0)) == seed:
			return (value as Dictionary).duplicate(true)
	return {}

func _seed_order(size: int) -> Array[int]:
	var order: Array[int] = []
	if size == 8:
		order.assign([1, 8, 4, 5, 2, 7, 3, 6])
	else:
		order.assign([1, 4, 2, 3])
	return order
