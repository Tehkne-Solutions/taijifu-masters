extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	_validate_tournament_eight(failures)
	_validate_history_filters(failures)
	_validate_replay_cards(failures)
	await _validate_scene(failures)
	if failures.is_empty():
		print("TAIJIFU CI: torneio de oito, replay e filtros válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)

func _validate_tournament_eight(failures: Array[String]) -> void:
	var ledger := TournamentLedger.new()
	ledger.reset(8)
	var participants: Array[Dictionary] = []
	var presets: Array[StringName] = [
		&"adaptive_staff", &"rock_guardian", &"lyra_elementalist", &"rin_challenger",
		&"aerial_flow", &"foundation_breaker", &"adaptive_staff", &"rock_guardian"
	]
	for index in range(8):
		participants.append({
			"participant_id": "seed_%d" % (index + 1),
			"name": "SEED %d" % (index + 1),
			"seed": index + 1,
			"loadout": BattleLoadoutCatalog.loadout_from_preset(presets[index]),
			"source": "ci"
		})
	if not ledger.set_participants(participants) or not ledger.start():
		failures.append("Torneio de oito não iniciou")
		return
	var first_pair := ledger.current_pair()
	if first_pair.size() != 2 or int(first_pair[0].get("seed", 0)) != 1 or int(first_pair[1].get("seed", 0)) != 8:
		failures.append("Pareamento inicial 1×8 incorreto")
	for match_index in range(7):
		var result := ledger.record_winner(1)
		if not bool(result.get("ok", false)):
			failures.append("Falha ao registrar vencedor %d" % match_index)
			return
	if not bool(ledger.data.get("finished", false)):
		failures.append("Torneio de oito não chegou à final")
	if int(ledger.champion().get("seed", 0)) != 1:
		failures.append("Seed 1 não foi preservado como campeão")
	if ledger.all_matches().size() != 7:
		failures.append("Chave de oito não possui sete confrontos")

func _validate_history_filters(failures: Array[String]) -> void:
	var ledger := MatchHistoryLedger.new()
	ledger.data = {
		"version": MatchHistoryLedger.VERSION,
		"matches": [
			_sample_record("m1", &"kael", &"nara", &"triple_ruins", 1, "KO"),
			_sample_record("m2", &"lyra", &"rin", &"silent_sanctuary", 2, "TEMPO"),
			_sample_record("m3", &"kael", &"rin", &"ember_crucible", 2, "PRORROGAÇÃO")
		]
	}
	if ledger.filtered({"character_id": &"kael"}, 0).size() != 2:
		failures.append("Filtro por personagem incorreto")
	if ledger.filtered({"arena_id": &"silent_sanctuary"}, 0).size() != 1:
		failures.append("Filtro por arena incorreto")
	if ledger.filtered({"result_id": &"p2_win"}, 0).size() != 2:
		failures.append("Filtro por vencedor incorreto")
	if ledger.filtered({"result_id": &"sudden_death"}, 0).size() != 1:
		failures.append("Filtro por prorrogação incorreto")
	var aggregate := ledger.aggregate({"character_id": &"kael"})
	if int(aggregate.get("series", 0)) != 2:
		failures.append("Agregação filtrada incorreta")

func _validate_replay_cards(failures: Array[String]) -> void:
	var replay := SeriesReplayRuntime.new()
	root.add_child(replay)
	await process_frame
	var record := _sample_record("replay", &"kael", &"nara", &"triple_ruins", 1, "KO")
	var cards := replay.build_cards(record)
	if cards.size() != 3:
		failures.append("Replay não criou abertura, round e desfecho")
	else:
		var round_card: Dictionary = cards[1]
		if not String(round_card.get("body", "")).contains("Aparo técnico"):
			failures.append("Replay não preservou o destaque do round")
	replay.queue_free()
	await process_frame

func _validate_scene(failures: Array[String]) -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not is_instance_valid(scene):
		failures.append("Cena principal não carregou")
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var tournament := instance.get_node_or_null("TournamentRuntime") as TournamentRuntime
	var replay := instance.get_node_or_null("SeriesReplayRuntime") as SeriesReplayRuntime
	var history := instance.get_node_or_null("MatchHistoryRuntime") as MatchHistoryRuntime
	var statistics := instance.get_node_or_null("SeriesStatisticsRuntime") as SeriesStatisticsRuntime
	if not is_instance_valid(tournament) or tournament.set_format_for_test(8) != 8:
		failures.append("Runtime de torneio não aceitou oito competidores")
	if not is_instance_valid(replay):
		failures.append("SeriesReplayRuntime ausente")
	if not is_instance_valid(history) or not is_instance_valid(statistics):
		failures.append("Histórico ou estatísticas ausentes")
	else:
		statistics.history.data = {"version": MatchHistoryLedger.VERSION, "matches": [_sample_record("scene", &"lyra", &"rin", &"silent_sanctuary", 2, "TEMPO")]}
		history.set_filters_for_test({"character_id": &"lyra", "arena_id": &"silent_sanctuary", "result_id": &"p2_win"})
		if history.filtered_count() != 1:
			failures.append("Runtime do histórico não aplicou filtros combinados")
	instance.queue_free()
	await process_frame

func _sample_record(match_id: String, p1_character: StringName, p2_character: StringName, arena_id: StringName, winner_index: int, reason: String) -> Dictionary:
	return {
		"match_id": match_id,
		"started_unix": 1,
		"completed_unix": 2,
		"winner_index": winner_index,
		"score_p1": 2 if winner_index == 1 else 1,
		"score_p2": 2 if winner_index == 2 else 1,
		"config": {"arena_id": arena_id, "series_id": &"best_of_3", "time_id": &"sixty", "modifier_id": &"classic"},
		"players": [
			{"player_index": 1, "character_id": String(p1_character), "character_name": String(p1_character).to_upper(), "build_name": "P1", "loadout": BattleLoadoutCatalog.loadout_from_preset(_preset_for_character(p1_character))},
			{"player_index": 2, "character_id": String(p2_character), "character_name": String(p2_character).to_upper(), "build_name": "P2", "loadout": BattleLoadoutCatalog.loadout_from_preset(_preset_for_character(p2_character))}
		],
		"rounds": [{
			"round_number": 1,
			"winner_index": winner_index,
			"reason": reason,
			"duration_seconds": 42.0,
			"stats": [{"damage_dealt": 100.0, "parries": 1.0}, {"damage_dealt": 80.0, "parries": 0.0}],
			"highlights": [{"time_seconds": 12.5, "player_index": 1, "event_id": "parry", "label": "Aparo técnico interrompe a pressão", "value": 1.0}],
			"resources": [{"health_ratio": 0.55}, {"health_ratio": 0.20}]
		}],
		"totals": [{"damage_dealt": 100.0, "parries": 1.0, "posture_breaks": 1.0, "disarms": 0.0}, {"damage_dealt": 80.0, "parries": 0.0, "posture_breaks": 0.0, "disarms": 0.0}]
	}

func _preset_for_character(character_id: StringName) -> StringName:
	match character_id:
		&"nara": return &"rock_guardian"
		&"lyra": return &"lyra_elementalist"
		&"rin": return &"rin_challenger"
		_: return &"adaptive_staff"
