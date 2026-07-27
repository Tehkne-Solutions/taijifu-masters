extends SceneTree

func _initialize() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var failures: Array[String] = []
	_validate_bracket_export(failures)
	_validate_history_curation(failures)
	await _validate_scene_runtimes(failures)
	if failures.is_empty():
		print("TAIJIFU CI: nomes, sorteio, exportação, ranking e curadoria válidos.")
		quit(0)
		return
	for failure in failures:
		push_error("TAIJIFU CI: %s" % failure)
	quit(1)

func _validate_bracket_export(failures: Array[String]) -> void:
	var ledger := TournamentLedger.new()
	ledger.reset(4)
	var participants: Array[Dictionary] = []
	var presets: Array[StringName] = [&"adaptive_staff", &"rock_guardian", &"lyra_elementalist", &"rin_challenger"]
	for index in range(4):
		participants.append({
			"participant_id": "export_%d" % index,
			"name": "MESTRE %d" % (index + 1),
			"seed": index + 1,
			"loadout": BattleLoadoutCatalog.loadout_from_preset(presets[index]),
			"source": "ci"
		})
	if not ledger.set_participants(participants) or not ledger.start():
		failures.append("Bracket de exportação não iniciou")
		return
	ledger.record_winner(1)
	var result := TournamentBracketExporter.export_snapshot(ledger.bracket_snapshot())
	if not bool(result.get("ok", false)):
		failures.append("Exportador recusou um bracket válido")
		return
	var svg_path := String(result.get("svg_path", ""))
	var json_path := String(result.get("json_path", ""))
	if not FileAccess.file_exists(svg_path) or not FileAccess.file_exists(json_path):
		failures.append("SVG ou JSON não foi criado")
		return
	var svg := FileAccess.get_file_as_string(svg_path)
	if not svg.contains("TAIJIFU MASTERS") or not svg.contains("MESTRE 1"):
		failures.append("SVG não preservou título ou nome do competidor")
	var json_text := FileAccess.get_file_as_string(json_path)
	if not json_text.contains(TournamentBracketExporter.SIGNATURE):
		failures.append("JSON exportado não possui assinatura")

func _validate_history_curation(failures: Array[String]) -> void:
	var ledger := MatchHistoryLedger.new()
	ledger.data = {
		"version": MatchHistoryLedger.VERSION,
		"matches": [
			_sample_record("curation_1", &"kael", &"nara", 1),
			_sample_record("curation_2", &"lyra", &"rin", 2)
		]
	}
	if not ledger.toggle_favorite("curation_1"):
		failures.append("Favorito não foi ativado")
	var tags := ledger.toggle_tag("curation_1", &"technical")
	if &"technical" not in tags:
		failures.append("Tag técnica não foi adicionada")
	ledger.toggle_tag("curation_1", &"tournament")
	if ledger.filtered({"curation_id": &"favorites"}, 0).size() != 1:
		failures.append("Filtro de favoritas incorreto")
	if ledger.filtered({"curation_id": &"technical"}, 0).size() != 1:
		failures.append("Filtro por tag incorreto")
	var aggregate := ledger.aggregate({"curation_id": &"favorites"})
	if int(aggregate.get("favorites", 0)) != 1:
		failures.append("Agregação de favoritas incorreta")
	var metadata := ledger.metadata("curation_1")
	if not bool(metadata.get("favorite", false)) or (metadata.get("tags", []) as Array).size() != 2:
		failures.append("Metadados não foram persistidos no registro")

func _validate_scene_runtimes(failures: Array[String]) -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not is_instance_valid(scene):
		failures.append("Cena principal não carregou")
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var tournament := instance.get_node_or_null("TournamentRuntime") as TournamentRuntime
	var ranking := instance.get_node_or_null("LocalRankingRuntime") as LocalRankingRuntime
	var statistics := instance.get_node_or_null("SeriesStatisticsRuntime") as SeriesStatisticsRuntime
	var history := instance.get_node_or_null("MatchHistoryRuntime") as MatchHistoryRuntime
	if not is_instance_valid(tournament):
		failures.append("TournamentRuntime ausente")
	else:
		tournament.set_format_for_test(4)
		if tournament.set_name_for_test(0, "  Mestre Aurora  ") != "Mestre Aurora":
			failures.append("Nome customizado não foi sanitizado")
		var first_shuffle := tournament.shuffle_for_test(4242)
		var second_shuffle := tournament.shuffle_for_test(4242)
		if first_shuffle != second_shuffle:
			failures.append("Sorteio com seed fixa não é reproduzível")
		var export_result := tournament.export_for_test()
		if not bool(export_result.get("ok", false)):
			failures.append("Runtime do torneio não exportou a prévia")
	if not is_instance_valid(ranking) or not is_instance_valid(statistics):
		failures.append("Ranking ou estatísticas ausentes")
	else:
		statistics.history.data = {
			"version": MatchHistoryLedger.VERSION,
			"matches": [
				_sample_record("rank_1", &"kael", &"nara", 1),
				_sample_record("rank_2", &"kael", &"lyra", 1),
				_sample_record("rank_3", &"rin", &"kael", 1)
			]
		}
		var entries := ranking.ranking_entries()
		if entries.is_empty() or StringName(entries[0].get("character_id", &"")) != &"kael":
			failures.append("Ranking não ordenou Kael como líder")
		if float(entries[0].get("rating", 0.0)) <= 1000.0:
			failures.append("Rating do líder não reagiu às vitórias")
	if not is_instance_valid(history):
		failures.append("MatchHistoryRuntime ausente")
	instance.queue_free()
	await process_frame

func _sample_record(match_id: String, p1_character: StringName, p2_character: StringName, winner_index: int) -> Dictionary:
	return {
		"match_id": match_id,
		"started_unix": 1,
		"completed_unix": 2,
		"winner_index": winner_index,
		"score_p1": 2 if winner_index == 1 else 1,
		"score_p2": 2 if winner_index == 2 else 1,
		"config": {"arena_id": &"triple_ruins", "series_id": &"best_of_3", "time_id": &"sixty", "modifier_id": &"classic"},
		"players": [
			{"player_index": 1, "character_id": String(p1_character), "character_name": String(p1_character).to_upper(), "loadout": BattleLoadoutCatalog.loadout_from_preset(_preset_for(p1_character))},
			{"player_index": 2, "character_id": String(p2_character), "character_name": String(p2_character).to_upper(), "loadout": BattleLoadoutCatalog.loadout_from_preset(_preset_for(p2_character))}
		],
		"rounds": [
			{"round_number": 1, "winner_index": winner_index, "reason": "KO", "duration_seconds": 30.0, "stats": [{"damage_dealt": 120.0, "parries": 2.0}, {"damage_dealt": 75.0}], "highlights": [], "resources": []},
			{"round_number": 2, "winner_index": winner_index, "reason": "KO", "duration_seconds": 28.0, "stats": [{"damage_dealt": 110.0, "posture_breaks": 1.0}, {"damage_dealt": 70.0}], "highlights": [], "resources": []}
		],
		"totals": [
			{"damage_dealt": 230.0, "parries": 2.0, "posture_breaks": 1.0, "disarms": 1.0},
			{"damage_dealt": 145.0, "parries": 0.0, "posture_breaks": 0.0, "disarms": 0.0}
		],
		"favorite": false,
		"tags": []
	}

func _preset_for(character_id: StringName) -> StringName:
	match character_id:
		&"nara": return &"rock_guardian"
		&"lyra": return &"lyra_elementalist"
		&"rin": return &"rin_challenger"
		_: return &"adaptive_staff"
