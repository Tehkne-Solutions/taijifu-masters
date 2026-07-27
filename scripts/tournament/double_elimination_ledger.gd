class_name DoubleEliminationLedger
extends RefCounted

const SAVE_PATH := "user://double_elimination_state.json"
const VERSION := 1
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
		"matches": [],
		"current_match_id": "",
		"losses": {},
		"eliminated": [],
		"champion": {},
		"runner_up": {},
		"reset_required": false,
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
	if bool(data.get("active", false)):
		_update_current_match()

func save_to_disk() -> String:
	data = sanitize_state(data)
	data["updated_unix"] = int(Time.get_unix_time_from_system())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return ""
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
	var ids: Dictionary = {}
	for index in range(size):
		var participant := sanitize_participant(participants[index], index)
		if participant.is_empty():
			return false
		participant["seed"] = index + 1
		var participant_id := String(participant.get("participant_id", ""))
		if participant_id == "" or ids.has(participant_id):
			participant_id = "double_seed_%d_%s" % [index + 1, participant_id if participant_id != "" else "player"]
		participant["participant_id"] = participant_id
		ids[participant_id] = true
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
	var clean_participants: Array[Dictionary] = []
	for index in range(size):
		if not (participants[index] is Dictionary):
			return false
		var participant := sanitize_participant(participants[index] as Dictionary, index)
		participant["seed"] = index + 1
		clean_participants.append(participant)
	var losses: Dictionary = {}
	for participant in clean_participants:
		losses[String(participant.get("participant_id", ""))] = 0
	data = default_state(size)
	data["participants"] = clean_participants
	data["matches"] = _build_schedule(size)
	data["losses"] = losses
	data["active"] = true
	_update_current_match()
	save_to_disk()
	return String(data.get("current_match_id", "")) != ""

func is_active() -> bool:
	return bool(data.get("active", false)) and not bool(data.get("finished", false))

func is_finished() -> bool:
	return bool(data.get("finished", false))

func current_match() -> Dictionary:
	if not is_active():
		return {}
	_update_current_match()
	var current_id := String(data.get("current_match_id", ""))
	return match_by_id(current_id)

func current_pair() -> Array[Dictionary]:
	var match_data := current_match()
	if match_data.is_empty():
		return []
	var p1_source: Variant = match_data.get("p1", {})
	var p2_source: Variant = match_data.get("p2", {})
	if not (p1_source is Dictionary) or not (p2_source is Dictionary):
		return []
	if (p1_source as Dictionary).is_empty() or (p2_source as Dictionary).is_empty():
		return []
	return [(p1_source as Dictionary).duplicate(true), (p2_source as Dictionary).duplicate(true)]

func record_result(winner_index: int, score_p1: int, score_p2: int) -> Dictionary:
	if not is_active():
		return {"ok": false, "error": "Dupla eliminação inativa"}
	var current := current_match()
	if current.is_empty():
		return {"ok": false, "error": "Confronto atual inválido"}
	var pair := current_pair()
	if pair.size() != 2:
		return {"ok": false, "error": "Competidores do confronto não resolvidos"}
	var clean_winner_index := clampi(winner_index, 1, 2)
	var winner: Dictionary = pair[clean_winner_index - 1].duplicate(true)
	var loser: Dictionary = pair[1 if clean_winner_index == 1 else 0].duplicate(true)
	var match_id := String(current.get("match_id", ""))
	var match_index := _find_match_index(match_id)
	if match_index < 0:
		return {"ok": false, "error": "Confronto não encontrado"}
	current["winner_index"] = clean_winner_index
	current["winner"] = winner
	current["loser"] = loser
	current["score_p1"] = maxi(0, score_p1)
	current["score_p2"] = maxi(0, score_p2)
	current["completed"] = true
	var matches: Array = data.get("matches", [])
	matches[match_index] = current
	data["matches"] = matches
	var loser_id := String(loser.get("participant_id", ""))
	var losses: Dictionary = data.get("losses", {})
	losses[loser_id] = int(losses.get(loser_id, 0)) + 1
	data["losses"] = losses
	var eliminated_now := false
	if int(losses.get(loser_id, 0)) >= 2:
		var eliminated: Array = data.get("eliminated", [])
		if loser_id not in eliminated:
			eliminated.append(loser_id)
			eliminated_now = true
		data["eliminated"] = eliminated
	var reset_required := false
	if match_id == "GF":
		if clean_winner_index == 1:
			_finish(winner, loser)
		else:
			_enable_reset(current)
			reset_required = true
	elif match_id == "RESET":
		_finish(winner, loser)
	else:
		_update_current_match()
	if not is_finished():
		_update_current_match()
	save_to_disk()
	return {
		"ok": true,
		"finished": is_finished(),
		"winner": winner,
		"loser": loser,
		"eliminated": eliminated_now,
		"loser_losses": int(losses.get(loser_id, 0)),
		"reset_required": reset_required,
		"next_match": current_match(),
		"stage_label": stage_label(),
		"champion": champion()
	}

func stage_label() -> String:
	if is_finished():
		return "DUPLA ELIMINAÇÃO CONCLUÍDA"
	var match_data := current_match()
	return String(match_data.get("stage_label", "DUPLA ELIMINAÇÃO")) if not match_data.is_empty() else "DUPLA ELIMINAÇÃO"

func current_bracket() -> StringName:
	var match_data := current_match()
	return StringName(match_data.get("bracket", &"upper")) if not match_data.is_empty() else &"upper"

func champion() -> Dictionary:
	var source: Variant = data.get("champion", {})
	return (source as Dictionary).duplicate(true) if source is Dictionary else {}

func runner_up() -> Dictionary:
	var source: Variant = data.get("runner_up", {})
	return (source as Dictionary).duplicate(true) if source is Dictionary else {}

func loss_count(participant_id: String) -> int:
	var losses: Dictionary = data.get("losses", {})
	return maxi(0, int(losses.get(participant_id, 0)))

func participant_status(participant_id: String) -> StringName:
	if String(champion().get("participant_id", "")) == participant_id:
		return &"champion"
	if participant_id in (data.get("eliminated", []) as Array):
		return &"eliminated"
	return &"lower" if loss_count(participant_id) == 1 else &"upper"

func match_by_id(match_id: String) -> Dictionary:
	for value in data.get("matches", []):
		if value is Dictionary and String((value as Dictionary).get("match_id", "")) == match_id:
			return (value as Dictionary).duplicate(true)
	return {}

func all_matches() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in data.get("matches", []):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result

func bracket_snapshot() -> Dictionary:
	return data.duplicate(true)

func sanitize_state(source: Dictionary) -> Dictionary:
	var size := int(source.get("bracket_size", 4))
	if size not in VALID_SIZES:
		size = 4
	var result := default_state(size)
	var participants: Array[Dictionary] = []
	var participant_source: Variant = source.get("participants", [])
	if participant_source is Array:
		for index in range(mini(size, participant_source.size())):
			if participant_source[index] is Dictionary:
				var participant := sanitize_participant(participant_source[index] as Dictionary, index)
				participant["seed"] = clampi(int(participant.get("seed", index + 1)), 1, size)
				participants.append(participant)
	result["participants"] = participants
	var matches: Array = []
	var match_source: Variant = source.get("matches", [])
	if match_source is Array:
		for value in match_source:
			if value is Dictionary:
				var clean_match := _sanitize_match(value as Dictionary)
				if not clean_match.is_empty():
					matches.append(clean_match)
	if matches.is_empty() and participants.size() == size and bool(source.get("active", false)):
		matches = _build_schedule(size)
	result["matches"] = matches
	var losses: Dictionary = {}
	var loss_source: Variant = source.get("losses", {})
	for participant in participants:
		var participant_id := String(participant.get("participant_id", ""))
		losses[participant_id] = clampi(int((loss_source as Dictionary).get(participant_id, 0)) if loss_source is Dictionary else 0, 0, 2)
	result["losses"] = losses
	var eliminated: Array[String] = []
	var eliminated_source: Variant = source.get("eliminated", [])
	if eliminated_source is Array:
		for value in eliminated_source:
			var participant_id := String(value)
			if losses.has(participant_id) and participant_id not in eliminated:
				eliminated.append(participant_id)
	result["eliminated"] = eliminated
	var champion_source: Variant = source.get("champion", {})
	if champion_source is Dictionary and not (champion_source as Dictionary).is_empty():
		result["champion"] = sanitize_participant(champion_source as Dictionary, 0)
	var runner_source: Variant = source.get("runner_up", {})
	if runner_source is Dictionary and not (runner_source as Dictionary).is_empty():
		result["runner_up"] = sanitize_participant(runner_source as Dictionary, 0)
	result["finished"] = bool(source.get("finished", false)) and not (result["champion"] as Dictionary).is_empty()
	result["active"] = bool(source.get("active", false)) and participants.size() == size and not bool(result["finished"])
	result["current_match_id"] = String(source.get("current_match_id", ""))
	result["reset_required"] = bool(source.get("reset_required", false))
	result["updated_unix"] = int(source.get("updated_unix", 0))
	return result

func sanitize_participant(source: Dictionary, ordinal: int = 0) -> Dictionary:
	var loadout_source: Variant = source.get("loadout", {})
	if not (loadout_source is Dictionary):
		return {}
	var loadout := BattleLoadoutCatalog.sanitize(loadout_source as Dictionary)
	var build := BuildProfile.prototype_preset(StringName(loadout.get("preset_id", &"adaptive_staff")))
	var participant_id := String(source.get("participant_id", "double_%d" % ordinal)).strip_edges().left(80)
	if participant_id == "":
		participant_id = "double_%d" % ordinal
	var name := String(source.get("name", source.get("profile_name", build.character_name))).strip_edges()
	if name == "":
		name = "COMPETIDOR %d" % (ordinal + 1)
	return {
		"participant_id": participant_id,
		"name": name.left(36),
		"profile_id": String(source.get("profile_id", participant_id)).left(80),
		"profile_name": String(source.get("profile_name", name)).left(36),
		"seed": maxi(1, int(source.get("seed", ordinal + 1))),
		"loadout": loadout,
		"source": String(source.get("source", "local")).left(80),
		"qualification": String(source.get("qualification", "")).left(12),
		"group_id": String(source.get("group_id", "")).left(8)
	}

func _update_current_match() -> void:
	if not is_active():
		data["current_match_id"] = ""
		return
	var matches: Array = data.get("matches", [])
	for index in range(matches.size()):
		if not (matches[index] is Dictionary):
			continue
		var match_data: Dictionary = matches[index]
		if not bool(match_data.get("enabled", true)) or bool(match_data.get("completed", false)):
			continue
		match_data = _resolve_match(match_data)
		matches[index] = match_data
		data["matches"] = matches
		var p1: Dictionary = match_data.get("p1", {})
		var p2: Dictionary = match_data.get("p2", {})
		if not p1.is_empty() and not p2.is_empty():
			data["current_match_id"] = String(match_data.get("match_id", ""))
			return
	data["current_match_id"] = ""

func _resolve_match(match_data: Dictionary) -> Dictionary:
	if (match_data.get("p1", {}) as Dictionary).is_empty():
		match_data["p1"] = _resolve_reference(String(match_data.get("p1_ref", "")))
	if (match_data.get("p2", {}) as Dictionary).is_empty():
		match_data["p2"] = _resolve_reference(String(match_data.get("p2_ref", "")))
	return match_data

func _resolve_reference(reference: String) -> Dictionary:
	if reference.begins_with("seed:"):
		return _participant_by_seed(int(reference.trim_prefix("seed:")))
	if reference.begins_with("winner:"):
		return _match_participant(reference.trim_prefix("winner:"), "winner")
	if reference.begins_with("loser:"):
		return _match_participant(reference.trim_prefix("loser:"), "loser")
	return {}

func _participant_by_seed(seed: int) -> Dictionary:
	for value in data.get("participants", []):
		if value is Dictionary and int((value as Dictionary).get("seed", 0)) == seed:
			return (value as Dictionary).duplicate(true)
	return {}

func _match_participant(match_id: String, field: String) -> Dictionary:
	var match_data := match_by_id(match_id)
	var source: Variant = match_data.get(field, {})
	return (source as Dictionary).duplicate(true) if source is Dictionary else {}

func _enable_reset(grand_final: Dictionary) -> void:
	var matches: Array = data.get("matches", [])
	var reset_index := _find_match_index("RESET")
	if reset_index < 0:
		return
	var reset_match: Dictionary = matches[reset_index]
	reset_match["enabled"] = true
	reset_match["p1"] = (grand_final.get("p1", {}) as Dictionary).duplicate(true)
	reset_match["p2"] = (grand_final.get("p2", {}) as Dictionary).duplicate(true)
	matches[reset_index] = reset_match
	data["matches"] = matches
	data["reset_required"] = true

func _finish(winner: Dictionary, loser: Dictionary) -> void:
	data["champion"] = winner.duplicate(true)
	data["runner_up"] = loser.duplicate(true)
	data["finished"] = true
	data["active"] = false
	data["current_match_id"] = ""

func _find_match_index(match_id: String) -> int:
	var matches: Array = data.get("matches", [])
	for index in range(matches.size()):
		if matches[index] is Dictionary and String((matches[index] as Dictionary).get("match_id", "")) == match_id:
			return index
	return -1

func _build_schedule(size: int) -> Array:
	if size == 8:
		return [
			_match_record("UQ1", "CHAVE SUPERIOR • QUARTAS 1", &"upper", "seed:1", "seed:8"),
			_match_record("UQ2", "CHAVE SUPERIOR • QUARTAS 2", &"upper", "seed:4", "seed:5"),
			_match_record("UQ3", "CHAVE SUPERIOR • QUARTAS 3", &"upper", "seed:2", "seed:7"),
			_match_record("UQ4", "CHAVE SUPERIOR • QUARTAS 4", &"upper", "seed:3", "seed:6"),
			_match_record("L1", "CHAVE INFERIOR • RODADA 1A", &"lower", "loser:UQ1", "loser:UQ2"),
			_match_record("L2", "CHAVE INFERIOR • RODADA 1B", &"lower", "loser:UQ3", "loser:UQ4"),
			_match_record("US1", "CHAVE SUPERIOR • SEMIFINAL 1", &"upper", "winner:UQ1", "winner:UQ2"),
			_match_record("US2", "CHAVE SUPERIOR • SEMIFINAL 2", &"upper", "winner:UQ3", "winner:UQ4"),
			_match_record("L3", "CHAVE INFERIOR • RODADA 2A", &"lower", "winner:L1", "loser:US2"),
			_match_record("L4", "CHAVE INFERIOR • RODADA 2B", &"lower", "winner:L2", "loser:US1"),
			_match_record("UF", "FINAL DA CHAVE SUPERIOR", &"upper", "winner:US1", "winner:US2"),
			_match_record("LS", "SEMIFINAL DA CHAVE INFERIOR", &"lower", "winner:L3", "winner:L4"),
			_match_record("LF", "FINAL DA CHAVE INFERIOR", &"lower", "winner:LS", "loser:UF"),
			_match_record("GF", "GRANDE FINAL", &"grand_final", "winner:UF", "winner:LF"),
			_match_record("RESET", "RESET DA GRANDE FINAL", &"reset", "", "", false)
		]
	return [
		_match_record("U1", "CHAVE SUPERIOR • SEMIFINAL 1", &"upper", "seed:1", "seed:4"),
		_match_record("U2", "CHAVE SUPERIOR • SEMIFINAL 2", &"upper", "seed:2", "seed:3"),
		_match_record("L1", "CHAVE INFERIOR • ELIMINATÓRIA", &"lower", "loser:U1", "loser:U2"),
		_match_record("UF", "FINAL DA CHAVE SUPERIOR", &"upper", "winner:U1", "winner:U2"),
		_match_record("LF", "FINAL DA CHAVE INFERIOR", &"lower", "winner:L1", "loser:UF"),
		_match_record("GF", "GRANDE FINAL", &"grand_final", "winner:UF", "winner:LF"),
		_match_record("RESET", "RESET DA GRANDE FINAL", &"reset", "", "", false)
	]

func _match_record(match_id: String, stage: String, bracket: StringName, p1_ref: String, p2_ref: String, enabled: bool = true) -> Dictionary:
	return {
		"match_id": match_id,
		"stage_label": stage,
		"bracket": bracket,
		"p1_ref": p1_ref,
		"p2_ref": p2_ref,
		"p1": {},
		"p2": {},
		"winner_index": 0,
		"winner": {},
		"loser": {},
		"score_p1": 0,
		"score_p2": 0,
		"completed": false,
		"enabled": enabled
	}

func _sanitize_match(source: Dictionary) -> Dictionary:
	var match_id := String(source.get("match_id", "")).strip_edges().left(16)
	if match_id == "":
		return {}
	var result := {
		"match_id": match_id,
		"stage_label": String(source.get("stage_label", match_id)).left(64),
		"bracket": StringName(source.get("bracket", &"upper")),
		"p1_ref": String(source.get("p1_ref", "")).left(24),
		"p2_ref": String(source.get("p2_ref", "")).left(24),
		"p1": {},
		"p2": {},
		"winner_index": clampi(int(source.get("winner_index", 0)), 0, 2),
		"winner": {},
		"loser": {},
		"score_p1": maxi(0, int(source.get("score_p1", 0))),
		"score_p2": maxi(0, int(source.get("score_p2", 0))),
		"completed": bool(source.get("completed", false)),
		"enabled": bool(source.get("enabled", true))
	}
	for field in ["p1", "p2", "winner", "loser"]:
		var participant_source: Variant = source.get(field, {})
		if participant_source is Dictionary and not (participant_source as Dictionary).is_empty():
			result[field] = sanitize_participant(participant_source as Dictionary, 0)
	return result
