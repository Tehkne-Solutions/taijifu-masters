class_name TournamentLedger
extends RefCounted

const SAVE_PATH := "user://tournament_state.json"
const VERSION := 1

var data: Dictionary = default_state()

static func default_state() -> Dictionary:
	return {
		"version": VERSION,
		"active": false,
		"finished": false,
		"stage_index": 0,
		"participants": [],
		"semifinal_winners": [],
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

func reset() -> void:
	data = default_state()
	save_to_disk()

func set_participants(participants: Array[Dictionary]) -> bool:
	if participants.size() != 4:
		return false
	var clean: Array[Dictionary] = []
	for index in range(4):
		var participant := sanitize_participant(participants[index], index)
		if participant.is_empty():
			return false
		clean.append(participant)
	data = default_state()
	data["participants"] = clean
	save_to_disk()
	return true

func start() -> bool:
	var participants: Array = data.get("participants", [])
	if participants.size() != 4:
		return false
	data["active"] = true
	data["finished"] = false
	data["stage_index"] = 0
	data["semifinal_winners"] = []
	data["champion"] = {}
	save_to_disk()
	return true

func current_pair() -> Array[Dictionary]:
	var participants: Array = data.get("participants", [])
	if participants.size() != 4 or bool(data.get("finished", false)):
		return []
	var stage := int(data.get("stage_index", 0))
	if stage == 0:
		return [_participant_at(participants, 0), _participant_at(participants, 1)]
	if stage == 1:
		return [_participant_at(participants, 2), _participant_at(participants, 3)]
	var winners: Array = data.get("semifinal_winners", [])
	if stage == 2 and winners.size() == 2:
		return [_participant_at(winners, 0), _participant_at(winners, 1)]
	return []

func record_winner(winner_index: int) -> Dictionary:
	if not bool(data.get("active", false)) or bool(data.get("finished", false)):
		return {"ok": false, "error": "Torneio inativo"}
	var pair := current_pair()
	if pair.size() != 2:
		return {"ok": false, "error": "Confronto atual inválido"}
	var clean_index := clampi(winner_index, 1, 2)
	var winner: Dictionary = pair[clean_index - 1].duplicate(true)
	var stage := int(data.get("stage_index", 0))
	if stage < 2:
		var winners: Array = data.get("semifinal_winners", [])
		winners.append(winner)
		data["semifinal_winners"] = winners
		data["stage_index"] = stage + 1
		data["active"] = true
		data["finished"] = false
		save_to_disk()
		return {
			"ok": true,
			"finished": false,
			"winner": winner,
			"next_stage_index": stage + 1,
			"next_pair": current_pair()
		}
	data["champion"] = winner
	data["finished"] = true
	data["active"] = false
	data["stage_index"] = 3
	save_to_disk()
	return {"ok": true, "finished": true, "winner": winner, "champion": winner}

func stage_label() -> String:
	match int(data.get("stage_index", 0)):
		0: return "SEMIFINAL A"
		1: return "SEMIFINAL B"
		2: return "FINAL"
		3: return "TORNEIO CONCLUÍDO"
		_: return "TORNEIO"

func champion() -> Dictionary:
	var source: Variant = data.get("champion", {})
	return (source as Dictionary).duplicate(true) if source is Dictionary else {}

func sanitize_state(source: Dictionary) -> Dictionary:
	var result := default_state()
	var participants_source: Variant = source.get("participants", [])
	var participants: Array[Dictionary] = []
	if participants_source is Array:
		for index in range(mini(4, participants_source.size())):
			if participants_source[index] is Dictionary:
				var clean := sanitize_participant(participants_source[index] as Dictionary, index)
				if not clean.is_empty():
					participants.append(clean)
	result["participants"] = participants
	var winners_source: Variant = source.get("semifinal_winners", [])
	var winners: Array[Dictionary] = []
	if winners_source is Array:
		for index in range(mini(2, winners_source.size())):
			if winners_source[index] is Dictionary:
				var clean := sanitize_participant(winners_source[index] as Dictionary, index)
				if not clean.is_empty():
					winners.append(clean)
	result["semifinal_winners"] = winners
	var champion_source: Variant = source.get("champion", {})
	if champion_source is Dictionary and not (champion_source as Dictionary).is_empty():
		result["champion"] = sanitize_participant(champion_source as Dictionary, 0)
	result["stage_index"] = clampi(int(source.get("stage_index", 0)), 0, 3)
	result["finished"] = bool(source.get("finished", false))
	result["active"] = bool(source.get("active", false)) and participants.size() == 4 and not bool(result["finished"])
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
	return {
		"participant_id": String(source.get("participant_id", "slot_%d" % ordinal)),
		"name": name.left(36),
		"loadout": loadout,
		"source": String(source.get("source", "local"))
	}

func _participant_at(source: Array, index: int) -> Dictionary:
	if index < 0 or index >= source.size() or not (source[index] is Dictionary):
		return {}
	return (source[index] as Dictionary).duplicate(true)
